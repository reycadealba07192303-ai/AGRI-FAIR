import mongoose from 'mongoose';

const cartItemSchema = new mongoose.Schema({
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  sellerId: { type: Number, required: true },

  /**
   * Which weight tier this line is - 1, 5, 25, 50 kg. The same rice at two
   * weights is two lines, because they are two different purchases at two
   * different per-kilo prices.
   *
   * Defaults to 1 so carts saved before tiers existed still price as kilos.
   */
  weightKg: { type: Number, required: true, min: 1, default: 1 },

  /** How many sacks of [weightKg] - not kilograms. */
  quantity: { type: Number, required: true, min: 1 },
  /**
   * Price of one sack at this tier when it was added. Snapshotted so a price
   * change mid-shopping is visible rather than silent.
   */
  unitPriceAtAdd: { type: Number, required: true, min: 0 },
  addedAt: { type: Date, default: Date.now },
}, { _id: false });

const cartSchema = new mongoose.Schema({
  buyerUserId: { type: Number, required: true, unique: true, index: true },
  items: { type: [cartItemSchema], default: [] },
}, { timestamps: true });

const Cart = mongoose.model('Cart', cartSchema);
export default Cart;
