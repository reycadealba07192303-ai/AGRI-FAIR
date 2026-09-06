import mongoose from 'mongoose';

export const OTP_TTL_MINUTES = 10;
export const OTP_MAX_ATTEMPTS = 5;

/**
 * One code machine, two jobs. Keeping signup and password reset in the same
 * collection means the expiry, attempt cap and hashing are written once —
 * and a code issued for one purpose can never be spent on the other.
 */
export const OTP_PURPOSES = {
  signup: 'signup',
  passwordReset: 'password-reset',
};

const emailOtpSchema = new mongoose.Schema(
  {
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true
    },
    purpose: {
      type: String,
      required: true,
      enum: Object.values(OTP_PURPOSES)
    },
    /**
     * Only the hash is stored. A leaked database read must not hand anyone a
     * working code, the same reason the password itself is hashed.
     */
    codeHash: {
      type: String,
      required: true
    },
    expiresAt: {
      type: Date,
      required: true
    },
    attempts: {
      type: Number,
      default: 0
    },
    consumedAt: {
      type: Date,
      default: null
    }
  },
  { timestamps: true }
);

emailOtpSchema.index({ email: 1, purpose: 1 });

// Mongo drops the document itself once expiresAt passes, so abandoned requests
// clean up without a cron job.
emailOtpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const EmailOtp = mongoose.model('EmailOtp', emailOtpSchema);

export default EmailOtp;
