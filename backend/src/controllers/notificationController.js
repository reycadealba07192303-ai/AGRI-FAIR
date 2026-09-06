import * as notificationRepo from '../repositories/notificationRepository.js';

export const listNotifications = async (req, res) => {
  try {
    const { unread, type } = req.query;
    const notifications = await notificationRepo.findByUser(req.user.userId, {
      unreadOnly: unread === 'true',
      type,
    });
    const unreadCount = await notificationRepo.countUnread(req.user.userId);
    res.status(200).json({ notifications, unreadCount });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const markNotificationRead = async (req, res) => {
  try {
    const notification = await notificationRepo.markAsRead(req.params.id, req.user.userId);
    if (!notification) {
      return res.status(404).json({ message: 'Notification not found.' });
    }
    res.status(200).json(notification);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};

export const markAllNotificationsRead = async (req, res) => {
  try {
    await notificationRepo.markAllAsRead(req.user.userId);
    res.status(200).json({ message: 'All notifications marked as read.' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};
