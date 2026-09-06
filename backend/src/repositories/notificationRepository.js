import Notification from '../models/Notification.js';
import User from '../models/User.js';

const PREF_KEY = {
  ORDER: 'order',
  PAYMENT: 'payment',
  MESSAGE: 'message',
  STOCK: 'stock',
  SYSTEM: 'system',
};

export const createNotification = async (data) => {
  const prefKey = PREF_KEY[data.type];
  if (prefKey) {
    const recipient = await User.findOne({ userId: data.userId }).select('notificationPrefs');
    if (recipient && recipient.notificationPrefs?.[prefKey] === false) {
      return null; // recipient opted out of this notification type
    }
  }
  return await Notification.create(data);
};

export const findByUser = async (userId, { unreadOnly = false, type } = {}) => {
  const filter = { userId };
  if (unreadOnly) filter.read = false;
  if (type) filter.type = type;
  return await Notification.find(filter).sort({ createdAt: -1 }).limit(100);
};

export const countUnread = async (userId) => {
  return await Notification.countDocuments({ userId, read: false });
};

export const markAsRead = async (id, userId) => {
  return await Notification.findOneAndUpdate({ _id: id, userId }, { read: true }, { new: true });
};

export const markAllAsRead = async (userId) => {
  return await Notification.updateMany({ userId, read: false }, { read: true });
};
