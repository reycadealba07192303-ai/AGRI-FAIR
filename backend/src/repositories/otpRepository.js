import EmailOtp from '../models/EmailOtp.js';

export const otpRepository = {
  /**
   * A new code retires every earlier one for that address and purpose, so a
   * user who taps "Resend" three times still ends up with exactly one code
   * that works.
   */
  async consumeAllFor(email, purpose) {
    return EmailOtp.updateMany(
      { email, purpose, consumedAt: null },
      { consumedAt: new Date() }
    );
  },

  async create({ email, purpose, codeHash, expiresAt }) {
    return EmailOtp.create({ email, purpose, codeHash, expiresAt });
  },

  async findActive(email, purpose) {
    return EmailOtp.findOne({
      email,
      purpose,
      consumedAt: null,
      expiresAt: { $gt: new Date() }
    }).sort({ createdAt: -1 });
  },

  async countRecent(email, purpose, since) {
    return EmailOtp.countDocuments({ email, purpose, createdAt: { $gte: since } });
  },

  async recordAttempt(id) {
    return EmailOtp.findByIdAndUpdate(id, { $inc: { attempts: 1 } }, { new: true });
  },

  async markConsumed(id) {
    return EmailOtp.findByIdAndUpdate(id, { consumedAt: new Date() }, { new: true });
  }
};
