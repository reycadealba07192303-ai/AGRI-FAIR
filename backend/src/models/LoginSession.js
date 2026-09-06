import mongoose from 'mongoose';

const loginSessionSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
  },
  ipAddress: {
    type: String,
  },
  userAgent: {
    type: String,
  },
  loggedInAt: {
    type: Date,
    default: Date.now,
  }
}, { timestamps: true });

const LoginSession = mongoose.model('LoginSession', loginSessionSchema);
export default LoginSession;
