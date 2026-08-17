import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_notification_service.dart';
import '../../features/chat/presentation/providers/custom_channel_provider.dart';
import 'web_notification_helper.dart';

class GlobalChatNotificationService {
  static RealtimeChannel? _subscription;
  static String? _currentUserId;
  
  static void init(String currentUserId, Ref ref) {
    if (_subscription != null) return;
    _currentUserId = currentUserId;

    // Ask for permissions initially on login
    LocalNotificationService.init();
    if (kIsWeb) {
      requestWebNotificationPermission();
    }

    final channelName = 'public:chat_messages_global_${currentUserId}_${DateTime.now().millisecondsSinceEpoch}';
    _subscription = Supabase.instance.client
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            _handleNewMessage(payload.newRecord, ref);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('GlobalChatNotificationService Realtime status: $status');
          if (error != null) {
            debugPrint('GlobalChatNotificationService Realtime error: $error');
          }
        });
  }

  static void dispose() {
    _subscription?.unsubscribe();
    _subscription = null;
    _currentUserId = null;
  }

  static void _handleNewMessage(Map<String, dynamic> record, Ref ref) async {
    final senderId = record['sender_id']?.toString();
    final receiverId = record['receiver_id']?.toString();
    final channel = record['channel']?.toString();
    final content = record['content']?.toString() ?? 'New Message';
    final senderName = record['sender_name']?.toString() ?? 'Someone';

    debugPrint('GlobalChatNotificationService received message in channel: $channel from: $senderName');

    // Don't notify if the user is the sender
    if (senderId == _currentUserId) return;
    
    // Don't notify if it's a DM for someone else
    if (receiverId != null && receiverId != _currentUserId) return;

    // If it's a custom channel, ensure the user is a member
    if (channel != null && 
        channel != 'support-chat' && 
        channel != 'all-aroundtally' && 
        channel != 'dm') {
      try {
        final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(channel);
        final dynamic response;
        if (isUuid) {
          response = await Supabase.instance.client
              .from('custom_channels')
              .select('id, is_private, created_by, channel_members(user_id)')
              .eq('id', channel)
              .maybeSingle();
        } else {
          response = await Supabase.instance.client
              .from('custom_channels')
              .select('id, is_private, created_by, channel_members(user_id)')
              .eq('name', channel)
              .maybeSingle();
        }
            
        if (response != null) {
          final isPrivate = response['is_private'] as bool? ?? false;
          if (isPrivate) {
            final createdBy = response['created_by'];
            if (createdBy != _currentUserId) {
              final members = response['channel_members'] as List<dynamic>? ?? [];
              final isMember = members.any((m) => m['user_id'] == _currentUserId);
              if (!isMember) return;
            }
          }
        }
      } catch (e) {
        debugPrint('GlobalChatNotificationService channel check error: $e');
      }
    }

    // Play sound using a short-lived instance to prevent overlapping 'play' calls 
    // on a single instance which causes "Cannot add new events after calling close" on Web.
    final player = AudioPlayer();
    player
        .play(AssetSource('sounds/reminder.wav'))
        .timeout(const Duration(seconds: 2))
        .then((_) {
      // Dispose after a delay enough for the sound to finish
      Future.delayed(const Duration(seconds: 3), () => player.dispose());
    }).catchError((e) {
      player.dispose();
      if (e is TimeoutException) {
        // Browser autoplay policy might block audio before interaction.
        return;
      }
      debugPrint('Error playing notification sound: $e');
    });

    final msgPreview = content.startsWith('__CALL_') ? 'Started a call' : content;
    final title = 'New message from $senderName';

    // Show Push Notification
    if (kIsWeb) {
      showWebNotification(title, msgPreview);
    } else {
      await LocalNotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: msgPreview,
      );
    }
  }
}
