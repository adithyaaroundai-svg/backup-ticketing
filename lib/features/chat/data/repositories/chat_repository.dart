import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../local/chat_cache_constants.dart';

class ChatRepository {
  final SupabaseClient _client;

  ChatRepository(this._client);

  // ── Paginated fetch for chat messages ────────────────────────────────────────
  Future<List<ChatMessage>> getPaginatedMessages({
    String? currentUserId,
    String? chatPartnerId,
    String channelName = 'support-chat',
    DateTime? before,
    int limit = 50,
  }) async {
    var query = _client.from('chat_messages').select('id, sender_id, receiver_id, sender_name, sender_role, sender_avatar_url, content, created_at, is_deleted, reactions, reply_to_message_id, reply_to_sender_name, reply_to_content, file_url, file_name, file_type, channel');
    
    if (chatPartnerId == null) {
      // Global/Custom channel
      query = query.eq('channel', channelName).isFilter('receiver_id', null);
    } else {
      // DM
      query = query.or('and(sender_id.eq.$currentUserId,receiver_id.eq.$chatPartnerId),and(sender_id.eq.$chatPartnerId,receiver_id.eq.$currentUserId)');
    }

    if (before != null) {
      query = query.lt('created_at', before.toIso8601String());
    }

    // Fetch newest first
    final data = await query.order('created_at', ascending: false).limit(limit);

    final messages = data.map((json) => ChatMessage.fromJson(json)).toList();
    
    // Sort ascending for UI (oldest to newest)
    messages.sort((a, b) {
      final t = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
      return t != 0 ? t : a.id.compareTo(b.id);
    });

    return messages;
  }

  /// Delta-sync fetch.
  /// [inclusive]: true uses >=, false uses > on created_at.
  /// First batch: inclusive=true (overlap window).
  /// Subsequent batches: inclusive=false (strict forward cursor).
  Future<List<ChatMessage>> getMessagesSince({
    required DateTime after,
    bool inclusive = false,
    String? currentUserId,
    String? chatPartnerId,
    String channelName = 'support-chat',
    int batchSize = kDeltaSyncBatchSize,
  }) async {
    var query = _client.from('chat_messages').select('id, sender_id, receiver_id, sender_name, sender_role, sender_avatar_url, content, created_at, is_deleted, reactions, reply_to_message_id, reply_to_sender_name, reply_to_content, file_url, file_name, file_type, channel');

    if (chatPartnerId == null) {
      query = query.eq('channel', channelName).isFilter('receiver_id', null);
    } else {
      query = query.or('and(sender_id.eq.$currentUserId,receiver_id.eq.$chatPartnerId),and(sender_id.eq.$chatPartnerId,receiver_id.eq.$currentUserId)');
    }

    // First batch uses >= (overlap); subsequent use >
    query = inclusive
        ? query.gte('created_at', after.toIso8601String())
        : query.gt('created_at', after.toIso8601String());

    final data = await query
        .order('created_at', ascending: true)   // ASC — simple forward append
        .limit(batchSize);

    return data.map((json) => ChatMessage.fromJson(json)).toList();
  }

  Future<Map<String, Set<String>>> fetchReceiptsForMessages(List<String> messageIds) async {
    if (messageIds.isEmpty) return {};
    final data = await _client
        .from('chat_read_receipts')
        .select('message_id, user_id')
        .inFilter('message_id', messageIds);

    final receipts = <String, Set<String>>{};
    for (final row in data) {
      final msgId = row['message_id']?.toString();
      final userId = row['user_id']?.toString();
      if (msgId != null && userId != null) {
        receipts.putIfAbsent(msgId, () => <String>{}).add(userId.trim().toLowerCase());
      }
    }
    return receipts;
  }

  // ── Realtime subscription for chat messages ──────────────────────────────────
  RealtimeChannel subscribeToMessages({
    required String channelName,
    String? currentUserId,
    String? chatPartnerId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final realtimeChannelName = chatPartnerId != null
        ? 'chat_dm_${currentUserId}_${chatPartnerId}_$uniqueId'
        : 'chat_${channelName}_$uniqueId';

    return _client
        .channel(realtimeChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: onEvent,
        )
        .subscribe();
  }

  RealtimeChannel subscribeToReadReceipts({
    required String channelName,
    String? currentUserId,
    String? chatPartnerId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    final realtimeChannelName = chatPartnerId != null
        ? 'chat_dm_receipts_${currentUserId}_${chatPartnerId}_$uniqueId'
        : 'chat_receipts_${channelName}_$uniqueId';

    return _client
        .channel(realtimeChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_read_receipts',
          callback: onEvent,
        )
        .subscribe();
  }

  // Send a message
  Future<String> sendMessage({
    String? id,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String content,
    String? receiverId,
    String? senderAvatarUrl,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String channel = 'support-chat',
    List<dynamic>? richTextDelta,
  }) async {
    final payload = <String, dynamic>{
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'channel': channel,
    };
    if (id != null) {
      payload['id'] = id;
    }
    if (receiverId != null) {
      payload['receiver_id'] = receiverId;
    }
    if (senderAvatarUrl != null) {
      payload['sender_avatar_url'] = senderAvatarUrl;
    }
    if (replyToMessageId != null) {
      payload['reply_to_message_id'] = replyToMessageId;
    }
    if (replyToSenderName != null) {
      payload['reply_to_sender_name'] = replyToSenderName;
    }
    if (replyToContent != null) {
      payload['reply_to_content'] = replyToContent;
    }
    if (richTextDelta != null) {
      // payload['rich_text_delta'] = jsonEncode(richTextDelta);
    }
    if (fileUrl != null) {
      payload['file_url'] = fileUrl;
    }
    if (fileName != null) {
      payload['file_name'] = fileName;
    }
    if (fileType != null) {
      payload['file_type'] = fileType;
    }
    
    final response = await _client.from('chat_messages').insert(payload).select('id').single();
    return response['id'] as String;
  }

  // Insert a call-event system message.
  // [callType] is 'audio' or 'video'.
  // [event] is 'started' | 'ended' | 'missed' | 'ongoing'.
  // [duration] is optional (e.g., '5m 32s'), used for 'ended' event.
  Future<void> sendCallMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    String callType = 'audio', // 'audio' | 'video'
    String event = 'started',  // 'started' | 'ended' | 'missed' | 'ongoing'
    String? duration,
    String? receiverId,
    String channel = 'support-chat',
  }) async {
    // Format: __CALL_AUDIO_STARTED__ or __CALL_VIDEO_ENDED__:5m 32s
    final suffix = duration != null ? ':$duration' : '';
    final content = '__CALL_${callType.toUpperCase()}_${event.toUpperCase()}__$suffix';
    final payload = <String, dynamic>{
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'content': content,
      'channel': channel,
    };
    if (receiverId != null) payload['receiver_id'] = receiverId;
    await _client.from('chat_messages').insert(payload);
  }


  Future<void> deleteMessage(String messageId) async {
    await _client
        .from('chat_messages')
        .update({'is_deleted': true})
        .eq('id', messageId);
  }

  Future<void> markAsRead(String messageId, String userId) async {
    await _client.from('chat_read_receipts').upsert({
      'message_id': messageId,
      'user_id': userId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'message_id,user_id');
  }

  // Mark multiple messages as read efficiently
  Future<void> markMessagesAsRead(List<String> messageIds, String userId) async {
    if (messageIds.isEmpty) return;
    
    final payload = messageIds.map((id) => {
      'message_id': id,
      'user_id': userId,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).toList();

    await _client.from('chat_read_receipts').upsert(payload, onConflict: 'message_id,user_id');
  }

  // Add or remove a reaction from a message
  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    // Get current message
    final response = await _client
        .from('chat_messages')
        .select('reactions')
        .eq('id', messageId)
        .single();

    final currentReactions = response['reactions'] as List<dynamic>? ?? [];

    // Check if user already reacted with any emoji
    final existingIndex = currentReactions.indexWhere(
      (r) => r['user_id'] == userId,
    );

    List<dynamic> updatedReactions;

    if (existingIndex != -1) {
      if (currentReactions[existingIndex]['emoji'] == emoji) {
        // Same emoji -> remove the reaction (toggle off)
        updatedReactions = List.from(currentReactions)..removeAt(existingIndex);
      } else {
        // Different emoji -> replace the reaction
        updatedReactions = List.from(currentReactions);
        updatedReactions[existingIndex] = {
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        };
      }
    } else {
      // No existing reaction -> add the reaction
      updatedReactions = [
        ...currentReactions,
        {
          'user_id': userId,
          'emoji': emoji,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        },
      ];
    }

    // Update the message
    await _client
        .from('chat_messages')
        .update({'reactions': updatedReactions})
        .eq('id', messageId);
  }

  // Toggle starred status of a message
  Future<void> toggleStarred(String messageId, String userId) async {
    // Check if already starred
    final existing = await _client
        .from('starred_messages')
        .select()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      // Remove star
      await _client
          .from('starred_messages')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', userId);
    } else {
      // Add star
      await _client.from('starred_messages').insert({
        'message_id': messageId,
        'user_id': userId,
      });
    }
  }

  // Get starred messages for a user
  Stream<List<ChatMessage>> getStarredMessages(String userId) {
    return _client
        .from('starred_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .asyncMap((starredData) async {
      final messageIds = starredData
          .map((s) => s['message_id']?.toString())
          .whereType<String>()
          .toList();

      if (messageIds.isEmpty) return <ChatMessage>[];

      final messagesData = await _client
          .from('chat_messages')
          .select('id, sender_id, receiver_id, sender_name, sender_role, sender_avatar_url, content, created_at, is_deleted, reactions, reply_to_message_id, reply_to_sender_name, reply_to_content, file_url, file_name, file_type, channel')
          .inFilter('id', messageIds)
          .order('created_at', ascending: false);

      return messagesData
          .map((json) => ChatMessage.fromJson(json))
          .toList();
    });
  }

  Future<Map<String, Map<String, dynamic>>> fetchDmConversationsBootstrap(String currentUserId) async {
    final response = await _client
        .from('chat_messages')
        .select('id, sender_id, receiver_id, sender_name, sender_role, sender_avatar_url, content, created_at, is_deleted, reactions, reply_to_message_id, reply_to_sender_name, reply_to_content, file_url, file_name, file_type, channel')
        .not('receiver_id', 'is', null)
        .or('sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId')
        .order('created_at', ascending: false)
        .limit(1000);
        
    final data = response.reversed.toList();

    final incomingMessageIds = data
        .where((m) => m['sender_id']?.toString() != currentUserId)
        .map((m) => m['id'].toString())
        .toList();

    final readMessageIds = <String>{};
    if (incomingMessageIds.isNotEmpty) {
      const batchSize = 300;
      for (var i = 0; i < incomingMessageIds.length; i += batchSize) {
        final chunk = incomingMessageIds.sublist(
          i,
          i + batchSize > incomingMessageIds.length ? incomingMessageIds.length : i + batchSize,
        );
        final receiptsData = await _client
            .from('chat_read_receipts')
            .select('message_id')
            .eq('user_id', currentUserId)
            .inFilter('message_id', chunk);
        for (final row in receiptsData) {
          readMessageIds.add(row['message_id'].toString());
        }
      }
    }

    final conversations = <String, Map<String, dynamic>>{};

    for (final json in data) {
      final msg = ChatMessage.fromJson(json);
      final partnerId = msg.senderId == currentUserId ? msg.receiverId : msg.senderId;
      if (partnerId == null || partnerId == currentUserId) continue;

      if (!conversations.containsKey(partnerId)) {
        conversations[partnerId] = {
          'last_message': msg,
          'unread_message_ids': <String>{},
          'total_message_count': 0,
        };
      }

      final conv = conversations[partnerId]!;
      conv['total_message_count'] = (conv['total_message_count'] as int) + 1;

      final lastMsg = conv['last_message'] as ChatMessage;
      if (msg.createdAt.isAfter(lastMsg.createdAt) || msg.createdAt.isAtSameMomentAs(lastMsg.createdAt)) {
        conv['last_message'] = msg;
      }

      if (msg.senderId != currentUserId) {
        if (!readMessageIds.contains(msg.id)) {
          (conv['unread_message_ids'] as Set<String>).add(msg.id);
        }
      }
    }

    return conversations;
  }

  RealtimeChannel subscribeToDmEngineMessages({
    required String currentUserId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    return _client
        .channel('dm_engine_msg_${currentUserId}_$uniqueId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: onEvent,
        )
        .subscribe();
  }

  RealtimeChannel subscribeToDmEngineReadReceipts({
    required String currentUserId,
    required void Function(PostgresChangePayload payload) onEvent,
  }) {
    final uniqueId = DateTime.now().millisecondsSinceEpoch;
    return _client
        .channel('dm_engine_rcpt_${currentUserId}_$uniqueId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_read_receipts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: currentUserId,
          ),
          callback: onEvent,
        )
        .subscribe();
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(Supabase.instance.client);
});
