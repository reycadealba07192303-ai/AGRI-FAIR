import express from 'express';
import { protect } from '../middleware/authMiddleware.js';
import * as cartService from '../services/cartService.js';

const router = express.Router();
router.use(protect);

const handle = (fn) => async (req, res) => {
  try {
    res.json(await fn(req));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
};

router.get('/', handle((req) => cartService.getCart(req.user.userId)));
router.post('/items', handle((req) => cartService.addItem(req.user.userId, req.body || {})));
router.put('/items/:productId', handle((req) => cartService.setQuantity(req.user.userId, req.params.productId, req.body?.quantity)));
router.delete('/items/:productId', handle((req) => cartService.removeItem(req.user.userId, req.params.productId)));
router.delete('/', handle((req) => cartService.clearCart(req.user.userId)));
router.post('/checkout', handle((req) => cartService.checkout(req.user.userId, req.body || {})));

export default router;
