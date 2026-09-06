import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'order_detail_screen.dart';
import 'order_history_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nm = NotificationModel.of(context);
    final all = nm.notifications;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    bool isToday(DateTime dt) =>
        DateTime(dt.year, dt.month, dt.day) == todayDate;
    bool isYesterday(DateTime dt) =>
        DateTime(dt.year, dt.month, dt.day) == yesterdayDate;

    final today = all.where((n) => isToday(n.timestamp)).toList();
    final yesterday = all.where((n) => isYesterday(n.timestamp)).toList();
    final earlier = all
        .where((n) => !isToday(n.timestamp) && !isYesterday(n.timestamp))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.primaryDark,
            size: 18,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            if (nm.unreadCount > 0)
              Text(
                '${nm.unreadCount} unread',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.primaryMedium,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          if (nm.unreadCount > 0)
            GestureDetector(
              onTap: nm.markAllRead,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: all.isEmpty
          ? const _EmptyNotifications()
          : ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 24),
              children: [
                if (today.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Today',
                    count: today.where((n) => !n.isRead).length,
                  ),
                  ...today.map((n) => _NotificationCard(notification: n)),
                ],
                if (yesterday.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Yesterday',
                    count: yesterday.where((n) => !n.isRead).length,
                  ),
                  ...yesterday.map((n) => _NotificationCard(notification: n)),
                ],
                if (earlier.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Earlier',
                    count: earlier.where((n) => !n.isRead).length,
                  ),
                  ...earlier.map((n) => _NotificationCard(notification: n)),
                ],
              ],
            ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
              letterSpacing: 1.0,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  const _NotificationCard({required this.notification});

  void _handleTap(BuildContext context) {
    NotificationModel.of(context).markRead(notification.id);

    switch (notification.type) {
      case NotificationType.orderConfirmed:
      case NotificationType.orderPacked:
      case NotificationType.outForDelivery:
      case NotificationType.delivered:
      case NotificationType.orderCancelled:
      case NotificationType.paymentConfirmed:
        if (notification.referenceId != null) {
          final user = UserModel.of(context);
          final matches = user.orders.where(
            (o) => o.orderNumber == notification.referenceId,
          );
          if (matches.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OrderDetailScreen(order: matches.first),
              ),
            );
            return;
          }
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
        );
        break;
      case NotificationType.newMessage:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
        break;
      case NotificationType.reviewSubmitted:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final color = _typeColor(notification.type);

    return GestureDetector(
      onTap: () => _handleTap(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isUnread
              ? AppColors.primaryDark.withValues(alpha: 0.035)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUnread
                ? AppColors.primaryDark.withValues(alpha: 0.14)
                : AppColors.border,
            width: isUnread ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Type icon
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _typeIcon(notification.type),
                  size: 21,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isUnread
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: AppColors.textDark,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _relativeTime(notification.timestamp),
                              style: TextStyle(
                                fontSize: 10,
                                color: isUnread
                                    ? AppColors.primaryMedium
                                    : AppColors.textMuted,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(height: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.55,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Navigation hint
                    if (_hasNavigation(notification.type)) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _navHintIcon(notification.type),
                            size: 11,
                            color: color.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _navHintLabel(notification.type),
                            style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon(NotificationType type) => switch (type) {
    NotificationType.orderConfirmed => Icons.receipt_rounded,
    NotificationType.orderPacked => Icons.inventory_2_rounded,
    NotificationType.outForDelivery => Icons.local_shipping_rounded,
    NotificationType.delivered => Icons.check_circle_rounded,
    NotificationType.orderCancelled => Icons.cancel_rounded,
    NotificationType.paymentConfirmed => Icons.payments_rounded,
    NotificationType.newMessage => Icons.chat_bubble_rounded,
    NotificationType.reviewSubmitted => Icons.star_rounded,
  };

  Color _typeColor(NotificationType type) => switch (type) {
    NotificationType.orderConfirmed => const Color(0xFF2563EB),
    NotificationType.orderPacked => const Color(0xFFD97706),
    NotificationType.outForDelivery => const Color(0xFF7C3AED),
    NotificationType.delivered => const Color(0xFF16A34A),
    NotificationType.orderCancelled => const Color(0xFFDC2626),
    NotificationType.paymentConfirmed => const Color(0xFF0891B2),
    NotificationType.newMessage => AppColors.primaryDark,
    NotificationType.reviewSubmitted => const Color(0xFFF59E0B),
  };

  bool _hasNavigation(NotificationType type) =>
      type != NotificationType.reviewSubmitted;

  IconData _navHintIcon(NotificationType type) =>
      type == NotificationType.newMessage
      ? Icons.chat_bubble_outline_rounded
      : Icons.receipt_long_outlined;

  String _navHintLabel(NotificationType type) =>
      type == NotificationType.newMessage ? 'Open Chat →' : 'View Order →';

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.notifications_none_rounded,
                size: 52,
                color: AppColors.primaryLight.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You're all caught up! Order updates,\nmessages, and alerts will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
