import express from 'express';
import { protect } from '../middleware/authMiddleware.js';
import {
  listShops,
  getSellerProfile,
  getSellerPayment,
  getSellerProducts,
} from '../controllers/sellerController.js';

const router = express.Router();

// Public on purpose: a buyer weighs up a seller before signing in, and the
// payload carries nothing private - a verified badge, not the documents.
// Before '/:id', or Express would read "shops" as an id.
router.get('/', listShops);
router.get('/:id', getSellerProfile);
router.get('/:id/products', getSellerProducts);

// Signed in only. The profile withholds account numbers on purpose; a buyer
// about to send money is a different case from a passer-by.
router.get('/:id/payment', protect, getSellerPayment);

export default router;
