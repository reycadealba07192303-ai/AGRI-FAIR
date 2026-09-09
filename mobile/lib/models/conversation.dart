import '../services/api_config.dart';

/// The other person in a conversation.
class ChatParticipant {
  const ChatParticipant({
    required this.id,
    required this.userId,
    required this.name,
    this.role = '',
    this.avatarUrl = '',
  });

  /// Mongo `_id` - what the conversation stores.
  final String id;

  /// The numeric userId - what sending a message is addressed to.
  final int userId;
  final String name;
  final String role;
  final String avatarUrl;

  String get avatarImageUrl => ApiConfig.mediaUrl(avatarUrl);
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  factory ChatParticipant.fromJson(Map<String, dynamic> json) {
    return ChatParticipant(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
    );
  }
}

/// A listing as it appears inside a thread - a card, not the whole product.
class ChatProduct {
  const ChatProduct({
    required this.id,
    required this.name,
    required this.pricePerKg,
    required this.variety,
    required this.stock,
    this.imageUrl = '',
  });

  final String id;
  final String name;
  final double pricePerKg;
  final String variety;
  final int stock;
  final String imageUrl;

  bool get inStock => stock > 0;
  String get imageFullUrl => ApiConfig.mediaUrl(imageUrl);

  factory ChatProduct.fromJson(Map<String, dynamic> json) {
    final images = (json['images'] as List?) ?? const [];

    return ChatProduct(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      pricePerKg: (json['price'] as num?)?.toDouble() ?? 0,
      variety: (json['variety'] ?? '').toString(),
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      imageUrl: images.isEmpty ? '' : images.first.toString(),
    );
  }
}

/// What a message is.
///
/// [system] is the order speaking - placed, confirmed, shipped - written into
/// the thread so the buyer does not have to hold the order screen and the
/// conversation in their head at once. [product] is a listing passed across.
enum MessageKind { text, system, product }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.text,
    required this.isRead,
    this.kind = MessageKind.text,
    this.product,
    this.mediaUrl = '',
    this.sentAt,
  });

  final String id;
  final String conversationId;

  /// The sender's numeric userId.
  ///
  /// Not the Mongo `_id`: that is what the document stores, but the signed-in
  /// account is known by its userId, and comparing the two never matches -
  /// which made every message render as the other person's.
  final int senderUserId;
  final String text;
  final String mediaUrl;
  final bool isRead;
  final MessageKind kind;

  /// Set only on a [MessageKind.product] message.
  final ChatProduct? product;
  final DateTime? sentAt;

  bool get hasMedia => mediaUrl.isNotEmpty;
  bool get isSystem => kind == MessageKind.system;
  String get mediaImageUrl => ApiConfig.mediaUrl(mediaUrl);

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // `sender` is populated with its userId; an unpopulated one leaves 0,
    // which belongs to nobody and so reads as the other person's.
    final sender = json['sender'];
    final senderUserId =
        sender is Map ? (sender['userId'] as num?)?.toInt() ?? 0 : 0;

    final rawProduct = json['product'];

    return ChatMessage(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '').toString(),
      senderUserId: senderUserId,
      text: (json['text'] ?? '').toString(),
      mediaUrl: (json['mediaUrl'] ?? '').toString(),
      isRead: json['isRead'] == true,
      // Messages saved before kinds existed carry none, and every one of them
      // was somebody typing.
      kind: switch ((json['kind'] ?? 'text').toString()) {
        'system' => MessageKind.system,
        'product' => MessageKind.product,
        _ => MessageKind.text,
      },
      product: rawProduct is Map<String, dynamic>
          ? ChatProduct.fromJson(rawProduct)
          : null,
      sentAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.participants,
    required this.unreadCount,
    this.lastMessage,
    this.updatedAt,
  });

  final String id;
  final List<ChatParticipant> participants;
  final int unreadCount;
  final ChatMessage? lastMessage;
  final DateTime? updatedAt;

  bool get hasUnread => unreadCount > 0;

  /// The participant who is not me.
  ///
  /// Matched on userId, which is what the signed-in account is known by. The
  /// Mongo `_id` is also on the participant, but the app never learns its own.
  ChatParticipant? otherThan(int myUserId) {
    for (final p in participants) {
      if (p.userId != myUserId) return p;
    }
    return participants.isEmpty ? null : participants.first;
  }

  /// The one line under the name in the inbox.
  ///
  /// Prefixed with "You:" when the last word was mine - without it a list of
  /// replies gives no clue whose turn it is.
  String preview(int myUserId) {
    final message = lastMessage;
    if (message == null) return 'No messages yet';

    // An order update is nobody's line - it reads as itself, unprefixed.
    if (message.isSystem) {
      return message.text.isEmpty ? 'Order updated' : message.text;
    }

    final mine = message.senderUserId != 0 && message.senderUserId == myUserId;
    final prefix = mine ? 'You: ' : '';

    if (message.kind == MessageKind.product) {
      final name = message.product?.name ?? 'a product';
      return mine ? 'You shared $name' : 'Shared $name';
    }

    if (message.text.isNotEmpty) return '$prefix${message.text}';
    if (message.hasMedia) return mine ? 'You sent a photo' : 'Sent a photo';
    return 'No messages yet';
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'];

    return Conversation(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      participants: (json['participants'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ChatParticipant.fromJson)
              .toList() ??
          const [],
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      lastMessage:
          last is Map<String, dynamic> ? ChatMessage.fromJson(last) : null,
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }
}
