import * as reviewRepo from '../repositories/reviewRepository.js';
import { findUserByUserId } from '../repositories/userRepository.js';

/**
 * A buyer may review only a product they actually received, and only once per
 * order. Without that rule a rating is just an anonymous comment box.
 */
export const createReview = async (buyerUserId, { orderId, rating, comment, images = [] }) => {
  const stars = Number(rating);
  if (!orderId) throw new Error('Which order is this review for?');
  if (!Number.isInteger(stars) || stars < 1 || stars > 5) {
    throw new Error('Give a rating from 1 to 5 stars.');
  }

  const order = await reviewRepo.findReviewableOrder(orderId, buyerUserId);
  if (!order) {
    throw new Error('You can only review an order you received and that is marked completed.');
  }

  const existing = await reviewRepo.findByOrder(orderId);
  if (existing) throw new Error('You already reviewed this order.');

  const buyer = await findUserByUserId(buyerUserId);

  return reviewRepo.createReview({
    productId: order.productId,
    sellerId: order.sellerId,
    buyerUserId,
    buyerName: buyer?.name || order.customerName || 'AgriFair buyer',
    orderId: order._id,
    rating: stars,
    comment: (comment || '').trim(),
    images: images.slice(0, 4),
  });
};

export const getProductReviews = async (productId) => {
  const [reviews, summary] = await Promise.all([
    reviewRepo.findByProduct(productId),
    reviewRepo.getRatingSummary({ productId }),
  ]);
  return { ...summary, reviews };
};

export const getSellerReviews = async (sellerId) => {
  const [reviews, summary] = await Promise.all([
    reviewRepo.findBySeller(sellerId),
    reviewRepo.getRatingSummary({ sellerId }),
  ]);
  return { ...summary, reviews };
};

/** The seller answers a review on their own product, once. */
export const replyToReview = async (reviewId, sellerId, text) => {
  const body = (text || '').trim();
  if (!body) throw new Error('Write a reply first.');

  const review = await reviewRepo.findById(reviewId);
  if (!review) throw new Error('Review not found');
  if (review.sellerId !== sellerId) throw new Error('That review is not on your product.');
  if (review.sellerReply?.text) throw new Error('You already replied to this review.');

  return reviewRepo.addSellerReply(reviewId, body);
};
