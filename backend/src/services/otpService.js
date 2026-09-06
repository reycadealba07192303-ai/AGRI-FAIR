import crypto from 'crypto';
import bcrypt from 'bcryptjs';

import { otpRepository } from '../repositories/otpRepository.js';
import { sendMail, isMailConfigured } from '../config/mailer.js';
import { OTP_TTL_MINUTES, OTP_MAX_ATTEMPTS, OTP_PURPOSES } from '../models/EmailOtp.js';

const RESEND_WINDOW_MS = 15 * 60 * 1000;
const MAX_CODES_PER_WINDOW = 5;

export { OTP_PURPOSES, OTP_TTL_MINUTES };

export function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

/**
 * crypto.randomInt, not Math.random — a one-time code is a credential, and a
 * predictable one is the whole attack.
 */
function generateCode() {
  return String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
}

function codeEmail({ heading, intro, code, footer }) {
  return `
    <div style="font-family:Segoe UI,Arial,sans-serif;max-width:480px;margin:0 auto;color:#16211b">
      <h2 style="color:#3f6b4c;margin:0 0 8px">${heading}</h2>
      <p style="margin:0 0 20px;color:#4c5b51">${intro}</p>
      <div style="font-size:34px;font-weight:700;letter-spacing:10px;color:#16211b;
                  background:#edf2ea;padding:18px;text-align:center;border-radius:6px">
        ${code}
      </div>
      <p style="margin:20px 0 0;color:#4c5b51">
        The code expires in ${OTP_TTL_MINUTES} minutes and can be used once.
      </p>
      <p style="margin:8px 0 0;color:#7c8b81;font-size:13px">${footer}</p>
    </div>
  `;
}

const TEMPLATES = {
  [OTP_PURPOSES.signup]: (name, code) => ({
    subject: `${code} is your AgriFair verification code`,
    html: codeEmail({
      heading: 'Verify your AgriFair email',
      intro: `Hi ${name || 'there'}, enter this code in the app to finish setting up your account.`,
      code,
      footer: 'If you did not create an AgriFair account, you can ignore this email.',
    }),
  }),
  [OTP_PURPOSES.passwordReset]: (name, code) => ({
    subject: `${code} is your AgriFair reset code`,
    html: codeEmail({
      heading: 'AgriFair password reset',
      intro: `Hi ${name || 'there'}, use this code to reset your password.`,
      code,
      footer: 'If you did not ask for this, you can ignore this email — your password stays as it is.',
    }),
  }),
};

export const otpService = {
  /**
   * Issues a code and emails it. Callers decide whether the address exists —
   * this never reveals that either way.
   */
  async issue({ email, purpose, name }) {
    const cleanEmail = normalizeEmail(email);
    if (!cleanEmail) throw new Error('Email is required');

    if (!isMailConfigured()) {
      throw new Error(
        'Email is not set up. Add SMTP_HOST, SMTP_USER and SMTP_PASS to backend/.env, then restart the server.'
      );
    }

    const recentCount = await otpRepository.countRecent(
      cleanEmail,
      purpose,
      new Date(Date.now() - RESEND_WINDOW_MS)
    );
    if (recentCount >= MAX_CODES_PER_WINDOW) {
      throw new Error('Too many codes requested. Please try again later.');
    }

    const code = generateCode();
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

    await otpRepository.consumeAllFor(cleanEmail, purpose);
    await otpRepository.create({ email: cleanEmail, purpose, codeHash, expiresAt });

    const { subject, html } = TEMPLATES[purpose](name, code);
    await sendMail({ to: cleanEmail, subject, html });

    return { sent: true };
  },

  /**
   * Burns the code on success. A code is single use, so a replay after the
   * password or the verification flag has changed finds nothing to spend.
   */
  async verify({ email, code, purpose }) {
    const cleanEmail = normalizeEmail(email);
    const cleanCode = typeof code === 'string' ? code.trim() : '';

    if (!cleanEmail || !cleanCode) {
      throw new Error('Email and code are required');
    }

    const record = await otpRepository.findActive(cleanEmail, purpose);
    if (!record) {
      throw new Error('That code has expired. Request a new one.');
    }

    if (record.attempts >= OTP_MAX_ATTEMPTS) {
      await otpRepository.markConsumed(record._id);
      throw new Error('Too many wrong attempts. Request a new code.');
    }

    const isMatch = await bcrypt.compare(cleanCode, record.codeHash);
    if (!isMatch) {
      const updated = await otpRepository.recordAttempt(record._id);
      const left = Math.max(0, OTP_MAX_ATTEMPTS - (updated?.attempts ?? OTP_MAX_ATTEMPTS));
      throw new Error(
        left > 0
          ? `Incorrect code. ${left} ${left === 1 ? 'try' : 'tries'} left.`
          : 'Too many wrong attempts. Request a new code.'
      );
    }

    await otpRepository.markConsumed(record._id);
    return { email: cleanEmail };
  }
};
