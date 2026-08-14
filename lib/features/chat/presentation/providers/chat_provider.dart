import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/chat_message.dart';
import '../../data/repositories/chat_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';
import '../../data/local/chat_cache_service.dart';
import '../../data/local/chat_cache_constants.dart';

import 'dart:io';
import 'package:http/http.dart' as http;
part 'chat_provider.g.dart';

@riverpod
Future<List<ChatMessage>> globalMessageSearch(Ref ref, String query) async {
  if (query.isEmpty) return [];

  // Debounce for 300ms
  await Future.delayed(const Duration(milliseconds: 300));

  
  // We can just rely on Riverpod's built-in FutureProvider behavior which throws on unmount, or just let it query.
  
  final currentUserId = ref.read(authProvider)?.id;
  final client = Supabase.instance.client;
  
  // Escape query for ILIKE if needed, or just use %query%
  final q = query.replaceAll('%', '\\%').replaceAll('_', '\\_');
  
  var dbQuery = client.from('chat_messages').select()
      .or('content.ilike.%$q%,sender_name.ilike.%$q%');
      
  if (currentUserId != null) {
    // Only return messages where the user is allowed
    // E.g., public channels or DMs involving the user
    // We assume any message with receiver_id == null is public, or we explicitly allow sender/receiver matches.
    dbQuery = dbQuery.or('receiver_id.is.null,sender_id.eq.$currentUserId,receiver_id.eq.$currentUserId');
  }

  final response = await dbQuery.order('created_at', ascending: false).limit(10);
  
  return response.map((json) => ChatMessage.fromJson(json)).toList();
}

enum AttachmentUploadStatus { idle, uploading, sent, failed }

class AttachmentUploadState {
  final AttachmentUploadStatus status;
  final String? localPath;
  final String? error;
  final VoidCallback? onRetry;

  const AttachmentUploadState({
    required this.status,
    this.localPath,
    this.error,
    this.onRetry,
  });
}

class AttachmentUploadStateNotifier extends Notifier<Map<String, AttachmentUploadState>> {
  @override
  Map<String, AttachmentUploadState> build() => {};

  void setUploadState(String messageId, AttachmentUploadState uploadState) {
    state = {...state, messageId: uploadState};
  }

  void removeUploadState(String messageId) {
    final newMap = Map<String, AttachmentUploadState>.from(state);
    newMap.remove(messageId);
    state = newMap;
  }
}

final attachmentUploadStateProvider = NotifierProvider<AttachmentUploadStateNotifier, Map<String, AttachmentUploadState>>(() {
  return AttachmentUploadStateNotifier();
});

final _chatCache = <String, List<ChatMessage>>{};
final _chatHasMoreCache = <String, bool>{};

// ── Chat stream — keepAlive so it never resets on navigation ─────────────────
@Riverpod(keepAlive: true)
class ChatStream extends _$ChatStream {
  RealtimeChannel? _channelSub;
  RealtimeChannel? _receiptsSub;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  
  @override
  FutureOr<List<ChatMessage>> build(String channel) async {
    final repository = ref.watch(chatRepositoryProvider);
    
    final messages = await repository.getPaginatedMessages(channelName: channel, limit: 30);
    _hasMore = messages.length == 30;
    
    final currentCache = _chatCache[channel] ?? [];
    final optimisticMessages = currentCache.where((c) => !messages.any((m) => m.id == c.id)).toList();
    final finalMessages = [...messages, ...optimisticMessages];
    finalMessages.sort((a, b) {
      final t = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
      return t != 0 ? t : a.id.compareTo(b.id);
    });
    
    final messageIds = finalMessages.map((m) => m.id).toList();
    if (messageIds.isNotEmpty) {
      final receipts = await repository.fetchReceiptsForMessages(messageIds);
      ReadReceiptsTracker.injectReceipts(receipts);
    }
    
    _chatCache[channel] = finalMessages;
    _chatHasMoreCache[channel] = _hasMore;
    
    _channelSub = repository.subscribeToMessages(
      channelName: channel,
      onEvent: _handlePostgresEvent,
    );

    _receiptsSub = repository.subscribeToReadReceipts(
      channelName: channel,
      onEvent: _handleReadReceiptEvent,
    );
    
    ref.onDispose(() {
      _channelSub?.unsubscribe();
      _receiptsSub?.unsubscribe();
    });
    
    return finalMessages;
  }

  void _updateState(List<ChatMessage> newList) {
    state = AsyncData(newList);
    print('Riverpod state assigned successfully');
    _chatCache[channel] = newList;
  }

  Future<void> loadMoreMessages({int limit = 10}) async {
    if (!_hasMore || _isLoadingMore) return;
    
    final currentList = state.value ?? [];
    if (currentList.isEmpty) return;

    final oldestMessageDate = currentList.first.createdAt;

    _isLoadingMore = true;
    state = AsyncData([...currentList]); // Force rebuild to show loading spinner

    try {
      final repository = ref.read(chatRepositoryProvider);
      final newMessages = await repository.getPaginatedMessages(
        channelName: channel,
        limit: limit,
        before: oldestMessageDate,
      );

      _hasMore = newMessages.length == limit;
      _chatHasMoreCache[channel] = _hasMore;
      
      if (newMessages.isNotEmpty) {
        final updatedList = [...newMessages, ...currentList];
        
        final messageIds = newMessages.map((m) => m.id).toList();
        final receipts = await repository.fetchReceiptsForMessages(messageIds);
        ReadReceiptsTracker.injectReceipts(receipts);
        
        _isLoadingMore = false;
        _updateState(updatedList);
        return;
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    }
    
    _isLoadingMore = false;
    state = AsyncData([...currentList]); // Force rebuild to hide loading spinner
  }

  void _handleReadReceiptEvent(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
      final record = payload.newRecord;
      final msgId = record['message_id']?.toString();
      final userId = record['user_id']?.toString();
      if (msgId != null && userId != null) {
        ReadReceiptsTracker.injectReceipt(msgId, userId);
      }
    }
  }

  void _handlePostgresEvent(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert) {
      final newMsg = ChatMessage.fromJson(payload.newRecord);
      if (newMsg.channel != channel || newMsg.receiverId != null) return;
      final currentList = state.value ?? [];
      if (!currentList.any((m) => m.id == newMsg.id)) {
        _updateState([...currentList, newMsg]);
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      final updatedMsg = ChatMessage.fromJson(payload.newRecord);
      if (updatedMsg.channel != channel || updatedMsg.receiverId != null) return;
      final currentList = state.value ?? [];
      final index = currentList.indexWhere((m) => m.id == updatedMsg.id);
      if (index != -1) {
        final newList = List<ChatMessage>.from(currentList);
        newList[index] = updatedMsg;
        _updateState(newList);
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'] as String?;
      if (deletedId != null) {
        ref.read(chatCacheServiceProvider).removeMessage(channel, deletedId);
        final currentList = state.value ?? [];
        if (currentList.any((m) => m.id == deletedId)) {
          _updateState(currentList.where((m) => m.id != deletedId).toList());
        }
      }
    }
  }

  void injectOptimisticMessage(ChatMessage message) {
    ref.read(chatCacheServiceProvider).upsertMessage(channel, message);
    final currentList = state.value ?? [];
    if (!currentList.any((m) => m.id == message.id)) {
      _updateState([...currentList, message]);
    }
  }

  void optimisticDelete(String messageId) {
    final currentList = state.value ?? [];
    final index = currentList.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final newList = List<ChatMessage>.from(currentList);
      final oldMsg = newList[index];
      newList[index] = oldMsg.copyWith(isDeleted: true, content: '');
      _updateState(newList);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final currentList = state.value ?? [];
      if (currentList.isEmpty) return;

      final oldestMsg = currentList.first;
      final repository = ref.read(chatRepositoryProvider);
      final olderMessages = await repository.getPaginatedMessages(
        channelName: channel,
        before: oldestMsg.createdAt,
        limit: 30,
      );

    if (olderMessages.length < 30) {
      _hasMore = false;
      _chatHasMoreCache[channel] = false;
    }
    
    final messageIds = olderMessages.map((m) => m.id).toList();
    if (messageIds.isNotEmpty) {
      final receipts = await repository.fetchReceiptsForMessages(messageIds);
      ReadReceiptsTracker.injectReceipts(receipts);
    }
    
    _updateState([...olderMessages, ...currentList]);
    } finally {
      _isLoadingMore = false;
    }
  }

  void refresh() {
    ref.invalidateSelf();
  }

  Future<void> softRefresh() async {
    final repository = ref.read(chatRepositoryProvider);
    final currentList = state.value ?? [];
    
    // Reconnect subscriptions
    _channelSub?.unsubscribe();
    _receiptsSub?.unsubscribe();
    _channelSub = repository.subscribeToMessages(
      channelName: channel,
      onEvent: _handlePostgresEvent,
    );
    _receiptsSub = repository.subscribeToReadReceipts(
      channelName: channel,
      onEvent: _handleReadReceiptEvent,
    );
    
    // Fetch latest messages and append missing ones
    if (currentList.isNotEmpty) {
      final messages = await repository.getPaginatedMessages(channelName: channel, limit: 30);
      final newMessages = messages.where((m) => !currentList.any((c) => c.id == m.id)).toList();
      if (newMessages.isNotEmpty) {
        final combined = [...currentList, ...newMessages];
        combined.sort((a, b) {
          final t = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
          return t != 0 ? t : a.id.compareTo(b.id);
        });
        _updateState(combined);
      }
    } else {
      final messages = await repository.getPaginatedMessages(channelName: channel, limit: 30);
      _updateState(messages);
    }
  }
}

final _dmCache = <String, List<ChatMessage>>{};
final _dmHasMoreCache = <String, bool>{};

// ── DM Chat stream — keepAlive so it never resets on navigation ──────────────
@Riverpod(keepAlive: true)
class DmStream extends _$DmStream {
  RealtimeChannel? _channelSub;
  RealtimeChannel? _receiptsSub;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  
  @override
  FutureOr<List<ChatMessage>> build(String chatPartnerId) async {
    final repository = ref.watch(chatRepositoryProvider);
    final myId = ref.watch(authProvider)?.id;
    final messages = await repository.getPaginatedMessages(
      currentUserId: myId,
      chatPartnerId: chatPartnerId,
      limit: 30,
    );
    _hasMore = messages.length == 30;
    
    final cacheKey = '${myId}_$chatPartnerId';
    final currentCache = _dmCache[cacheKey] ?? [];
    final optimisticMessages = currentCache.where((c) => !messages.any((m) => m.id == c.id)).toList();
    final finalMessages = [...messages, ...optimisticMessages];
    finalMessages.sort((a, b) {
      final t = a.createdAt.toUtc().compareTo(b.createdAt.toUtc());
      return t != 0 ? t : a.id.compareTo(b.id);
    });
    
    final messageIds = finalMessages.map((m) => m.id).toList();
    if (messageIds.isNotEmpty) {
      final receipts = await repository.fetchReceiptsForMessages(messageIds);
      ReadReceiptsTracker.injectReceipts(receipts);
    }
    
    if (myId != null) {
      _dmCache[cacheKey] = finalMessages;
      _dmHasMoreCache[cacheKey] = _hasMore;
    }
    
    _channelSub = repository.subscribeToMessages(
      channelName: 'dm',
      currentUserId: myId,
      chatPartnerId: chatPartnerId,
      onEvent: _handlePostgresEvent,
    );

    _receiptsSub = repository.subscribeToReadReceipts(
      channelName: 'dm',
      currentUserId: myId,
      chatPartnerId: chatPartnerId,
      onEvent: _handleReadReceiptEvent,
    );
    
    ref.onDispose(() {
      _channelSub?.unsubscribe();
      _receiptsSub?.unsubscribe();
    });
    
    return finalMessages;
  }

  void _updateState(List<ChatMessage> newList) {
    state = AsyncData(newList);
    final myId = ref.read(authProvider)?.id;
    if (myId != null) {
      final cacheKey = '${myId}_$chatPartnerId';
      _dmCache[cacheKey] = newList;
    }
  }

  void _handleReadReceiptEvent(PostgresChangePayload payload) {
    if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
      final record = payload.newRecord;
      final msgId = record['message_id']?.toString();
      final userId = record['user_id']?.toString();
      if (msgId != null && userId != null) {
        ReadReceiptsTracker.injectReceipt(msgId, userId);
      }
    }
  }

  void _handlePostgresEvent(PostgresChangePayload payload) {
    final myId = ref.read(authProvider)?.id;
    if (myId == null) return;

    if (payload.eventType == PostgresChangeEvent.insert) {
      print('Postgres INSERT received for DM!');
      final newMsg = ChatMessage.fromJson(payload.newRecord);
      final isRelevant = (newMsg.senderId == myId && newMsg.receiverId == chatPartnerId) ||
                         (newMsg.senderId == chatPartnerId && newMsg.receiverId == myId);
      if (!isRelevant) return;
      final currentList = state.value ?? [];
      if (!currentList.any((m) => m.id == newMsg.id)) {
        _updateState([...currentList, newMsg]);
      }
    } else if (payload.eventType == PostgresChangeEvent.update) {
      print('Postgres UPDATE received for DM! Record ID: ${payload.newRecord['id']}');
      final updatedMsg = ChatMessage.fromJson(payload.newRecord);
      final isRelevant = (updatedMsg.senderId == myId && updatedMsg.receiverId == chatPartnerId) ||
                         (updatedMsg.senderId == chatPartnerId && updatedMsg.receiverId == myId);
      if (!isRelevant) return;
      final currentList = state.value ?? [];
      final index = currentList.indexWhere((m) => m.id == updatedMsg.id);
      if (index != -1) {
        final newList = List<ChatMessage>.from(currentList);
        newList[index] = updatedMsg;
        _updateState(newList);
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'] as String?;
      if (deletedId != null) {
        final myId = ref.read(authProvider)?.id;
        if (myId != null) {
          final cacheKey = '${myId}_$chatPartnerId';
          ref.read(chatCacheServiceProvider).removeMessage(cacheKey, deletedId);
        }
        final currentList = state.value ?? [];
        if (currentList.any((m) => m.id == deletedId)) {
          _updateState(currentList.where((m) => m.id != deletedId).toList());
        }
      }
    }
  }

  void injectOptimisticMessage(ChatMessage message) {
    final myId = ref.read(authProvider)?.id;
    if (myId != null) {
      final cacheKey = '${myId}_$chatPartnerId';
      ref.read(chatCacheServiceProvider).upsertMessage(cacheKey, message);
    }
    final currentList = state.value ?? [];
    if (!currentList.any((m) => m.id == message.id)) {
      _updateState([...currentList, message]);
    }
    ref.read(dmConversationsProvider.notifier).onOptimisticMessageSent(message);
  }

  void optimisticDelete(String messageId) {
    final currentList = state.value ?? [];
    final index = currentList.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final newList = List<ChatMessage>.from(currentList);
      final oldMsg = newList[index];
      newList[index] = oldMsg.copyWith(isDeleted: true, content: '');
      _updateState(newList);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    try {
      final currentList = state.value ?? [];
      if (currentList.isEmpty) return;

      final oldestMsg = currentList.first;
      final repository = ref.read(chatRepositoryProvider);
      final myId = ref.read(authProvider)?.id;
    
    final olderMessages = await repository.getPaginatedMessages(
      currentUserId: myId,
      chatPartnerId: chatPartnerId,
      before: oldestMsg.createdAt,
      limit: 30,
    );

    if (olderMessages.length < 30) {
      _hasMore = false;
      if (myId != null) {
        final cacheKey = '${myId}_$chatPartnerId';
        _dmHasMoreCache[cacheKey] = false;
      }
    }
    
    final messageIds = olderMessages.map((m) => m.id).toList();
    if (messageIds.isNotEmpty) {
      final receipts = await repository.fetchReceiptsForMessages(messageIds);
      ReadReceiptsTracker.injectReceipts(receipts);
    }
    
    _updateState([...olderMessages, ...currentList]);
    } finally {
      _isLoadingMore = false;
    }
  }

  void refresh() {
    ref.invalidateSelf();
  }
}

// ── Last-seen timestamp per user, persisted in SharedPreferences ─────────────
@Riverpod(keepAlive: true)
class ChatLastSeen extends _$ChatLastSeen {
  static const _lastViewedKey = 'chat_last_viewed_at';

  @override
  Future<DateTime> build() async {
    final myId = ref.watch(authProvider)?.id;
    if (myId == null) return DateTime.now().toUtc();

    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastViewedKey}_$myId';
    final lastViewedStr = prefs.getString(key);

    if (lastViewedStr != null) {
      return DateTime.parse(lastViewedStr).toUtc();
    }

    // First login — treat everything currently in the DB as already read
    // by setting lastSeen to the latest message timestamp (or now if no
    // messages). This prevents the badge and toasts from firing for all
    // historical messages on first login.
    final messages = ref.read(chatStreamProvider('support-chat')).asData?.value;
    final DateTime baseline;
    if (messages != null && messages.isNotEmpty) {
      baseline = messages.last.createdAt.toUtc().add(
        const Duration(milliseconds: 500),
      );
    } else {
      baseline = DateTime.now().toUtc();
    }
    await prefs.setString(key, baseline.toIso8601String());
    return baseline;
  }

  Future<void> updateLastSeen(DateTime timestamp, {String? userId}) async {
    final activeUserId = ref.read(authProvider)?.id;
    final targetUserId = userId ?? activeUserId;
    if (targetUserId == null) return;

    final next = timestamp.toUtc();

    // Update in-memory state for the active user (only move forward)
    if (targetUserId == activeUserId) {
      final current =
          state.value ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (next.isAfter(current)) {
        state = AsyncData(next);
      }
    }

    // Persist — only write if newer than what's stored
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_lastViewedKey}_$targetUserId';
      final existing = prefs.getString(key);
      if (existing == null || next.isAfter(DateTime.parse(existing).toUtc())) {
        await prefs.setString(key, next.toIso8601String());
      }
    } catch (_) {}
  }
}

// ── Unread count — keepAlive so badge stays correct across navigation ─────────
@Riverpod(keepAlive: true)
class ChatUnreadCount extends _$ChatUnreadCount {
  @override
  int build() {
    final myId = ref.watch(authProvider)?.id;
    if (myId == null) return 0;

    final messagesAsync = ref.watch(chatStreamProvider('support-chat'));
    final lastSeenAsync = ref.watch(chatLastSeenProvider);

    // Set up callback to invalidate when tracker changes
    ReadReceiptsTracker.setOnChangeCallback(() {
      ref.invalidateSelf();
    });

    // Don't calculate unread count until lastSeen has loaded.
    // Otherwise every message appears unread on app restart.
    if (lastSeenAsync.isLoading) return 0;

    return messagesAsync.maybeWhen(
      data: (messages) {
        if (messages.isEmpty) return 0;
        final normalizedMyId = myId.toString().trim().toLowerCase();
        final lastSeen = lastSeenAsync.value;

        final unreadCount = messages.where((m) {
          if (m.senderId.trim().toLowerCase() == normalizedMyId) return false;

          // Primary: messages older than or equal to lastSeen are read
          if (lastSeen != null && !m.createdAt.toUtc().isAfter(lastSeen)) {
            return false;
          }

          // Secondary: explicit per-message read receipt
          final readBy = ReadReceiptsTracker.getReadBy(m.id);
          if (readBy.contains(normalizedMyId)) return false;

          return true;
        }).length;

        return unreadCount;
      },
      orElse: () => 0,
    );
  }

  /// Call this when the user opens the chat page.
  Future<void> markAsRead({DateTime? timestamp}) async {
    final myId = ref.read(authProvider)?.id;
    if (myId == null) return;

    DateTime effectiveTimestamp;

    if (timestamp != null) {
      effectiveTimestamp = timestamp;
    } else {
      final messages = ref.read(chatStreamProvider('support-chat')).asData?.value;
      if (messages != null && messages.isNotEmpty) {
        effectiveTimestamp = messages.last.createdAt;
      } else {
        effectiveTimestamp = DateTime.now().toUtc();
      }
    }

    // Add a small buffer so messages at the exact same millisecond are covered
    final safeTimestamp = effectiveTimestamp.toUtc().add(
      const Duration(milliseconds: 500),
    );

    await ref
        .read(chatLastSeenProvider.notifier)
        .updateLastSeen(safeTimestamp, userId: myId);

    // Also update in ReadReceiptsTracker for per-user tracking
    await ReadReceiptsTracker.updateUserLastSeen(myId, safeTimestamp);

    // Mark all visible messages as read in the read receipts tracker
    final messages = ref.read(chatStreamProvider('support-chat')).asData?.value ?? [];
    for (final message in messages) {
      if (message.senderId != myId) {
        // Only mark messages from others as read
        await ReadReceiptsTracker.markAsRead(message.id, myId);
      }
    }
  }
}

// ── New-message event for toast notifications ─────────────────────────────────
@Riverpod(keepAlive: true)
class ChatNewMessageEvent extends _$ChatNewMessageEvent {
  // Track IDs we've already notified so re-registering listeners never
  // re-fires for the same message (happens on every navigation rebuild or
  // provider re-creation within the same session).
  static final Set<String> _notifiedIds = {};

  @override
  ChatMessage? build() => null;

  /// Only fires if this message hasn't been notified before in this session
  /// AND the message is newer than the user's last-seen timestamp.
  void notify(ChatMessage message) {
    if (_notifiedIds.contains(message.id)) return;

    // Extra guard: never toast a message the user has already "seen"
    // (i.e. it was present before they logged in this session).
    final lastSeenAsync = ref.read(chatLastSeenProvider);
    final lastSeen = lastSeenAsync.value;
    if (lastSeen != null && !message.createdAt.toUtc().isAfter(lastSeen)) {
      // Message is older than or equal to lastSeen — mark as notified so
      // we never try again, but don't show a toast.
      _notifiedIds.add(message.id);
      return;
    }

    _notifiedIds.add(message.id);
    state = message;
  }

  void clear() => state = null;

  /// Call on logout to reset the notified-IDs set for the next user.
  static void resetSession() => _notifiedIds.clear();
}

// ════════════════════════════════════════════════════════════════════════════
// All-AroundTally channel — read state & notifications (mirrors support chat)
// ════════════════════════════════════════════════════════════════════════════
const String kAllAroundTallyChannel = 'all-aroundtally';

// ── Last-seen timestamp for all-aroundtally, persisted in SharedPreferences ──
@Riverpod(keepAlive: true)
class AllAroundTallyLastSeen extends _$AllAroundTallyLastSeen {
  static const _lastViewedKey = 'aroundtally_last_viewed_at';

  @override
  Future<DateTime> build() async {
    final myId = ref.watch(authProvider)?.id;
    if (myId == null) return DateTime.now().toUtc();

    final prefs = await SharedPreferences.getInstance();
    final key = '${_lastViewedKey}_$myId';
    final lastViewedStr = prefs.getString(key);

    if (lastViewedStr != null) {
      return DateTime.parse(lastViewedStr).toUtc();
    }

    // First login — treat everything currently in the DB as already read so
    // the badge and toasts don't fire for all historical messages.
    final messages =
        ref.read(chatStreamProvider(kAllAroundTallyChannel)).asData?.value;
    final DateTime baseline;
    if (messages != null && messages.isNotEmpty) {
      baseline = messages.last.createdAt.toUtc().add(
        const Duration(milliseconds: 500),
      );
    } else {
      baseline = DateTime.now().toUtc();
    }
    await prefs.setString(key, baseline.toIso8601String());
    return baseline;
  }

  Future<void> updateLastSeen(DateTime timestamp, {String? userId}) async {
    final activeUserId = ref.read(authProvider)?.id;
    final targetUserId = userId ?? activeUserId;
    if (targetUserId == null) return;

    final next = timestamp.toUtc();

    if (targetUserId == activeUserId) {
      final current =
          state.value ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      if (next.isAfter(current)) {
        state = AsyncData(next);
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_lastViewedKey}_$targetUserId';
      final existing = prefs.getString(key);
      if (existing == null || next.isAfter(DateTime.parse(existing).toUtc())) {
        await prefs.setString(key, next.toIso8601String());
      }
    } catch (_) {}
  }
}

// ── Unread count for all-aroundtally — keepAlive so badge stays correct ──────
@Riverpod(keepAlive: true)
class AllAroundTallyUnreadCount extends _$AllAroundTallyUnreadCount {
  @override
  int build() {
    final myId = ref.watch(authProvider)?.id;
    if (myId == null) return 0;

    final messagesAsync = ref.watch(chatStreamProvider(kAllAroundTallyChannel));
    final lastSeenAsync = ref.watch(allAroundTallyLastSeenProvider);

    if (lastSeenAsync.isLoading) return 0;

    return messagesAsync.maybeWhen(
      data: (messages) {
        if (messages.isEmpty) return 0;
        final normalizedMyId = myId.toString().trim().toLowerCase();
        final lastSeen = lastSeenAsync.value;

        return messages.where((m) {
          if (m.senderId.trim().toLowerCase() == normalizedMyId) return false;
          if (m.isDeleted) return false;

          // Primary: messages older than or equal to lastSeen are read
          if (lastSeen != null && !m.createdAt.toUtc().isAfter(lastSeen)) {
            return false;
          }

          // Secondary: explicit per-message read receipt
          final readBy = ReadReceiptsTracker.getReadBy(m.id);
          if (readBy.contains(normalizedMyId)) return false;

          return true;
        }).length;
      },
      orElse: () => 0,
    );
  }

  /// Call this when the user opens the all-aroundtally channel page.
  Future<void> markAsRead({DateTime? timestamp}) async {
    final myId = ref.read(authProvider)?.id;
    if (myId == null) return;

    DateTime effectiveTimestamp;
    if (timestamp != null) {
      effectiveTimestamp = timestamp;
    } else {
      final messages =
          ref.read(chatStreamProvider(kAllAroundTallyChannel)).asData?.value;
      if (messages != null && messages.isNotEmpty) {
        effectiveTimestamp = messages.last.createdAt;
      } else {
        effectiveTimestamp = DateTime.now().toUtc();
      }
    }

    final safeTimestamp = effectiveTimestamp.toUtc().add(
      const Duration(milliseconds: 500),
    );

    await ref
        .read(allAroundTallyLastSeenProvider.notifier)
        .updateLastSeen(safeTimestamp, userId: myId);

    // Mark visible messages from others as read in the (channel-agnostic,
    // message-id keyed) read receipts tracker.
    final messages =
        ref.read(chatStreamProvider(kAllAroundTallyChannel)).asData?.value ?? [];
    for (final message in messages) {
      if (message.senderId != myId) {
        await ReadReceiptsTracker.markAsRead(message.id, myId);
      }
    }
  }
}

// ── New-message event for all-aroundtally toast notifications ────────────────
@Riverpod(keepAlive: true)
class AllAroundTallyNewMessageEvent extends _$AllAroundTallyNewMessageEvent {
  static final Set<String> _notifiedIds = {};

  @override
  ChatMessage? build() => null;

  void notify(ChatMessage message) {
    if (_notifiedIds.contains(message.id)) return;

    final lastSeenAsync = ref.read(allAroundTallyLastSeenProvider);
    final lastSeen = lastSeenAsync.value;
    if (lastSeen != null && !message.createdAt.toUtc().isAfter(lastSeen)) {
      _notifiedIds.add(message.id);
      return;
    }

    _notifiedIds.add(message.id);
    state = message;
  }

  void clear() => state = null;

  /// Call on logout to reset the notified-IDs set for the next user.
  static void resetSession() => _notifiedIds.clear();
}

// ── Read receipts tracking (client-side) ─────────────────────────────────────
class ReadReceiptsTracker {
  static const _readReceiptsKey = 'chat_read_receipts';
  static const _userLastSeenKey = 'chat_user_last_seen_';

  // In-memory cache for synchronous access
  static Map<String, Set<String>> _cache = {};
  static Map<String, DateTime> _userLastSeenCache = {};
  static bool _initialized = false;
  static bool _isInitializing = false; // Prevent concurrent initialization

  // Callback to notify when tracker changes
  static VoidCallback? _onChange;

  static void setOnChangeCallback(VoidCallback callback) {
    _onChange = callback;
  }

  static Future<void> _initialize() async {
    if (_initialized || _isInitializing) return;

    _isInitializing = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load read receipts
      final data = prefs.getString(_readReceiptsKey);
      if (data != null) {
        final Map<String, dynamic> decoded = jsonDecode(data);
        _cache = decoded.map(
          (key, value) => MapEntry(
            key,
            (value as List)
                .map((e) => e.toString().trim().toLowerCase())
                .toSet(),
          ),
        );
      }

      // Load user last seen timestamps
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_userLastSeenKey)) {
          final userId = key.substring(_userLastSeenKey.length);
          final timestampStr = prefs.getString(key);
          if (timestampStr != null) {
            _userLastSeenCache[userId] = DateTime.parse(timestampStr);
          }
        }
      }

      _initialized = true;
      // Notify listeners that tracker is now initialized
      _onChange?.call();
    } catch (e) {
      // If loading fails, continue with empty cache
      debugPrint('Error loading ReadReceiptsTracker: $e');
    } finally {
      _isInitializing = false;
    }
  }

  static Future<void> _saveReadReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _cache.map((key, value) => MapEntry(key, value.toList())),
    );
    await prefs.setString(_readReceiptsKey, encoded);
  }

  static Future<void> _saveUserLastSeen(
    String userId,
    DateTime timestamp,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_userLastSeenKey$userId',
      timestamp.toIso8601String(),
    );
    _userLastSeenCache[userId] = timestamp;
  }

  static Future<void> markAsRead(String messageId, String userId) async {
    await _initialize();
    if (!_cache.containsKey(messageId)) {
      _cache[messageId] = {};
    }
    _cache[messageId]!.add(userId.trim().toLowerCase());
    await _saveReadReceipts();
    await _saveRemoteReadReceipt(messageId, userId);
    // Notify listeners that tracker changed
    _onChange?.call();
  }

  static Future<void> markMultipleAsRead(List<String> messageIds, String userId) async {
    if (messageIds.isEmpty) return;
    await _initialize();
    
    for (final messageId in messageIds) {
      if (!_cache.containsKey(messageId)) {
        _cache[messageId] = {};
      }
      _cache[messageId]!.add(userId.trim().toLowerCase());
    }
    
    await _saveReadReceipts();
    
    try {
      final payload = messageIds.map((id) => {
        'message_id': id,
        'user_id': userId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }).toList();
      await Supabase.instance.client.from('chat_read_receipts').upsert(payload, onConflict: 'message_id,user_id');
    } catch (e) {
      debugPrint('Unable to save multiple remote chat read receipts: $e');
    }
    
    _onChange?.call();
  }

  static Future<void> updateUserLastSeen(
    String userId,
    DateTime timestamp,
  ) async {
    await _initialize();
    await _saveUserLastSeen(userId, timestamp);
  }

  static DateTime? getUserLastSeen(String userId) {
    // Return cached value even if not fully initialized
    return _userLastSeenCache[userId];
  }

  static Set<String> getReadBy(String messageId) {
    // Return cached value even if not fully initialized
    // The initialization happens asynchronously in preload()
    return _cache[messageId] ?? {};
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_readReceiptsKey);
    final keys = prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith(_userLastSeenKey)) {
        await prefs.remove(key);
      }
    }
    _cache = {};
    _userLastSeenCache = {};
    _initialized = false;
  }

  static Future<void> preload() async {
    await _initialize();
  }

  static void injectReceipts(Map<String, Set<String>> receipts) {
    bool changed = false;
    for (final entry in receipts.entries) {
      if (!_cache.containsKey(entry.key)) {
        _cache[entry.key] = {};
      }
      final beforeCount = _cache[entry.key]!.length;
      _cache[entry.key]!.addAll(entry.value);
      if (_cache[entry.key]!.length != beforeCount) {
        changed = true;
      }
    }
    if (changed) {
      _saveReadReceipts();
      _onChange?.call();
    }
  }

  static void injectReceipt(String messageId, String userId) {
    if (!_cache.containsKey(messageId)) {
      _cache[messageId] = {};
    }
    final normalizedUser = userId.trim().toLowerCase();
    if (!_cache[messageId]!.contains(normalizedUser)) {
      _cache[messageId]!.add(normalizedUser);
      _saveReadReceipts();
      _onChange?.call();
    }
  }

  static Future<void> _saveRemoteReadReceipt(
    String messageId,
    String userId,
  ) async {
    try {
      await Supabase.instance.client.from('chat_read_receipts').upsert({
        'message_id': messageId,
        'user_id': userId,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'message_id,user_id');
    } catch (e) {
      debugPrint('Unable to save remote chat read receipt: $e');
    }
  }
}

// ── Chat controller ───────────────────────────────────────────────────────────
@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  @override
  FutureOr<void> build() {}

  Future<String> sendMessage({
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
    state = const AsyncLoading();
    final messageId = const Uuid().v4();
    
    // Create optimistic message
    final optimisticMessage = ChatMessage(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: content,
      receiverId: receiverId,
      senderAvatarUrl: senderAvatarUrl,
      createdAt: DateTime.now().toUtc(),
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      channel: channel,
      richTextDelta: richTextDelta,
    );

    // Inject optimistic message immediately
    if (receiverId != null) {
      ref.read(dmStreamProvider(receiverId).notifier).injectOptimisticMessage(optimisticMessage);
    } else {
      ref.read(chatStreamProvider(channel).notifier).injectOptimisticMessage(optimisticMessage);
    }

    state = await AsyncValue.guard(
      () async {
        try {
          await ref
              .read(chatRepositoryProvider)
              .sendMessage(
                id: messageId,
                senderId: senderId,
                senderName: senderName,
                senderRole: senderRole,
                content: content,
                receiverId: receiverId,
                senderAvatarUrl: senderAvatarUrl,
                replyToMessageId: replyToMessageId,
                replyToSenderName: replyToSenderName,
                richTextDelta: richTextDelta,
                replyToContent: replyToContent,
                fileUrl: fileUrl,
                fileName: fileName,
                fileType: fileType,
                channel: channel,
              );
        } catch (e, st) {
          print('SEND MESSAGE ERROR: $e');
          print('SEND MESSAGE STACKTRACE: $st');
          rethrow;
        }
      },
    );
    return messageId;
  }

  Future<void> deleteMessage(String messageId, {String? receiverId, String channel = 'support-chat'}) async {
    state = const AsyncLoading();

    // Optimistic delete
    if (receiverId != null) {
      ref.read(dmStreamProvider(receiverId).notifier).optimisticDelete(messageId);
    } else {
      ref.read(chatStreamProvider(channel).notifier).optimisticDelete(messageId);
    }

    state = await AsyncValue.guard(
      () => ref.read(chatRepositoryProvider).deleteMessage(messageId),
    );
  }

  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await ref.read(chatRepositoryProvider).toggleReaction(
      messageId: messageId,
      userId: userId,
      emoji: emoji,
    );
  }

  Future<String> sendVoiceMessage({
    required String senderId,
    required String senderName,
    required String senderRole,
    required String localAudioPath,
    required int durationSeconds,
    String? receiverId,
    String? senderAvatarUrl,
    String? replyToMessageId,
    String? replyToSenderName,
    String? replyToContent,
    String channel = 'support-chat',
  }) async {
    final messageId = const Uuid().v4();
    final fileName = 'voice_${durationSeconds}_${DateTime.now().millisecondsSinceEpoch}.webm';
    
    // Create optimistic message (using localPath as temporary fileUrl, no text content as requested)
    final optimisticMessage = ChatMessage(
      id: messageId,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      content: '',
      receiverId: receiverId,
      senderAvatarUrl: senderAvatarUrl,
      createdAt: DateTime.now().toUtc(),
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      fileUrl: localAudioPath,
      fileName: fileName,
      fileType: 'voice',
      channel: channel,
    );

    // Inject optimistic message immediately
    if (receiverId != null) {
      ref.read(dmStreamProvider(receiverId).notifier).injectOptimisticMessage(optimisticMessage);
    } else {
      ref.read(chatStreamProvider(channel).notifier).injectOptimisticMessage(optimisticMessage);
    }

    // Set initial uploading status
    ref.read(attachmentUploadStateProvider.notifier).setUploadState(
      messageId,
      AttachmentUploadState(
        status: AttachmentUploadStatus.uploading,
        localPath: localAudioPath,
        onRetry: () => _retryVoiceUpload(
          messageId: messageId,
          optimisticMessage: optimisticMessage,
          localAudioPath: localAudioPath,
          fileName: fileName,
          senderId: senderId,
          senderName: senderName,
          senderRole: senderRole,
          receiverId: receiverId,
          senderAvatarUrl: senderAvatarUrl,
          replyToMessageId: replyToMessageId,
          replyToSenderName: replyToSenderName,
          replyToContent: replyToContent,
          channel: channel,
        ),
      ),
    );

    _performVoiceUpload(
      messageId: messageId,
      localAudioPath: localAudioPath,
      fileName: fileName,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      receiverId: receiverId,
      senderAvatarUrl: senderAvatarUrl,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      channel: channel,
      optimisticMessage: optimisticMessage,
    );

    return messageId;
  }

  Future<void> _performVoiceUpload({
    required String messageId,
    required String localAudioPath,
    required String fileName,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String? receiverId,
    required String? senderAvatarUrl,
    required String? replyToMessageId,
    required String? replyToSenderName,
    required String? replyToContent,
    required String channel,
    required ChatMessage optimisticMessage,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      if (kIsWeb) {
        final response = await http.get(Uri.parse(localAudioPath));
        final bytes = response.bodyBytes;
        await supabase.storage.from('chat_attachments').uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(contentType: 'audio/webm', upsert: true),
        );
      } else {
        final file = File(localAudioPath);
        await supabase.storage.from('chat_attachments').upload(
          fileName,
          file,
          fileOptions: const FileOptions(contentType: 'audio/webm', upsert: true),
        );
      }

      final publicUrl = supabase.storage.from('chat_attachments').getPublicUrl(fileName);
      if (publicUrl.isEmpty) throw Exception('Empty URL returned from storage');

      await ref.read(chatRepositoryProvider).sendMessage(
        id: messageId,
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        content: '',
        receiverId: receiverId,
        senderAvatarUrl: senderAvatarUrl,
        replyToMessageId: replyToMessageId,
        replyToSenderName: replyToSenderName,
        replyToContent: replyToContent,
        fileUrl: publicUrl,
        fileName: fileName,
        fileType: 'voice',
        channel: channel,
      );

      ref.read(attachmentUploadStateProvider.notifier).removeUploadState(messageId);

      if (!kIsWeb) {
        try {
          await File(localAudioPath).delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Voice message background upload failed: $e');
      final state = ref.read(attachmentUploadStateProvider)[messageId];
      if (state != null) {
        ref.read(attachmentUploadStateProvider.notifier).setUploadState(
          messageId,
          AttachmentUploadState(
            status: AttachmentUploadStatus.failed,
            localPath: localAudioPath,
            error: e.toString(),
            onRetry: state.onRetry,
          ),
        );
      }
    }
  }

  void _retryVoiceUpload({
    required String messageId,
    required ChatMessage optimisticMessage,
    required String localAudioPath,
    required String fileName,
    required String senderId,
    required String senderName,
    required String senderRole,
    required String? receiverId,
    required String? senderAvatarUrl,
    required String? replyToMessageId,
    required String? replyToSenderName,
    required String? replyToContent,
    required String channel,
  }) {
    final state = ref.read(attachmentUploadStateProvider)[messageId];
    if (state != null) {
      ref.read(attachmentUploadStateProvider.notifier).setUploadState(
        messageId,
        AttachmentUploadState(
          status: AttachmentUploadStatus.uploading,
          localPath: localAudioPath,
          onRetry: state.onRetry,
        ),
      );
    }
    _performVoiceUpload(
      messageId: messageId,
      localAudioPath: localAudioPath,
      fileName: fileName,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      receiverId: receiverId,
      senderAvatarUrl: senderAvatarUrl,
      replyToMessageId: replyToMessageId,
      replyToSenderName: replyToSenderName,
      replyToContent: replyToContent,
      channel: channel,
      optimisticMessage: optimisticMessage,
    );
  }
}

// ── Message status model ─────────────────────────────────────────────────────
class MessageStatus {
  final String messageId;
  final List<Map<String, dynamic>> readBy;
  final List<Map<String, dynamic>> deliveredTo;

  const MessageStatus({
    required this.messageId,
    required this.readBy,
    required this.deliveredTo,
  });
}

// ── Message status provider (manual implementation) ───────────────────────
final messageStatusProvider =
    Provider.family<MessageStatus, Map<String, dynamic>>((ref, args) {
      final currentUser = ref.watch(authProvider);
      if (currentUser == null) {
        return const MessageStatus(messageId: '', readBy: [], deliveredTo: []);
      }

      final agentsAsync = ref.watch(agentsListProvider);
      final agents = agentsAsync.value ?? [];

      final messageId = args['messageId'] as String;
      final messageTimestamp = args['messageTimestamp'] as DateTime?;

      // Get read receipts from in-memory cache (synchronous)
      final readByUserIds = ReadReceiptsTracker.getReadBy(messageId);

      // Track delivered and read status
      final readBy = <Map<String, dynamic>>[];
      final deliveredTo = <Map<String, dynamic>>[];

      for (final agent in agents) {
        final agentId = agent['id']?.toString() ?? '';
        if (agentId.isEmpty) continue;

        // Normalize agent ID for comparison
        final normalizedAgentId = agentId.trim().toLowerCase();

        // Skip the sender for delivery (they don't "deliver" to themselves)
        if (agentId != currentUser.id) {
          deliveredTo.add(agent);
        }

        // Skip the sender for read status (they don't "read" their own message)
        if (agentId == currentUser.id) {
          continue;
        }

        // Check if this user has read the message
        // First check read receipts, then fallback to user's lastSeen timestamp
        bool hasRead = false;
        if (readByUserIds.contains(normalizedAgentId)) {
          hasRead = true;
        } else if (messageTimestamp != null) {
          // Fallback: Check if user's lastSeen is after message timestamp
          final userLastSeen = ReadReceiptsTracker.getUserLastSeen(
            normalizedAgentId,
          );
          if (userLastSeen != null) {
            hasRead = messageTimestamp.toUtc().isBefore(userLastSeen);
          }
        }

        if (hasRead) {
          readBy.add(agent);
        }
      }

      return MessageStatus(
        messageId: messageId,
        readBy: readBy,
        deliveredTo: deliveredTo,
      );
    });


// ── Starred messages stream ─────────────────────────────────────────────────────
final starredMessagesStreamProvider = StreamProvider.family<List<ChatMessage>, String>((ref, userId) {
  ref.keepAlive();
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getStarredMessages(userId);
});

// ── DM Conversation State & Engine ──────────────────────────────────────────
class DmConversationState {
  final String partnerId;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final bool isOpen;
  final DateTime? lastReadAt;
  final Set<String> unreadMessageIds;
  final int totalMessageCount;

  const DmConversationState({
    required this.partnerId,
    this.lastMessage,
    required this.unreadCount,
    required this.isOpen,
    this.lastReadAt,
    required this.unreadMessageIds,
    this.totalMessageCount = 0,
  });

  DmConversationState copyWith({
    String? partnerId,
    ChatMessage? lastMessage,
    int? unreadCount,
    bool? isOpen,
    DateTime? lastReadAt,
    Set<String>? unreadMessageIds,
    int? totalMessageCount,
  }) {
    return DmConversationState(
      partnerId: partnerId ?? this.partnerId,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isOpen: isOpen ?? this.isOpen,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      unreadMessageIds: unreadMessageIds ?? this.unreadMessageIds,
      totalMessageCount: totalMessageCount ?? this.totalMessageCount,
    );
  }
}

class CurrentOpenConversationNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  @override
  set state(String? value) => super.state = value;
}

final currentOpenConversationProvider = NotifierProvider<CurrentOpenConversationNotifier, String?>(() {
  return CurrentOpenConversationNotifier();
});

class DmConversationEngine extends Notifier<Map<String, DmConversationState>> {
  Ref get _ref => ref;
  RealtimeChannel? _msgSub;
  RealtimeChannel? _rcptSub;
  bool _isBootstrapping = true;
  final List<PostgresChangePayload> _realtimeBuffer = [];
  final Set<String> _seenMessageIds = {};

  int _stateVersion = 0;
  int get stateVersion => _stateVersion;

  void _commit(Map<String, DmConversationState> nextState, [int? expectedVersion]) {
    if (expectedVersion != null && expectedVersion != _stateVersion) {
      debugPrint('DmConversationEngine warning: stale write rejected (expected revision $expectedVersion, actual $_stateVersion).');
      return;
    }
    _stateVersion++;
    state = nextState;
  }

  @override
  Map<String, DmConversationState> build() {
    // Watch authProvider so that when the user logs out/in, this engine is destroyed and recreated.
    ref.watch(authProvider);

    ref.onDispose(() {
      _msgSub?.unsubscribe();
      _rcptSub?.unsubscribe();
    });
    ref.listen<String?>(currentOpenConversationProvider, (previous, current) {
      onOpenConversationChanged(previous, current);
    });
    Future.microtask(() => _init());
    return const {};
  }

  Future<void> _init() async {
    final authUser = _ref.read(authProvider);
    if (authUser == null) {
      _isBootstrapping = false;
      return;
    }
    final currentUserId = authUser.id;
    final repository = _ref.read(chatRepositoryProvider);
    final cacheService = _ref.read(chatCacheServiceProvider);

    // 1. Start realtime subscriptions immediately before or in parallel with bootstrap
    _msgSub = repository.subscribeToDmEngineMessages(
      currentUserId: currentUserId,
      onEvent: (payload) => _handleMsgEvent(payload, currentUserId),
    );
    _rcptSub = repository.subscribeToDmEngineReadReceipts(
      currentUserId: currentUserId,
      onEvent: (payload) => _handleRcptEvent(payload, currentUserId),
    );

    // 2. Restore Hive cache for instant offline startup
    try {
      final cachedMessages = await cacheService.readAllDmMessages(currentUserId);
      final cacheMap = <String, DmConversationState>{};
      for (final msg in cachedMessages) {
        final partnerId = msg.senderId == currentUserId ? msg.receiverId! : msg.senderId;
        if (partnerId == currentUserId) continue;
        _seenMessageIds.add(msg.id);

        final existing = cacheMap[partnerId];
        if (existing == null) {
          final isOpen = _ref.read(currentOpenConversationProvider) == partnerId;
          final isUnread = !isOpen && msg.senderId == partnerId && !ReadReceiptsTracker.getReadBy(msg.id).contains(currentUserId.trim().toLowerCase());
          final unreadIds = isUnread ? {msg.id} : <String>{};
          cacheMap[partnerId] = DmConversationState(
            partnerId: partnerId,
            lastMessage: msg,
            unreadCount: unreadIds.length,
            isOpen: isOpen,
            unreadMessageIds: unreadIds,
            totalMessageCount: 1,
          );
        } else {
          final isNewer = msg.createdAt.isAfter(existing.lastMessage!.createdAt) || msg.createdAt.isAtSameMomentAs(existing.lastMessage!.createdAt);
          final isOpen = _ref.read(currentOpenConversationProvider) == partnerId;
          final isUnread = !isOpen && msg.senderId == partnerId && !ReadReceiptsTracker.getReadBy(msg.id).contains(currentUserId.trim().toLowerCase());
          final unreadIds = Set<String>.from(existing.unreadMessageIds);
          if (isUnread) unreadIds.add(msg.id);
          cacheMap[partnerId] = existing.copyWith(
            lastMessage: isNewer ? msg : existing.lastMessage,
            unreadCount: unreadIds.length,
            unreadMessageIds: unreadIds,
            totalMessageCount: existing.totalMessageCount + 1,
          );
        }
      }
      if (cacheMap.isNotEmpty) {
        _commit(cacheMap);
      }
    } catch (e) {
      debugPrint('Error loading DM Hive cache into engine: $e');
    }

    // 3. Complete bootstrap / delta sync from Supabase
    try {
      final bootstrapData = await repository.fetchDmConversationsBootstrap(currentUserId);
      final nextState = Map<String, DmConversationState>.from(state);

      for (final entry in bootstrapData.entries) {
        final partnerId = entry.key;
        final data = entry.value;
        final lastMsg = data['last_message'] as ChatMessage?;
        final unreadIds = data['unread_message_ids'] as Set<String>? ?? {};
        final totalCount = data['total_message_count'] as int? ?? 0;

        if (lastMsg != null) _seenMessageIds.add(lastMsg.id);
        for (final id in unreadIds) {
          _seenMessageIds.add(id);
        }

        final isOpen = _ref.read(currentOpenConversationProvider) == partnerId;
        final finalUnreadIds = isOpen ? <String>{} : unreadIds;
        
        final existing = nextState[partnerId];
        if (existing == null) {
          nextState[partnerId] = DmConversationState(
            partnerId: partnerId,
            lastMessage: lastMsg,
            unreadCount: finalUnreadIds.length,
            isOpen: isOpen,
            unreadMessageIds: finalUnreadIds,
            totalMessageCount: totalCount,
          );
        } else {
          final isNewer = lastMsg != null && (existing.lastMessage == null || lastMsg.createdAt.isAfter(existing.lastMessage!.createdAt) || lastMsg.createdAt.isAtSameMomentAs(existing.lastMessage!.createdAt));
          nextState[partnerId] = existing.copyWith(
            lastMessage: isNewer ? lastMsg : existing.lastMessage,
            unreadCount: finalUnreadIds.length,
            unreadMessageIds: finalUnreadIds,
            totalMessageCount: totalCount > existing.totalMessageCount ? totalCount : existing.totalMessageCount,
            isOpen: isOpen,
          );
        }
      }
      _commit(nextState);
    } catch (e) {
      debugPrint('Error running DM bootstrap from Supabase: $e');
    }

    // 4. Replay buffered events in order and continue normal realtime operation
    _isBootstrapping = false;
    if (_realtimeBuffer.isNotEmpty) {
      final toReplay = List<PostgresChangePayload>.from(_realtimeBuffer);
      _realtimeBuffer.clear();
      for (final payload in toReplay) {
        if (payload.table == 'chat_messages') {
          _processMsgPayload(payload, currentUserId);
        } else if (payload.table == 'chat_read_receipts') {
          _processRcptPayload(payload, currentUserId);
        }
      }
    }
  }

  void _handleMsgEvent(PostgresChangePayload payload, String currentUserId) {
    if (_isBootstrapping) {
      _realtimeBuffer.add(payload);
      return;
    }
    _processMsgPayload(payload, currentUserId);
  }

  void _handleRcptEvent(PostgresChangePayload payload, String currentUserId) {
    if (_isBootstrapping) {
      _realtimeBuffer.add(payload);
      return;
    }
    _processRcptPayload(payload, currentUserId);
  }

  void _processMsgPayload(PostgresChangePayload payload, String currentUserId) {
    if (payload.eventType == PostgresChangeEvent.insert || payload.eventType == PostgresChangeEvent.update) {
      final msg = ChatMessage.fromJson(payload.newRecord);
      
      if (msg.receiverId == null) return;
      final isRelevant = (msg.senderId == currentUserId || msg.receiverId == currentUserId);
      if (!isRelevant) return;

      final partnerId = msg.senderId == currentUserId ? msg.receiverId! : msg.senderId;
      if (partnerId == currentUserId) return;

      final isOpen = _ref.read(currentOpenConversationProvider) == partnerId;
      final isInsert = payload.eventType == PostgresChangeEvent.insert;
      
      if (isInsert) {
        if (_seenMessageIds.contains(msg.id)) return;
        _seenMessageIds.add(msg.id);
      }

      final currentMap = state;
      final existing = currentMap[partnerId];

      DmConversationState updatedConv;
      if (existing == null) {
        final isIncoming = msg.senderId == partnerId;
        final shouldMarkUnread = isIncoming && !isOpen;
        final unreadIds = shouldMarkUnread ? {msg.id} : <String>{};
        
        updatedConv = DmConversationState(
          partnerId: partnerId,
          lastMessage: msg,
          unreadCount: unreadIds.length,
          isOpen: isOpen,
          unreadMessageIds: unreadIds,
          totalMessageCount: 1,
        );
      } else {
        ChatMessage? nextLastMessage = existing.lastMessage;
        if (nextLastMessage == null || msg.createdAt.isAfter(nextLastMessage.createdAt) || msg.createdAt.isAtSameMomentAs(nextLastMessage.createdAt) || msg.id == nextLastMessage.id) {
          nextLastMessage = msg;
        }

        final unreadIds = Set<String>.from(existing.unreadMessageIds);
        int nextTotalCount = existing.totalMessageCount;
        if (isInsert) {
          nextTotalCount += 1;
          if (msg.senderId == partnerId) {
            if (!isOpen) {
              unreadIds.add(msg.id);
            }
          }
        }

        updatedConv = existing.copyWith(
          lastMessage: nextLastMessage,
          unreadCount: isOpen ? 0 : unreadIds.length,
          unreadMessageIds: isOpen ? const {} : unreadIds,
          isOpen: isOpen,
          totalMessageCount: nextTotalCount,
        );
      }

      final nextMap = Map<String, DmConversationState>.from(currentMap);
      nextMap[partnerId] = updatedConv;
      _commit(nextMap);

      if (isOpen && msg.senderId == partnerId && isInsert) {
        ReadReceiptsTracker.markMultipleAsRead([msg.id], currentUserId);
      }
    } else if (payload.eventType == PostgresChangeEvent.delete) {
      final deletedId = payload.oldRecord['id'] as String?;
      if (deletedId != null) {
        _seenMessageIds.remove(deletedId);
        final currentMap = state;
        for (final entry in currentMap.entries) {
          if (entry.value.unreadMessageIds.contains(deletedId)) {
            final unreadIds = Set<String>.from(entry.value.unreadMessageIds)..remove(deletedId);
            final nextMap = Map<String, DmConversationState>.from(currentMap);
            nextMap[entry.key] = entry.value.copyWith(
              unreadCount: unreadIds.length,
              unreadMessageIds: unreadIds,
            );
            _commit(nextMap);
            break;
          }
        }
      }
    }
  }

  void _processRcptPayload(PostgresChangePayload payload, String currentUserId) {
    if (payload.eventType != PostgresChangeEvent.insert && payload.eventType != PostgresChangeEvent.update) return;
    final msgId = payload.newRecord['message_id']?.toString();
    final userId = payload.newRecord['user_id']?.toString();
    if (msgId == null || userId == null || userId.trim().toLowerCase() != currentUserId.trim().toLowerCase()) return;

    final currentMap = state;
    String? matchedPartnerId;
    for (final entry in currentMap.entries) {
      if (entry.value.unreadMessageIds.contains(msgId)) {
        matchedPartnerId = entry.key;
        break;
      }
    }

    if (matchedPartnerId != null) {
      final existing = currentMap[matchedPartnerId]!;
      final nextUnreadIds = Set<String>.from(existing.unreadMessageIds)..remove(msgId);
      final nextMap = Map<String, DmConversationState>.from(currentMap);
      nextMap[matchedPartnerId] = existing.copyWith(
        unreadCount: nextUnreadIds.length,
        unreadMessageIds: nextUnreadIds,
        lastReadAt: DateTime.now().toUtc(),
      );
      _commit(nextMap);
    }
  }

  void onOpenConversationChanged(String? previous, String? current) {
    final authUser = _ref.read(authProvider);
    if (authUser == null) return;
    final myId = authUser.id;

    final currentMap = state;
    final nextMap = Map<String, DmConversationState>.from(currentMap);
    bool changed = false;

    if (previous != null && nextMap.containsKey(previous)) {
      nextMap[previous] = nextMap[previous]!.copyWith(isOpen: false);
      changed = true;
    }

    if (current != null) {
      if (!nextMap.containsKey(current)) {
        nextMap[current] = DmConversationState(
          partnerId: current,
          unreadCount: 0,
          isOpen: true,
          unreadMessageIds: const {},
          lastReadAt: DateTime.now().toUtc(),
        );
        changed = true;
      } else {
        final conv = nextMap[current]!;
        if (!conv.isOpen || conv.unreadCount > 0) {
          final idsToMarkRead = Set<String>.from(conv.unreadMessageIds);
          nextMap[current] = conv.copyWith(
            isOpen: true,
            unreadCount: 0,
            unreadMessageIds: const {},
            lastReadAt: DateTime.now().toUtc(),
          );
          changed = true;
          
          if (idsToMarkRead.isNotEmpty) {
            ReadReceiptsTracker.markMultipleAsRead(idsToMarkRead.toList(), myId);
          }
        }
      }
    }

    if (changed) {
      _commit(nextMap);
    }
  }

  void markConversationAsRead(String partnerId) {
    final authUser = _ref.read(authProvider);
    if (authUser == null) return;
    final myId = authUser.id;
    
    final currentMap = state;
    final conv = currentMap[partnerId];
    if (conv == null) return;

    if (conv.unreadCount > 0 || !conv.isOpen) {
      final idsToMarkRead = Set<String>.from(conv.unreadMessageIds);
      final nextMap = Map<String, DmConversationState>.from(currentMap);
      nextMap[partnerId] = conv.copyWith(
        isOpen: _ref.read(currentOpenConversationProvider) == partnerId,
        unreadCount: 0,
        unreadMessageIds: const {},
        lastReadAt: DateTime.now().toUtc(),
      );
      _commit(nextMap);
      if (idsToMarkRead.isNotEmpty) {
        ReadReceiptsTracker.markMultipleAsRead(idsToMarkRead.toList(), myId);
      }
    }
  }

  void onOptimisticMessageSent(ChatMessage message) {
    final authUser = _ref.read(authProvider);
    if (authUser == null || message.receiverId == null) return;
    final myId = authUser.id;
    final partnerId = message.senderId == myId ? message.receiverId! : message.senderId;
    if (partnerId == myId) return;

    _seenMessageIds.add(message.id);
    final currentMap = state;
    final existing = currentMap[partnerId];
    final isOpen = _ref.read(currentOpenConversationProvider) == partnerId;

    DmConversationState updatedConv;
    if (existing == null) {
      updatedConv = DmConversationState(
        partnerId: partnerId,
        lastMessage: message,
        unreadCount: 0,
        isOpen: isOpen,
        unreadMessageIds: const {},
        totalMessageCount: 1,
      );
    } else {
      updatedConv = existing.copyWith(
        lastMessage: message,
        isOpen: isOpen,
        totalMessageCount: existing.totalMessageCount + 1,
      );
    }
    final nextMap = Map<String, DmConversationState>.from(currentMap);
    nextMap[partnerId] = updatedConv;
    _commit(nextMap);
  }

}

final dmConversationsProvider = NotifierProvider<DmConversationEngine, Map<String, DmConversationState>>(() {
  return DmConversationEngine();
});

final dmUnreadCountProvider = Provider.family<int, String>((ref, partnerId) {
  return ref.watch(dmConversationsProvider.select((map) => map[partnerId]?.unreadCount ?? 0));
});
