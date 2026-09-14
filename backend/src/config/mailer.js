import nodemailer from 'nodemailer';
import MailComposer from 'nodemailer/lib/mail-composer/index.js';

let transporter = null;
let gmailToken = null; // { value, expiresAt }

const GMAIL_SEND_URL =
  'https://gmail.googleapis.com/upload/gmail/v1/users/me/messages/send?uploadType=media';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

/**
 * Two ways to send, picked by what is configured:
 *
 * - GMAIL_CLIENT_ID/GMAIL_CLIENT_SECRET/GMAIL_REFRESH_TOKEN: the Gmail API
 *   over HTTPS (port 443). Use this on Railway — Railway blocks outbound SMTP
 *   (25/465/587) on non-Pro plans, so Gmail SMTP only ever times out there.
 *   Nodemailer still builds the message; only the delivery changes.
 * - SMTP_HOST/SMTP_USER/SMTP_PASS: plain SMTP, fine for local development.
 *
 * Mail is optional: the app runs fine without either, and anything that sends
 * mail reports a clear "not configured" instead of crashing.
 *
 * For Gmail SMTP, SMTP_PASS must be an App Password, not the account password —
 * Google rejects plain passwords from SMTP.
 */
function useGmailApi() {
  const { GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN } = process.env;
  return Boolean(GMAIL_CLIENT_ID && GMAIL_CLIENT_SECRET && GMAIL_REFRESH_TOKEN);
}

function smtpConfigured() {
  return Boolean(process.env.SMTP_HOST && process.env.SMTP_USER && process.env.SMTP_PASS);
}

export function getMailer() {
  if (transporter) return transporter;
  if (!smtpConfigured()) return null;

  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS } = process.env;
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
  return useGmailApi() || smtpConfigured();
}

/**
 * Access tokens last about an hour; the refresh token does not expire as long
 * as the OAuth app is "In production" and the account keeps its access.
 */
async function getGmailAccessToken() {
  if (gmailToken && gmailToken.expiresAt > Date.now()) return gmailToken.value;

  const res = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: process.env.GMAIL_CLIENT_ID,
      client_secret: process.env.GMAIL_CLIENT_SECRET,
      refresh_token: process.env.GMAIL_REFRESH_TOKEN,
      grant_type: 'refresh_token',
    }),
    signal: AbortSignal.timeout(10000),
  });

  if (!res.ok) {
    const detail = await res.text().catch(() => '');
    throw new Error(`Google refused the Gmail token refresh (${res.status}): ${detail}`);
  }

  const { access_token, expires_in } = await res.json();
  gmailToken = { value: access_token, expiresAt: Date.now() + (expires_in - 60) * 1000 };
  return access_token;
}

async function sendViaGmailApi(message) {
  const raw = await new MailComposer(message).compile().build();
  const token = await getGmailAccessToken();

  const res = await fetch(GMAIL_SEND_URL, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': 'message/rfc822' },
    body: raw,
    signal: AbortSignal.timeout(20000),
  });

  if (!res.ok) {
    if (res.status === 401) gmailToken = null;
    const detail = await res.text().catch(() => '');
    throw new Error(`Gmail API rejected the email (${res.status}): ${detail}`);
  }

  return res.json();
}

export async function sendMail({ to, subject, html, attachments }) {
  if (!isMailConfigured()) {
    throw new Error(
      'Email is not set up. Add GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET and GMAIL_REFRESH_TOKEN (or SMTP_HOST, SMTP_USER and SMTP_PASS) to backend/.env, then restart the server.'
    );
  }

  const from = process.env.MAIL_FROM || `AgriFair <${process.env.SMTP_USER}>`;
  const message = { from, to, subject, html, attachments };

  if (useGmailApi()) return sendViaGmailApi(message);
  return getMailer().sendMail(message);
}
