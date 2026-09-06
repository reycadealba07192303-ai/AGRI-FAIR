import 'package:flutter/material.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isFromUser;
  final DateTime timestamp;
  bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromUser,
    required this.timestamp,
    this.isRead = false,
  });
}

class ChatModel extends ChangeNotifier {
  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'w1',
      text:
          'Hello! 👋 Welcome to AgriFair Support. How can we assist you today?',
      isFromUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      isRead: false,
    ),
    ChatMessage(
      id: 'w2',
      text:
          'You can ask us about your orders, products, delivery schedules, or any other concerns. We\'re happy to help!',
      isFromUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
      isRead: false,
    ),
  ];

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  int get unreadCount =>
      _messages.where((m) => !m.isFromUser && !m.isRead).length;

  void sendMessage(String text) {
    _messages.add(
      ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: text.trim(),
        isFromUser: true,
        timestamp: DateTime.now(),
        isRead: true,
      ),
    );
    notifyListeners();
  }

  void markAllRead() {
    bool changed = false;
    for (final m in _messages) {
      if (!m.isRead) {
        m.isRead = true;
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  static ChatModel of(BuildContext context) => ChatNotifier.of(context);
}

class ChatNotifier extends InheritedNotifier<ChatModel> {
  const ChatNotifier({
    super.key,
    required ChatModel model,
    required super.child,
  }) : super(notifier: model);

  static ChatModel of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ChatNotifier>()!.notifier!;
}
