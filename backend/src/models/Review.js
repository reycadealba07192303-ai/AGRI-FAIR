import mongoose from 'mongoose';

const reviewSchema = new mongoose.Schema({
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
    index: true,
  },
  sellerId: {
    type: Number, // seller's User.userId
    required: true,
    index: true,
  },
  buyerUserId: {
    type: Number,
    required: true,
    index: true,
  },
  buyerName: {
    type: String,
    required: true,
    trim: true,
  },
  /**
   * The completed order this review is for. Reviews are only accepted from a
   * buyer who actually received the goods, which is what stops a competitor or
   * a bot from burying a seller under fake one-star ratings.
   */
  orderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Order',
    required: true,
  },
  rating: {
    type: Number,
    required: true,
    min: 1,
    max: 5,
  },
  comment: {
    type: String,
    trim: true,
    default: '',
    maxlength: 1000,
  },
  images: {
    type: [String],
    default: [],
    validate: [(v) => v.length <= 4, 'At most 4 photos per review'],
  },
  /** The seller may answer publicly, once. */
  sellerReply: {
    text: { type: String, trim: true, default: '' },
    repliedAt: { type: Date },
  },
  hidden: {
    type: Boolean,
    default: false,
  },
}, { timestamps: true });

// One review per order, so a buyer cannot rate the same purchase repeatedly.
reviewSchema.index({ orderId: 1 }, { unique: true });
reviewSchema.index({ productId: 1, createdAt: -1 });

const Review = mongoose.model('Review', reviewSchema);
export default Review;
