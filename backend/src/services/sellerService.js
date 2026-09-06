import Product from '../models/Product.js';
import { findUserByUserIdSafe } from '../repositories/userRepository.js';
import { getRatingSummary } from '../repositories/reviewRepository.js';

/**
 * A seller's public face, for a buyer deciding whether to trust them.
 *
 * Everything here is deliberately chosen. Compliance documents prove a seller
 * is real, but the files themselves never leave the review desk - a buyer sees
 * that a permit was verified and which kind, never the permit. The same goes
 * for payout: that money can be sent is worth knowing; the account number is
 * not the buyer's business. Email and contact stay private too, since the app
 * already has chat.
 */
function toPublicProfile(user, stats) {
  const documents = user.documents || [];
  const verifiedDocs = documents.filter((doc) => doc.status === 'verified');

  return {
    id: user.userId,
    name: user.name,
    avatarUrl: user.avatarUrl || '',
    bio: user.bio || '',
    sellerType: user.sellerType || '',
    memberSince: user.createdAt,

    businessName: user.sellerProfile?.businessName || '',
    // A trader or retailer has no farm, so these come back empty rather than
    // as blank labels the app has to hide.
    farmName: user.sellerProfile?.farmName || '',
    farmLocation: user.sellerProfile?.farmLocation || '',
    farmSize: user.sellerProfile?.farmSize || '',
    farmPhotos: user.sellerProfile?.farmPhotos || [],

    /**
     * Two things have to be true: a Super Admin approved the account, and at
     * least one compliance document was checked and passed. Either alone is
     * weaker than a badge suggests.
     */
    isVerified: user.status === 'active' && verifiedDocs.length > 0,
    verifiedCredentials: verifiedDocs.map((doc) => doc.type),
    acceptsGcash: user.payout?.status === 'verified',

    averageRating: stats.averageRating,
    reviewCount: stats.reviewCount,
    productCount: stats.productCount,
    totalSold: stats.totalSold,
  };
}

export const sellerService = {
  async getPublicProfile(userId) {
    if (!Number.isFinite(userId)) throw new Error('Invalid seller id');

    const user = await findUserByUserIdSafe(userId);
    if (!user || user.role !== 'seller') {
      throw new Error('Seller not found');
    }

    const [rating, products] = await Promise.all([
      getRatingSummary({ sellerId: userId }),
      Product.find({ createdBy: userId, status: 'active' }).select('soldCount'),
    ]);

    return toPublicProfile(user, {
      averageRating: rating.average ? Math.round(rating.average * 10) / 10 : 0,
      reviewCount: rating.count || 0,
      productCount: products.length,
      totalSold: products.reduce((sum, p) => sum + (p.soldCount || 0), 0),
    });
  },

  /** Only active listings - a buyer browsing a shop should not meet hidden ones. */
  async getPublicProducts(userId) {
    if (!Number.isFinite(userId)) throw new Error('Invalid seller id');

    return Product.find({ createdBy: userId, status: 'active' }).sort({
      createdAt: -1,
    });
  },
};
