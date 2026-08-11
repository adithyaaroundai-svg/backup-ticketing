import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'local_notification_service.dart';

class GlobalChatNotificationService {
  static RealtimeChannel? _subscription;
  static String? _currentUserId;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  
  static void init(String currentUserId, Ref ref) {
    if (_subscription != null) return;
    _currentUserId = currentUserId;

    // Ask for permissions initially on login
    LocalNotificationService.init();

    _subscription = Supabase.instance.client
        .channel('public:chat_messages_global')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            _handleNewMessage(payload.newRecord, ref);
          },
        )
        .subscribe();
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

    // Don't notify if the user is the sender
    if (senderId == _currentUserId) return;
    
    // Don't notify if it's a DM for someone else
    if (receiverId != null && receiverId != _currentUserId) return;

    // Play sound without awaiting to prevent browser autoplay block from freezing notifications
    _audioPlayer
        .play(AssetSource('sounds/reminder.wav'))
        .timeout(const Duration(seconds: 2))
        .catchError((e) {
      debugPrint('Error playing notification sound: $e');
    });

    // Show Push Notification on mobile
    if (!kIsWeb) {
      final msgPreview = content.startsWith('__CALL_') ? 'Started a call' : content;
      await LocalNotificationService.showNotification(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: 'New message from $senderName',
        body: msgPreview,
      );
    }
  }
}
