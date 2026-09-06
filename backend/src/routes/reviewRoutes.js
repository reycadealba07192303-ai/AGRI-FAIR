import express from 'express';
import { protect } from '../middleware/authMiddleware.js';
import upload from '../middleware/multerMiddleware.js';
import * as reviewService from '../services/reviewService.js';

const router = express.Router();

// ---- Public: anyone browsing may read ratings ----
router.get('/product/:productId', async (req, res) => {
  try {
    res.json(await reviewService.getProductReviews(req.params.productId));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

router.get('/seller/:sellerId', async (req, res) => {
  try {
    res.json(await reviewService.getSellerReviews(Number(req.params.sellerId)));
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ---- Buyer: leave a review, with up to 4 photos ----
router.post('/', protect, upload.array('images', 4), async (req, res) => {
  try {
    const images = (req.files || []).map((f) => `/uploads/media/${f.filename}`);
    const review = await reviewService.createReview(req.user.userId, {
      orderId: req.body.orderId,
      rating: req.body.rating,
      comment: req.body.comment,
      images,
    });
    res.status(201).json(review);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

// ---- Seller: reply once to a review on their product ----
router.post('/:id/reply', protect, async (req, res) => {
  try {
    const review = await reviewService.replyToReview(req.params.id, req.user.userId, req.body.text);
    res.json(review);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
});

export default router;
