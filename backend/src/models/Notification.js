import mongoose from 'mongoose';

const notificationSchema = new mongoose.Schema({
  userId: {
    type: Number, // recipient's User.userId
    required: true,
    index: true,
  },
  type: {
    type: String,
    enum: ['ORDER', 'PAYMENT', 'MESSAGE', 'STOCK', 'SYSTEM'],
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  body: {
    type: String,
    default: '',
  },
  link: {
    type: String,
    default: '',
  },
  read: {
    type: Boolean,
    default: false,
  },
}, {
  timestamps: true,
});

notificationSchema.index({ userId: 1, createdAt: -1 });

const Notification = mongoose.model('Notification', notificationSchema);
export default Notification;
