import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/notification_service.dart';

enum NotificationType { order, payment, message, stock, system }

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.link = '',
  });

  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;
  final String link;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        timestamp: timestamp,
        isRead: isRead ?? this.isRead,
        link: link,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      type: _parseType((json['type'] ?? 'SYSTEM').toString()),
      timestamp: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      isRead: json['read'] == true,
      link: (json['link'] ?? '').toString(),
    );
  }

  static NotificationType _parseType(String raw) {
    switch (raw.toUpperCase()) {
      case 'ORDER':
        return NotificationType.order;
      case 'PAYMENT':
        return NotificationType.payment;
      case 'MESSAGE':
        return NotificationType.message;
      case 'STOCK':
        return NotificationType.stock;
      default:
        return NotificationType.system;
    }
  }
}

class NotificationModel extends ChangeNotifier {
  NotificationModel();

  final List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;
  String? _error;

  List<AppNotification> get notifications =>
      [..._notifications]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  int get unreadCount => _unreadCount;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await NotificationService.instance.list();
      _notifications
        ..clear()
        ..addAll(result.items);
      _unreadCount = result.unreadCount;
      _loading = false;
      notifyListeners();
    } on ApiException catch (err) {
      _loading = false;
      _error = err.message;
      notifyListeners();
    } catch (_) {
      _loading = false;
      _error = 'Could not load notifications.';
      notifyListeners();
    }
  }

  Future<void> markRead(String id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx < 0 || _notifications[idx].isRead) return;

    _notifications[idx] = _notifications[idx].copyWith(isRead: true);
    _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
    notifyListeners();

    try {
      await NotificationService.instance.markRead(id);
    } catch (_) {
      // Keep the local read state; the next load will reconcile.
    }
  }

  Future<void> markAllRead() async {
    if (_unreadCount == 0) return;

    for (var i = 0; i < _notifications.length; i++) {
      if (!_notifications[i].isRead) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    }
    _unreadCount = 0;
    notifyListeners();

    try {
      await NotificationService.instance.markAllRead();
    } catch (_) {
      // Same as markRead — optimistic UI, reconcile on reload.
    }
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

  static NotificationModel of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<NotificationNotifier>()!
      .notifier!;
}
