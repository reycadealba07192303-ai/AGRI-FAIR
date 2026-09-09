import '../models/notification_model.dart';
import 'api_client.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _api = ApiClient.instance;

  Future<({List<AppNotification> items, int unreadCount})> list() async {
    final body = await _api.get('/notifications');
    if (body is! Map) {
      return (items: const <AppNotification>[], unreadCount: 0);
    }

    final raw = body['notifications'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <AppNotification>[];

    final unread = (body['unreadCount'] as num?)?.toInt() ??
        items.where((n) => !n.isRead).length;

    return (items: items, unreadCount: unread);
  }

  Future<void> markRead(String id) async {
    await _api.put('/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _api.put('/notifications/read-all');
  }
}
