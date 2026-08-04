import sys
import re

def main():
    file_path = 'lib/features/chat/data/repositories/chat_repository.dart'
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    new_getDmConversationsOnce = """  Future<Map<String, Map<String, dynamic>>> getDmConversationsOnce(String currentUserId) async {
    final data = await _client
        .from('chat_messages')
        .select('id, sender_id, receiver_id, sender_name, sender_avatar_url, content, created_at')
        .not('receiver_id', 'is', null)
        .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .order('created_at', ascending: true);

    final conversations = <String, Map<String, dynamic>>{};

    for (final msg in data) {
      final msgId = msg['id']?.toString();
      final senderId = msg['sender_id']?.toString();
      final receiverId = msg['receiver_id']?.toString();
      final createdAt = DateTime.tryParse(msg['created_at']?.toString() ?? '');
      if (msgId == null || receiverId == null || createdAt == null) continue;

      final partnerId = senderId == currentUserId ? receiverId : senderId;
      if (partnerId == null || partnerId == currentUserId) continue;

      conversations.putIfAbsent(partnerId, () => {
        'last_message_at': createdAt,
        'last_message_id': msgId,
        'last_message': msg['content'],
        'last_sender_id': senderId,
        'sender_name': msg['sender_name'],
        'sender_avatar_url': msg['sender_avatar_url'],
        'messages_from_partner': <String>[],
        'total_message_count': 0,
      });

      conversations[partnerId]!['total_message_count'] = (conversations[partnerId]!['total_message_count'] as int) + 1;

      final currentLast = conversations[partnerId]!['last_message_at'] as DateTime;
      if (createdAt.isAfter(currentLast) || createdAt.isAtSameMomentAs(currentLast)) {
        conversations[partnerId]!['last_message_at'] = createdAt;
        conversations[partnerId]!['last_message_id'] = msgId;
        conversations[partnerId]!['last_message'] = msg['content'];
        conversations[partnerId]!['last_sender_id'] = senderId;
        
        // If the partner sent this message, use their name and avatar
        // Otherwise keep whatever we had, or fetch from agents later
        if (senderId != currentUserId) {
          conversations[partnerId]!['sender_name'] = msg['sender_name'];
          conversations[partnerId]!['sender_avatar_url'] = msg['sender_avatar_url'];
        }
      }

      if (senderId != currentUserId) {
        (conversations[partnerId]!['messages_from_partner'] as List<String>).add(msgId);
      }
    }

    final receiptsData = await _client
        .from('chat_read_receipts')
        .select('message_id')
        .eq('user_id', currentUserId);
    final readMessageIds = receiptsData.map((row) => row['message_id'].toString()).toSet();

    for (final partnerId in conversations.keys) {
      final messagesFromPartner = conversations[partnerId]!['messages_from_partner'] as List<String>;
      
      int unread = 0;
      for (final msgId in messagesFromPartner) {
        if (!readMessageIds.contains(msgId)) unread++;
      }

      conversations[partnerId]!['unread_count'] = unread;
      conversations[partnerId]!.remove('messages_from_partner');
      conversations[partnerId]!.remove('total_message_count');
    }

    return conversations;
  }"""

    # Replace the old getDmConversationsOnce
    pattern1 = re.compile(r'  Future<Map<String, Map<String, dynamic>>> getDmConversationsOnce.*?return conversations;\n  }', re.DOTALL)
    content = pattern1.sub(new_getDmConversationsOnce, content)

    # Now replace getDmConversations fetch() method
    new_fetch = """    Future<void> fetch() async {
      try {
        final conversations = await getDmConversationsOnce(currentUserId);
        if (!controller.isClosed) {
          controller.add(conversations);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }"""
    
    pattern2 = re.compile(r'    Future<void> fetch\(\) async \{.*?    \}', re.DOTALL)
    content = pattern2.sub(new_fetch, content, count=1)

    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    main()
