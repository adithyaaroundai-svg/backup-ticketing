import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/chat_message.dart';
import 'chat_cache_constants.dart';
import 'hive_chat_message.dart';

final chatCacheServiceProvider = Provider<ChatCacheService>((ref) {
  return ChatCacheService();
});

class ChatCacheService {
  Box<HiveChatMessage> get _messagesBox => Hive.box<HiveChatMessage>('chat_messages_cache');
  Box<String> get _metaBox => Hive.box<String>('chat_cache_meta');

  Future<List<ChatMessage>> readMessages(String key) async {
    final prefix = '$key|';
    final List<HiveChatMessage> matches = [];
    
    for (final dynamic k in _messagesBox.keys) {
      if (k is String && k.startsWith(prefix)) {
        final msg = _messagesBox.get(k);
        if (msg != null) matches.add(msg);
      }
    }

    matches.sort((a, b) {
      final t = a.createdAt.compareTo(b.createdAt);
      return t != 0 ? t : a.id.compareTo(b.id);
    });

    return matches.map((m) => m.toMessage()).toList();
  }

  Future<DateTime?> readLastSyncedAt(String key) async {
    final val = _metaBox.get('$key|lastSyncedAt');
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  Future<void> mergeMessages(String key, List<ChatMessage> incoming) async {
    if (incoming.isEmpty) return;

    // 1. Upsert all messages
    final Map<String, HiveChatMessage> putData = {};
    for (final m in incoming) {
      putData['$key|${m.id}'] = HiveChatMessage.fromMessage(m);
    }
    await _messagesBox.putAll(putData);

    // 2. Update lastSyncedAt if needed
    final newestIncoming = incoming.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
    final stored = await readLastSyncedAt(key);
    
    if (stored == null || newestIncoming.createdAt.isAfter(stored)) {
      await _metaBox.put('$key|lastSyncedAt', newestIncoming.createdAt.toUtc().toIso8601String());
    }

    // 3. Trim
    await _trim(key);
  }

  Future<void> upsertMessage(String key, ChatMessage msg) async {
    await _messagesBox.put('$key|${msg.id}', HiveChatMessage.fromMessage(msg));
  }

  Future<void> removeMessage(String key, String messageId) async {
    await _messagesBox.delete('$key|$messageId');
  }

  Future<void> _trim(String key) async {
    final prefix = '$key|';
    final List<MapEntry<String, HiveChatMessage>> entries = [];
    
    for (final dynamic k in _messagesBox.keys) {
      if (k is String && k.startsWith(prefix)) {
        final msg = _messagesBox.get(k);
        if (msg != null) {
          entries.add(MapEntry(k, msg));
        }
      }
    }

    if (entries.length <= kMaxCachedMessagesPerConversation) return;

    entries.sort((a, b) {
      final t = a.value.createdAt.compareTo(b.value.createdAt);
      return t != 0 ? t : a.value.id.compareTo(b.value.id);
    });

    final int toDelete = entries.length - kMaxCachedMessagesPerConversation;
    final keysToDelete = entries.take(toDelete).map((e) => e.key).toList();
    
    await _messagesBox.deleteAll(keysToDelete);
  }
}
