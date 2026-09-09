import express from 'express';
import { otpRequestLimiter, otpSubmitLimiter } from '../middleware/rateLimiter.js';
import {
  register,
  login,
  logout,
  resendVerification,
  verifyEmailOtp,
  activateAccount,
  startDeliverySetup,
  forgotPassword,
  verifyResetOtp,
  resetPassword
} from '../controllers/authController.js';

const router = express.Router();

router.post('/register', register);
router.post('/login', login);
router.post('/logout', logout);

// Asking for a code sends mail; submitting one does not. They are limited
// separately so a person working through a normal flow - request, mistype,
// retype, finish - never runs out partway.
router.post('/resend-verification', otpRequestLimiter, resendVerification);
router.post('/forgot-password', otpRequestLimiter, forgotPassword);

router.post('/verify-email-otp', otpSubmitLimiter, verifyEmailOtp);
// A delivery person setting up the account their shop made for them. The
// first call says whether there is one and sends the code; the second sets the
// password once the code checks out.
router.post('/delivery/start', otpRequestLimiter, startDeliverySetup);
router.post('/activate', otpSubmitLimiter, activateAccount);
router.post('/verify-reset-otp', otpSubmitLimiter, verifyResetOtp);
router.post('/reset-password', otpSubmitLimiter, resetPassword);

export default router;
