import express from 'express';
import { protect } from '../middleware/authMiddleware.js';
import * as deliveryService from '../services/deliveryService.js';

const router = express.Router();

// Seller/courier pushes the current position.
router.put('/:orderId/location', protect, async (req, res) => {
  try {
    res.json(await deliveryService.updateLocation(req.params.orderId, req.user.userId, req.body || {}));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// Buyer and seller both poll this.
router.get('/:orderId', protect, async (req, res) => {
  try {
    res.json(await deliveryService.getTracking(req.params.orderId, req.user));
  } catch (error) {
    res.status(403).json({ error: error.message });
  }
});

export default router;
