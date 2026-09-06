import 'package:flutter/material.dart';

enum NotificationType {
  orderConfirmed,
  orderPacked,
  outForDelivery,
  delivered,
  orderCancelled,
  paymentConfirmed,
  newMessage,
  reviewSubmitted,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String? referenceId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.referenceId,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
        referenceId: referenceId,
      );
}

class NotificationModel extends ChangeNotifier {
  final List<AppNotification> _notifications;

  NotificationModel() : _notifications = _seed();

  static List<AppNotification> _seed() => [
        AppNotification(
          id: 'n1',
          title: 'New Message from Admin',
          body: 'Your recent inquiry has been resolved. Let us know if you need anything else!',
          type: NotificationType.newMessage,
          timestamp: DateTime.now().subtract(const Duration(hours: 1, minutes: 20)),
          isRead: false,
        ),
        AppNotification(
          id: 'n2',
          title: 'New Message from Admin',
          body: 'Hi there! We have received your message. Our team will get back to you shortly.',
          type: NotificationType.newMessage,
          timestamp: DateTime.now().subtract(const Duration(hours: 5, minutes: 10)),
          isRead: false,
        ),
        AppNotification(
          id: 'n3',
          title: 'Order Delivered Successfully',
          body: 'Your order AGF-001234 has arrived. We hope you enjoy your premium rice!',
          type: NotificationType.delivered,
          timestamp: DateTime.now().subtract(const Duration(days: 2)),
          isRead: true,
          referenceId: 'AGF-001234',
        ),
        AppNotification(
          id: 'n4',
          title: 'Out for Delivery',
          body:
              'Your order AGF-001234 is on its way! The courier is heading to your location.',
          type: NotificationType.outForDelivery,
          timestamp: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
          isRead: true,
          referenceId: 'AGF-001234',
        ),
        AppNotification(
          id: 'n5',
          title: 'Order Packed',
          body:
              'Your order AGF-001234 has been carefully packed and is ready for pickup by the courier.',
          type: NotificationType.orderPacked,
          timestamp: DateTime.now().subtract(const Duration(days: 3)),
          isRead: true,
          referenceId: 'AGF-001234',
        ),
        AppNotification(
          id: 'n6',
          title: 'Payment Confirmed',
          body:
              'Your GCash payment for order AGF-001234 (₱480) has been confirmed. Thank you!',
          type: NotificationType.paymentConfirmed,
          timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 1)),
          isRead: true,
          referenceId: 'AGF-001234',
        ),
        AppNotification(
          id: 'n7',
          title: 'Order Confirmed!',
          body:
              'Your order AGF-001234 has been placed successfully. We are now preparing your items.',
          type: NotificationType.orderConfirmed,
          timestamp: DateTime.now().subtract(const Duration(days: 3, hours: 2)),
          isRead: true,
          referenceId: 'AGF-001234',
        ),
      ];

  List<AppNotification> get notifications =>
      [..._notifications]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void add(AppNotification notification) {
    _notifications.add(notification);
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1 && !_notifications[idx].isRead) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    bool changed = false;
    for (int i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  static NotificationModel of(BuildContext context) =>
      NotificationNotifier.of(context);
}

class NotificationNotifier extends InheritedNotifier<NotificationModel> {
  const NotificationNotifier({
    super.key,
    required NotificationModel model,
    required super.child,
  }) : super(notifier: model);

  static NotificationModel of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<NotificationNotifier>()!
          .notifier!;
}
