import mongoose from 'mongoose';

export const ORDER_STATUSES = [
  'pending',
  'confirmed',
  'processing',
  'shipped',
  'delivered',
  'completed',
  'cancelled',
];

const statusHistoryEntrySchema = new mongoose.Schema({
  status: { type: String, required: true },
  changedAt: { type: Date, default: Date.now },
  reason: { type: String, default: '' },
}, { _id: false });

const orderSchema = new mongoose.Schema({
  sellerId: {
    type: Number, // seller's User.userId
    required: true,
    index: true,
  },
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true,
  },
  productName: {
    type: String,
    required: true,
  },
  unitPrice: {
    type: Number,
    required: true,
    min: 0,
  },
  quantity: {
    type: Number,
    required: true,
    min: 1,
  },
  subtotal: {
    type: Number,
    required: true,
    min: 0,
  },
  deliveryFee: {
    type: Number,
    default: 0,
    min: 0,
  },
  total: {
    type: Number,
    required: true,
    min: 0,
  },
  paymentMethod: {
    type: String,
    enum: ['Cash/COD', 'GCash', 'PayMongo'],
    default: 'Cash/COD',
  },
  customerName: {
    type: String,
    required: true,
    trim: true,
  },
  customerContact: {
    type: String,
    trim: true,
    default: '',
  },
  deliveryAddress: {
    type: String,
    trim: true,
    default: '',
  },
  buyerUserId: {
    type: Number,
    default: null,
  },
  /**
   * Payment tracking is separate from fulfilment: an order can be delivered but
   * unpaid, or paid but not yet shipped.
   *   unpaid        - nothing received yet (the COD default)
   *   proof_sent    - buyer uploaded a GCash screenshot, waiting on the seller
   *   paid          - the seller confirmed the money landed in their account
   *   rejected      - the seller checked and the payment was not there
   */
  /**
   * Live delivery tracking, used once the order is `shipped`. The courier's app
   * pushes a position; the buyer and the seller both read it. Coordinates are
   * kept only while the order is in transit and cleared on completion.
   */
  delivery: {
    courierName: { type: String, trim: true, default: '' },
    courierContact: { type: String, trim: true, default: '' },
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
    updatedAt: { type: Date },
    etaMinutes: { type: Number, default: null },
    isLive: { type: Boolean, default: false },
  },

  paymentStatus: {
    type: String,
    enum: ['unpaid', 'proof_sent', 'paid', 'rejected'],
    default: 'unpaid',
  },
  paymentProof: { type: String, default: '' },
  paymentReference: { type: String, trim: true, default: '' },
  paymentNote: { type: String, trim: true, default: '' },
  amountPaid: { type: Number, default: 0, min: 0 },
  paidAt: { type: Date },
  paymentReviewedAt: { type: Date },

  status: {
    type: String,
    enum: ORDER_STATUSES,
    default: 'pending',
  },
  statusReason: {
    type: String,
    trim: true,
    default: '',
  },
  statusHistory: {
    type: [statusHistoryEntrySchema],
    default: [],
  },
  stockDeducted: {
    type: Boolean,
    default: false,
  },
  source: {
    type: String,
    enum: ['manual', 'storefront'],
    default: 'manual',
  },
  orderNumber: {
    type: String,
  },
  /**
   * A cart checkout produces one Order row per line item, because every seller
   * fulfils and gets paid separately. The rows share a groupId so the buyer
   * still sees a single order with several items on it.
   */
  groupId: {
    type: String,
    index: true,
    default: null,
  },
  orderDate: {
    type: Date,
    default: Date.now,
  },
  notes: {
    type: String,
    trim: true,
    default: '',
  },
}, {
  timestamps: true,
});

orderSchema.index({ sellerId: 1, orderDate: -1 });
orderSchema.index({ status: 1 });

const Order = mongoose.model('Order', orderSchema);
export default Order;
