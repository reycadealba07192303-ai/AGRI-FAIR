import nodemailer from 'nodemailer';

let transporter = null;

/**
 * SMTP is optional: the app runs fine without it, and anything that sends mail
 * reports a clear "not configured" instead of crashing.
 *
 * For Gmail, SMTP_PASS must be an App Password, not the account password —
 * Google rejects plain passwords from SMTP.
 */
export function getMailer() {
  if (transporter) return transporter;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;

  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT) || 587,
    secure: Number(SMTP_PORT) === 465,
    auth: { user: SMTP_USER, pass: SMTP_PASS },

    // Without pooling, every message pays for a fresh TCP connection, TLS
    // handshake and login to Gmail - most of the several seconds a send used
    // to take. Held open, later messages skip all of it.
    pool: true,
    maxConnections: 3,

    // A hung SMTP connection must not hold a request forever.
    connectionTimeout: 10000,
    greetingTimeout: 10000,
    socketTimeout: 20000,
  });

  return transporter;
}

export function isMailConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

export async function sendMail({ to, subject, html, attachments }) {
  const mailer = getMailer();
  if (!mailer) {
    throw new Error(
      'Email is not set up. Add SMTP_HOST, SMTP_USER and SMTP_PASS to backend/.env, then restart the server.'
    );
  }

  const from = process.env.MAIL_FROM || `AgriFair <${process.env.SMTP_USER}>`;
  return mailer.sendMail({ from, to, subject, html, attachments });
}
