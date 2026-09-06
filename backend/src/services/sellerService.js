import Product from '../models/Product.js';
import User from '../models/User.js';
import { findUserByUserIdSafe } from '../repositories/userRepository.js';
import { getRatingSummary, getRatingMapForSellers } from '../repositories/reviewRepository.js';

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

  /**
   * The shop directory. Only sellers with something to sell appear: a buyer
   * browsing shops has no use for an empty one, and an approved account with
   * no listings is not yet a shop.
   */
  async listShops() {
    // One grouped query rather than a lookup per seller - a directory of
    // twenty shops would otherwise be twenty-one round trips.
    const counts = await Product.aggregate([
      { $match: { status: 'active' } },
      {
        $group: {
          _id: '$createdBy',
          productCount: { $sum: 1 },
          totalSold: { $sum: { $ifNull: ['$soldCount', 0] } },
          varieties: { $addToSet: '$variety' },
          fromPrice: { $min: '$price' },
        },
      },
      { $sort: { totalSold: -1 } },
    ]);

    if (!counts.length) return [];

    const sellerIds = counts.map((row) => row._id);
    const [sellers, ratings] = await Promise.all([
      User.find({ userId: { $in: sellerIds }, role: 'seller', status: 'active' }),
      getRatingMapForSellers(sellerIds),
    ]);

    const byId = new Map(sellers.map((user) => [user.userId, user]));

    return counts
      .filter((row) => byId.has(row._id))
      .map((row) => {
        const user = byId.get(row._id);
        const documents = user.documents || [];
        const rating = ratings.get(row._id) || { averageRating: 0, reviewCount: 0 };

        return {
          id: user.userId,
          name: user.name,
          businessName: user.sellerProfile?.businessName || '',
          avatarUrl: user.avatarUrl || '',
          sellerType: user.sellerType || '',
          farmLocation: user.sellerProfile?.farmLocation || '',
          isVerified: documents.some((doc) => doc.status === 'verified'),
          productCount: row.productCount,
          totalSold: row.totalSold,
          // What they actually stock, so a shop card can say so without the
          // app fetching every listing to find out.
          varieties: row.varieties.filter(Boolean).sort(),
          fromPrice: row.fromPrice,
          averageRating: rating.averageRating,
          reviewCount: rating.reviewCount,
        };
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
