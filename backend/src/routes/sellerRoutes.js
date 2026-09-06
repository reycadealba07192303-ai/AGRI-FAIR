import express from 'express';
import { getSellerProfile, getSellerProducts } from '../controllers/sellerController.js';

const router = express.Router();

// Public on purpose: a buyer weighs up a seller before signing in, and the
// payload carries nothing private - a verified badge, not the documents.
router.get('/:id', getSellerProfile);
router.get('/:id/products', getSellerProducts);

export default router;
