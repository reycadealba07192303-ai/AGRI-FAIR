import express from 'express';
import { otpRequestLimiter, otpSubmitLimiter } from '../middleware/rateLimiter.js';
import {
  register,
  login,
  logout,
  resendVerification,
  verifyEmailOtp,
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
router.post('/verify-reset-otp', otpSubmitLimiter, verifyResetOtp);
router.post('/reset-password', otpSubmitLimiter, resetPassword);

export default router;
