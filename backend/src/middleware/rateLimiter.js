import rateLimit from 'express-rate-limit';

/**
 * A plain-text body reaches the clients as an unparseable response, so the
 * person sees "something went wrong" instead of "you tried too often". Every
 * limiter below answers in the same envelope the rest of the API uses.
 */
const tooMany = (message) => ({ success: false, message });

export const passwordLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: tooMany('Too many password attempts. Try again later.'),
});

/**
 * Each of these costs an outgoing email, so the budget stays small.
 */
export const otpRequestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
  message: tooMany('Too many codes requested. Wait a few minutes and try again.'),
});

/**
 * Submitting a code is cheap and the code itself already dies after five wrong
 * tries, so this only exists to stop someone grinding through many codes.
 *
 * It must be its own limiter: sharing one budget with the request side meant a
 * whole reset - ask for a code, mistype it once, retype it, set the password -
 * ran out of requests halfway through, and the per-code attempt counter could
 * never be reached.
 */
export const otpSubmitLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 20,
  message: tooMany('Too many attempts. Wait a few minutes and try again.'),
});
