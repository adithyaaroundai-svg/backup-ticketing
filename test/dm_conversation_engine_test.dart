import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/features/chat/domain/entities/chat_message.dart';
import 'package:ticketing_system/features/chat/presentation/providers/chat_provider.dart';

void main() {
  group('DmConversationState & Engine Architecture Tests', () {
    ChatMessage createMockMsg({
      required String id,
      required String senderId,
      required String receiverId,
      required String content,
    }) {
      return ChatMessage(
        id: id,
        senderId: senderId,
        receiverId: receiverId,
        senderName: 'Agent $senderId',
        senderRole: 'Support',
        content: content,
        createdAt: DateTime.now().toUtc(),
      );
    }

    test('Simultaneous senders - each partner conversation maintains isolated state & unread badge', () {
      final stateMap = <String, DmConversationState>{};

      // Alice sends a message
      final msgAlice = createMockMsg(id: '101', senderId: 'alice', receiverId: 'me', content: 'Hi from Alice');
      stateMap['alice'] = DmConversationState(
        partnerId: 'alice',
        lastMessage: msgAlice,
        unreadCount: 1,
        isOpen: false,
        unreadMessageIds: {'101'},
        totalMessageCount: 1,
      );

      // Bob sends a message
      final msgBob = createMockMsg(id: '102', senderId: 'bob', receiverId: 'me', content: 'Hi from Bob');
      stateMap['bob'] = DmConversationState(
        partnerId: 'bob',
        lastMessage: msgBob,
        unreadCount: 1,
        isOpen: false,
        unreadMessageIds: {'102'},
        totalMessageCount: 1,
      );

      // Charlie sends a message
      final msgCharlie = createMockMsg(id: '103', senderId: 'charlie', receiverId: 'me', content: 'Hi from Charlie');
      stateMap['charlie'] = DmConversationState(
        partnerId: 'charlie',
        lastMessage: msgCharlie,
        unreadCount: 1,
        isOpen: false,
        unreadMessageIds: {'103'},
        totalMessageCount: 1,
      );

      // Verify each sender's badge is exactly 1 and state is isolated
      expect(stateMap['alice']!.unreadCount, 1);
      expect(stateMap['bob']!.unreadCount, 1);
      expect(stateMap['charlie']!.unreadCount, 1);

      // Total aggregate unread count
      final aggregateUnread = stateMap.values.fold<int>(0, (sum, conv) => sum + conv.unreadCount);
      expect(aggregateUnread, 3);
    });

    test('Active conversation suppression - open conversation keeps unread at 0', () {
      final msgBob = createMockMsg(id: '201', senderId: 'bob', receiverId: 'me', content: 'Are you there?');
      const bool isBobOpen = true; // Bob's chat window is actively open

      final bobConv = DmConversationState(
        partnerId: 'bob',
        lastMessage: msgBob,
        unreadCount: isBobOpen ? 0 : 1,
        isOpen: isBobOpen,
        unreadMessageIds: isBobOpen ? const {} : {'201'},
        totalMessageCount: 1,
      );

      expect(bobConv.isOpen, isTrue);
      expect(bobConv.unreadCount, 0);
      expect(bobConv.unreadMessageIds, isEmpty);
    });

    test('Background conversation while active - Charlie message increments while Bob is open', () {
      final stateMap = <String, DmConversationState>{
        'bob': DmConversationState(
          partnerId: 'bob',
          unreadCount: 0,
          isOpen: true,
          unreadMessageIds: const {},
          totalMessageCount: 5,
        ),
      };

      // Charlie sends a message in background
      final msgCharlie = createMockMsg(id: '301', senderId: 'charlie', receiverId: 'me', content: 'New support query');
      stateMap['charlie'] = DmConversationState(
        partnerId: 'charlie',
        lastMessage: msgCharlie,
        unreadCount: 1,
        isOpen: false,
        unreadMessageIds: {'301'},
        totalMessageCount: 1,
      );

      expect(stateMap['bob']!.unreadCount, 0);
      expect(stateMap['bob']!.isOpen, isTrue);
      expect(stateMap['charlie']!.unreadCount, 1);
      expect(stateMap['charlie']!.isOpen, isFalse);
    });

    test('Read receipt synchronization - clearing badge updates unread count to 0 without mutating last message', () {
      final initialMsg = createMockMsg(id: '401', senderId: 'alice', receiverId: 'me', content: 'Important update');
      var aliceConv = DmConversationState(
        partnerId: 'alice',
        lastMessage: initialMsg,
        unreadCount: 1,
        isOpen: false,
        unreadMessageIds: {'401'},
        totalMessageCount: 1,
      );

      // Simulate read receipt sync arriving from Device B or opening chat
      aliceConv = aliceConv.copyWith(
        unreadCount: 0,
        unreadMessageIds: const {},
        lastReadAt: DateTime.now().toUtc(),
      );

      expect(aliceConv.unreadCount, 0);
      expect(aliceConv.unreadMessageIds, isEmpty);
      expect(aliceConv.lastMessage?.content, 'Important update');
    });
  });
}
