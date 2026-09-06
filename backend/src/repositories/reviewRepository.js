import Review from '../models/Review.js';
import Order from '../models/Order.js';

export const createReview = async (data) => Review.create(data);

export const findByProduct = async (productId, { limit = 50 } = {}) =>
  Review.find({ productId, hidden: false }).sort({ createdAt: -1 }).limit(limit).lean();

export const findBySeller = async (sellerId, { limit = 100 } = {}) =>
  Review.find({ sellerId, hidden: false }).sort({ createdAt: -1 }).limit(limit).lean();

export const findByOrder = async (orderId) => Review.findOne({ orderId });

export const findById = async (id) => Review.findById(id);

/** The completed order that entitles this buyer to review this product. */
export const findReviewableOrder = async (orderId, buyerUserId) =>
  Order.findOne({ _id: orderId, buyerUserId, status: 'completed' });

/** Star breakdown plus the average, for a product or a whole seller. */
/**
 * One aggregate for a whole page of products. Asking per product turns a
 * 20-item catalog into 21 round trips.
 */
export const getRatingMapForProducts = async (productIds) => {
  if (!productIds?.length) return new Map();

  const rows = await Review.aggregate([
    { $match: { productId: { $in: productIds } } },
    { $group: { _id: '$productId', average: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);

  return new Map(
    rows.map((row) => [
      String(row._id),
      { averageRating: Math.round(row.average * 10) / 10, reviewCount: row.count },
    ])
  );
};

/** The seller-side twin of getRatingMapForProducts, for the shop directory. */
export const getRatingMapForSellers = async (sellerIds) => {
  if (!sellerIds?.length) return new Map();

  const rows = await Review.aggregate([
    { $match: { sellerId: { $in: sellerIds }, hidden: false } },
    { $group: { _id: '$sellerId', average: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);

  return new Map(
    rows.map((row) => [
      row._id,
      { averageRating: Math.round(row.average * 10) / 10, reviewCount: row.count },
    ])
  );
};

export const getRatingSummary = async (match) => {
  const [totals] = await Review.aggregate([
    { $match: { ...match, hidden: false } },
    { $group: { _id: null, average: { $avg: '$rating' }, count: { $sum: 1 } } },
  ]);

  const spread = await Review.aggregate([
    { $match: { ...match, hidden: false } },
    { $group: { _id: '$rating', count: { $sum: 1 } } },
  ]);

  const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  for (const s of spread) breakdown[s._id] = s.count;

  return {
    average: totals ? Math.round(totals.average * 10) / 10 : 0,
    count: totals?.count || 0,
    breakdown,
  };
};

export const addSellerReply = async (id, text) =>
  Review.findByIdAndUpdate(
    id,
    { sellerReply: { text, repliedAt: new Date() } },
    { returnDocument: 'after' }
  );
