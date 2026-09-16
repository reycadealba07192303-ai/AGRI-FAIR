/**
 * One email per address per minute, for anything that sends a code or a link.
 *
 * The stored codes already carry this for real accounts (see otpService), but
 * a request for an address with no account sends nothing and stores nothing -
 * so without this, "wait a minute" would only ever be said about registered
 * emails, and the cooldown itself would tell a stranger which ones exist.
 * Every request is counted here first, account or not, so both answer alike.
 *
 * Kept in memory: it is a speed bump in front of the database limits, not the
 * limit itself. A restart forgets it; the per-code window in otpService and the
 * route rate limiters do not.
 */

export const SEND_COOLDOWN_SECONDS = 60;

const lastSent = new Map();

export function cooldownError(retryAfter, message) {
  const err = new Error(
    message || `A code was just sent. Use that one, or wait ${retryAfter} seconds to get a new one.`
  );
  err.code = 'RESEND_COOLDOWN';
  err.retryAfter = retryAfter;
  return err;
}

/** Seconds still to wait since `since`, or 0 when a new send is allowed. */
export function secondsLeft(since, now = Date.now()) {
  if (!since) return 0;
  const waited = (now - new Date(since).getTime()) / 1000;
  return waited < SEND_COOLDOWN_SECONDS ? Math.ceil(SEND_COOLDOWN_SECONDS - waited) : 0;
}

/**
 * Gives the slot back, for a send that failed - the person got nothing, so
 * they should not have to wait a minute to try again.
 */
export function releaseSendSlot(key) {
  lastSent.delete(key);
}

/**
 * Takes the send slot for `key` (for example "reset:juan@gmail.com"), or throws
 * RESEND_COOLDOWN with how long to wait.
 */
export function claimSendSlot(key) {
  const now = Date.now();

  // Forget anything past its minute, so the map only ever holds the last one.
  for (const [k, at] of lastSent) {
    if (now - at >= SEND_COOLDOWN_SECONDS * 1000) lastSent.delete(k);
  }

  const wait = secondsLeft(lastSent.get(key), now);
  if (wait > 0) throw cooldownError(wait);

  lastSent.set(key, now);
}
