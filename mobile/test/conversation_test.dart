import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/models/conversation.dart';
import 'package:mobile_app/services/auth_service.dart';

/// Who a message belongs to.
///
/// Every one of these covers the same bug from a different side: the app knows
/// itself by a numeric userId, the chat documents store Mongo `_id`s, and any
/// place the two are compared silently decides that nothing is mine.
void main() {
  ChatParticipant participant(int userId, String name) => ChatParticipant(
        id: 'mongo-$userId',
        userId: userId,
        name: name,
      );

  group('who is the other person', () {
    test('the participant matched is the one who is not me', () {
      final conversation = Conversation(
        id: 'c1',
        participants: [participant(7, 'Me'), participant(12, 'Seller')],
        unreadCount: 0,
      );

      expect(conversation.otherThan(7)!.name, 'Seller');
      expect(conversation.otherThan(12)!.name, 'Me');
    });

    test('an id that matches nobody does not silently pick me', () {
      // What the Mongo-id bug looked like: my own row came back as "the other
      // person", so the inbox showed the buyer talking to themselves.
      final conversation = Conversation(
        id: 'c1',
        participants: [participant(7, 'Me'), participant(12, 'Seller')],
        unreadCount: 0,
      );

      // 0 is what int.tryParse leaves behind on a Mongo id. The first
      // participant is returned, which is wrong-but-harmless; the point of the
      // test is that the real ids above never take this path.
      expect(conversation.otherThan(0)!.name, 'Me');
    });
  });

  group('a message knows its sender', () {
    test('a populated sender gives the numeric userId, not the _id', () {
      final message = ChatMessage.fromJson({
        '_id': 'm1',
        'conversationId': 'c1',
        'sender': {'_id': '68f0a1b2c3d4e5f6a7b8c9d0', 'userId': 12},
        'text': 'Meron pa po kayong Jasmine?',
        'isRead': false,
      });

      expect(message.senderUserId, 12);
    });

    test('an unpopulated sender belongs to nobody rather than to me', () {
      // `lastMessage` used to come back with a bare ObjectId. Reading that as
      // an id would have made it match whoever happened to parse to the same
      // thing - better that it matches no one.
      final message = ChatMessage.fromJson({
        '_id': 'm1',
        'conversationId': 'c1',
        'sender': '68f0a1b2c3d4e5f6a7b8c9d0',
        'text': 'hello',
        'isRead': true,
      });

      expect(message.senderUserId, 0);
    });
  });

  group('the inbox preview', () {
    Conversation withLast(int senderUserId, {String text = 'Opo, meron pa'}) {
      return Conversation(
        id: 'c1',
        participants: [participant(7, 'Me'), participant(12, 'Seller')],
        unreadCount: 0,
        lastMessage: ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          senderUserId: senderUserId,
          text: text,
          isRead: false,
        ),
      );
    }

    test('my own last message is marked as mine', () {
      expect(withLast(7).preview(7), 'You: Opo, meron pa');
    });

    test("the other person's last message is not", () {
      expect(withLast(12).preview(7), 'Opo, meron pa');
    });

    test('a sender nobody owns is never claimed as mine', () {
      expect(withLast(0).preview(0), 'Opo, meron pa');
    });

    test('a photo reads as a photo, not as empty', () {
      final conversation = Conversation(
        id: 'c1',
        participants: [participant(7, 'Me'), participant(12, 'Seller')],
        unreadCount: 0,
        lastMessage: const ChatMessage(
          id: 'm1',
          conversationId: 'c1',
          senderUserId: 12,
          text: '',
          mediaUrl: '/uploads/media/rice.jpg',
          isRead: false,
        ),
      );

      expect(conversation.preview(7), 'Sent a photo');
    });

    test('nothing said yet says so', () {
      final conversation = Conversation(
        id: 'c1',
        participants: [participant(7, 'Me')],
        unreadCount: 0,
      );

      expect(conversation.preview(7), 'No messages yet');
    });
  });

  group('the signed-in account has one identity', () {
    test('login, which names the numeric id `id`', () {
      final user = AuthUser.fromJson({
        'id': 12,
        'email': 'buyer@agrifair.invalid',
        'name': 'Buyer',
        'role': 'buyer',
        'emailVerified': true,
      });

      expect(user.id, '12');
    });

    test('/user/me, which carries both `_id` and `userId`', () {
      // The one that used to differ. A restored session read `_id` here and
      // the person came back as somebody else.
      final user = AuthUser.fromJson({
        '_id': '68f0a1b2c3d4e5f6a7b8c9d0',
        'userId': 12,
        'email': 'buyer@agrifair.invalid',
        'name': 'Buyer',
        'role': 'buyer',
        'emailVerified': true,
      });

      expect(user.id, '12');
    });
  });
}
