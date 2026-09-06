import mongoose from 'mongoose';

export const RICE_VARIETIES = [
  'Jasmine',
  'Sinandomeng',
  'Brown Rice',
  'Black Rice',
  'Red Rice',
  'Glutinous (Malagkit)',
  'Other',
];

const weightTierSchema = new mongoose.Schema({
  weightKg: { type: Number, required: true, min: 1 },
  discountPercent: { type: Number, required: true, min: 0, max: 100, default: 0 },
}, { _id: false });

const productSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true,
  },
  variety: {
    type: String,
    required: true,
    enum: RICE_VARIETIES,
  },
  price: {
    type: Number,
    required: true,
    min: 1,
  },
  description: {
    type: String,
    trim: true,
    required: true,
  },
  stock: {
    type: Number,
    required: true,
    min: 0,
    default: 0,
  },
  lowStockThreshold: {
    type: Number,
    required: true,
    min: 0,
    default: 20,
  },
  /**
   * Units actually sold. Moves with `stockDeducted` on the order, so a
   * confirmed order counts and a cancelled one gives the count back — a
   * checkout that never ships must not inflate this.
   */
  soldCount: {
    type: Number,
    default: 0,
    min: 0,
  },
  weightTiers: {
    type: [weightTierSchema],
    default: [],
  },
  images: {
    type: [String],
    default: [],
  },
  status: {
    type: String,
    enum: ['active', 'inactive'],
    default: 'active',
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
  createdBy: {
    type: Number, // Storing the integer userId
    required: true,
  },
});

productSchema.pre('save', async function() {
  this.updatedAt = Date.now();
  // ✅ No next() call needed because the function is async
});

const Product = mongoose.model('Product', productSchema);

export default Product;
