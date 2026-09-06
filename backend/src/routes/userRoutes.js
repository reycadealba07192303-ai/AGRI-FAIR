import express from 'express';
import { protect } from '../middleware/authMiddleware.js';
import { passwordLimiter } from '../middleware/rateLimiter.js';
import upload from '../middleware/multerMiddleware.js';
import {
  getMe,
  updateProfile,
  updatePassword,
  getLoginHistory
} from '../controllers/userController.js';

const router = express.Router();

const profileUpload = upload.fields([
  { name: 'avatar', maxCount: 1 },
  { name: 'farmPhotos', maxCount: 5 },
  { name: 'paymentQr', maxCount: 1 },
  { name: 'document', maxCount: 1 },
]);

router.get('/me', protect, getMe);
router.put('/edit', protect, profileUpload, updateProfile);
router.put('/reset-password', protect, passwordLimiter, updatePassword);
router.get('/login-history', protect, getLoginHistory);

export default router;