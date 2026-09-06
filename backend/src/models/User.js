import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

/**
 * "Reyca De Alba" and "reyca  de alba" are the same person claiming the same
 * name, so both collapse to one key. Comparing the raw field would let either
 * spelling slip past a check on the other.
 */
export function toNameKey(name) {
  return typeof name === 'string'
    ? name.trim().toLowerCase().replace(/\s+/g, ' ')
    : '';
}

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  /**
   * Derived from `name` on every save; never set by hand. Kept as its own
   * field so the uniqueness check is an indexed lookup rather than a regex
   * scan over every user.
   */
  nameKey: {
    type: String,
    index: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  password: {
    type: String,
    required: false,
    minlength: 6,
    select: false
  },
  firebaseUid: {
    type: String,
    unique: true,
    sparse: true,
    index: true
  },
  emailVerified: {
    type: Boolean,
    default: false
  },
  role: {
    type: String,
    enum: ['superadmin', 'seller', 'buyer'],
    default: 'buyer'
  },
  status: {
    type: String,
    enum: ['active', 'suspended', 'pending'],
    default: function () {
      return this.role === 'seller' ? 'pending' : 'active';
    }
  },
  userId: { type: Number, unique: true },
  lastLogin: {
    type: Date
  },
  contact: { type: String, trim: true, default: '' },
  bio: { type: String, trim: true, default: '' },
  avatarUrl: { type: String, default: '' },
  /**
   * Not every rice seller farms. A trader or retailer has a business but no
   * land, so the farm fields below are only meaningful for `farmer`.
   */
  sellerType: {
    type: String,
    enum: ['farmer', 'trader', 'retailer', 'cooperative', ''],
    default: '',
  },
  sellerProfile: {
    businessName: { type: String, trim: true, default: '' },
    businessAddress: { type: String, trim: true, default: '' },
    // Farmer-only
    farmName: { type: String, trim: true, default: '' },
    farmLocation: { type: String, trim: true, default: '' },
    farmSize: { type: String, trim: true, default: '' },
    farmPhotos: { type: [String], default: [] },
  },

  /**
   * Compliance documents. The image itself is never shown after review — the
   * app displays a verified badge instead, so there is nothing on screen to
   * screenshot or steal.
   */
  documents: [{
    type: {
      type: String,
      enum: ['BIR', 'DTI', 'SEC', 'MAYORS_PERMIT', 'BARANGAY', 'ORGANIC_CERT', 'OTHER'],
      required: true,
    },
    file: { type: String, required: true },
    label: { type: String, trim: true, default: '' },
    referenceNo: { type: String, trim: true, default: '' },
    status: {
      type: String,
      enum: ['pending', 'verified', 'rejected'],
      default: 'pending',
    },
    rejectionReason: { type: String, trim: true, default: '' },
    uploadedAt: { type: Date, default: Date.now },
    reviewedAt: { type: Date },
    reviewedBy: { type: Number },
  }],
  /**
   * Where this seller gets paid. The buyer scans the QR in their own GCash app
   * and the seller confirms the money arrived - AgriFair never touches the funds
   * and never stores a payment credential, only a picture of a QR code.
   */
  payout: {
    method: { type: String, enum: ['gcash', 'bank', ''], default: '' },
    accountName: { type: String, trim: true, default: '' },
    accountNumber: { type: String, trim: true, default: '' },
    qrImage: { type: String, default: '' },
    status: {
      type: String,
      enum: ['unset', 'pending', 'verified', 'rejected'],
      default: 'unset',
    },
    rejectionReason: { type: String, trim: true, default: '' },
    submittedAt: { type: Date },
    verifiedAt: { type: Date },
    verifiedBy: { type: Number },
  },
  pickupAddress: { type: String, trim: true, default: '' },

  /**
   * Where a buyer wants their rice delivered. A list rather than one field:
   * people order to a home and a workplace, and retyping the whole thing at
   * every checkout is how a wrong address gets entered.
   *
   * Exactly one carries isDefault - the service enforces that, since two
   * defaults means checkout has to guess.
   */
  addresses: [{
    label: { type: String, trim: true, default: 'Home' },
    fullName: { type: String, trim: true, required: true },
    contact: { type: String, trim: true, required: true },
    line: { type: String, trim: true, required: true },
    barangay: { type: String, trim: true, default: '' },
    city: { type: String, trim: true, required: true },
    province: { type: String, trim: true, default: '' },
    // "Green gate beside the sari-sari store" - what actually gets a rider
    // to the door.
    notes: { type: String, trim: true, default: '' },
    isDefault: { type: Boolean, default: false },
  }],
  deliveryOrigin: { type: String, trim: true, default: '' },
  notificationPrefs: {
    order: { type: Boolean, default: true },
    payment: { type: Boolean, default: true },
    message: { type: Boolean, default: true },
    stock: { type: Boolean, default: true },
    system: { type: Boolean, default: true },
  },
  theme: { type: String, enum: ['light', 'dark'], default: 'light' },
}, {
  timestamps: true
});

userSchema.pre('save', function () {
  if (this.isModified('name') || this.isNew) {
    this.nameKey = toNameKey(this.name);
  }
});

userSchema.pre('save', async function () {
  if (!this.isModified('password') || !this.password) return;
  this.password = await bcrypt.hash(this.password, 12);
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  if (!this.password) return false;
  return bcrypt.compare(candidatePassword, this.password);
};

const User = mongoose.model('User', userSchema);
export default User;
