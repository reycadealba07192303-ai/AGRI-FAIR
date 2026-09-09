import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/conversation.dart';
import '../models/user_model.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/clay.dart';
import 'conversation_screen.dart';

/// Who you have been talking to.
///
/// Every row is a seller a buyer has messaged, newest first, with the sellers
/// who are waiting on a reply marked. There is no way to start a conversation
/// from here on purpose - a message begins on a shop, where there is something
/// to ask about.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => ChatScreenState();
}

class ChatScreenState extends State<ChatScreen> {
  List<Conversation> _conversations = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Re-reads the inbox from outside - the tab bar calls this when Messages is
  /// opened. The tabs live in an IndexedStack, which builds every screen once
  /// at launch and never again, so without this the list a buyer sees is the
  /// one that existed before they had messaged anybody.
  void reload() => _load();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final conversations = await ChatService.instance.conversations();
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(Conversation conversation, ChatParticipant other) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          conversationId: conversation.id,
          otherUserId: other.userId,
          otherName: other.name,
          otherAvatarUrl: other.avatarUrl,
        ),
      ),
    );

    // Reading a conversation clears its unread count on the server, and may
    // have added a reply, so the list is stale on the way back.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final unread = _conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Row(
        children: [
          const Text(
            'Messages',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(width: 10),
          if (!_loading && unread > 0)
            ClayBadge(label: '$unread new', color: AppColors.error, compact: true),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        children: const [
          ClaySkeleton(height: 78, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 78, radius: AppRadius.lg),
          SizedBox(height: 12),
          ClaySkeleton(height: 78, radius: AppRadius.lg),
        ],
      );
    }

    if (_error != null) {
      return ClayEmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'Cannot load your messages',
        message: _error!,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    if (_conversations.isEmpty) {
      return const ClayEmptyState(
        icon: Icons.forum_outlined,
        title: 'No messages yet',
        message:
            'Open a shop and tap Chat to ask a seller about their rice — '
            'how it was milled, when it was harvested, anything.',
      );
    }

    final myUserId = int.tryParse(UserModel.of(context).account?.id ?? '') ?? 0;

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primaryMedium,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
        itemCount: _conversations.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final conversation = _conversations[i];
          final other = conversation.otherThan(myUserId);

          if (other == null) return const SizedBox.shrink();

          return _ConversationRow(
            conversation: conversation,
            other: other,
            myUserId: myUserId,
            onTap: () => _open(conversation, other),
          );
        },
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({
    required this.conversation,
    required this.other,
    required this.myUserId,
    required this.onTap,
  });

  final Conversation conversation;
  final ChatParticipant other;
  final int myUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = conversation.hasUnread;

    return ClayCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          ChatAvatar(
            url: other.avatarImageUrl,
            initial: other.initial,
            size: 48,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        other.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: unread ? FontWeight.w800 : FontWeight.w700,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    if (conversation.updatedAt != null)
                      Text(
                        relativeTime(conversation.updatedAt!),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: unread
                              ? AppColors.primaryMedium
                              : AppColors.textMuted,
                          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        conversation.preview(myUserId),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          // Unread is carried by weight and colour, not by a
                          // dot alone - it has to read at a glance down a list.
                          color: unread ? AppColors.textDark : AppColors.textMuted,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        constraints: const BoxConstraints(minWidth: 20),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          conversation.unreadCount > 99
                              ? '99+'
                              : '${conversation.unreadCount}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round avatar with the person's initial behind it.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.url,
    required this.initial,
    this.size = 44,
  });

  final String url;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceSunken,
        shape: BoxShape.circle,
        boxShadow: AppShadows.subtle,
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? _initial()
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => _initial(),
              placeholder: (_, _) => _initial(),
            ),
    );
  }

  Widget _initial() {
    return Center(
      child: Text(
        initial,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryMedium,
        ),
      ),
    );
  }
}

/// Short and relative: an inbox is scanned, and "2h" carries more at a glance
/// than a timestamp.
String relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
  return '${(diff.inDays / 365).floor()}y';
}
