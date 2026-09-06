import mongoose from 'mongoose';

const cartItemSchema = new mongoose.Schema({
  productId: { type: mongoose.Schema.Types.ObjectId, ref: 'Product', required: true },
  sellerId: { type: Number, required: true },
  quantity: { type: Number, required: true, min: 1 },
  /** Snapshot so a price change mid-shopping is visible rather than silent. */
  unitPriceAtAdd: { type: Number, required: true, min: 0 },
  addedAt: { type: Date, default: Date.now },
}, { _id: false });

const cartSchema = new mongoose.Schema({
  buyerUserId: { type: Number, required: true, unique: true, index: true },
  items: { type: [cartItemSchema], default: [] },
}, { timestamps: true });

const Cart = mongoose.model('Cart', cartSchema);
export default Cart;
