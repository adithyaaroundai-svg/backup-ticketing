import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_notification_service.dart';

// Top-level function for handling background messages when app is closed
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint("Handling a background message: ${message.messageId}");

    // If message already has a notification payload, Android system handles display
    // Otherwise if it's data-only, or to ensure heads-up display:
    if (message.notification == null) {
      final title = message.data['title'] ?? 'TallyCare';
      final body = message.data['body'] ?? message.data['content'] ?? 'You have a new update';

      final plugin = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await plugin.initialize(
        settings: const InitializationSettings(android: androidInit),
      );

      const androidDetails = AndroidNotificationDetails(
        'tallycare_high_importance_channel',
        'TallyCare High Importance Notifications',
        channelDescription: 'Used for important chat and ticket alerts',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: true,
      );

      await plugin.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(android: androidDetails),
        payload: message.data['link'],
      );
    }
  } catch (e) {
    debugPrint("Error in _firebaseMessagingBackgroundHandler: $e");
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();

  factory PushNotificationService() {
    return _instance;
  }

  PushNotificationService._internal();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _initialized = false;

  static const String highImportanceChannelId = 'tallycare_high_importance_channel';

  Future<void> init() async {
    if (_initialized) return;

    try {
      // 1. Set background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Request permissions (especially for iOS & Android 13+)
      try {
        NotificationSettings settings = await _fcm.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        ).timeout(const Duration(seconds: 4));
        debugPrint('User granted push permission: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('PushNotificationService permission check timed out or failed: $e');
      }

      // 3. Create high importance Android notification channel
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        const AndroidNotificationChannel channel = AndroidNotificationChannel(
          highImportanceChannelId,
          'TallyCare High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        );

        final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(channel);
      }

      // 4. Update token to supabase
      unawaited(saveTokenToSupabase());

      // 5. Listen for token refresh
      _fcm.onTokenRefresh.listen((fcmToken) {
        _updateTokenInSupabase(fcmToken);
      }).onError((err) {
        debugPrint("Error getting FCM token on refresh: $err");
      });

      // 6. Handle foreground messages by popping a local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground: ${message.messageId}');
        final notification = message.notification;
        if (notification != null) {
          LocalNotificationService.showNotification(
            id: message.hashCode,
            title: notification.title ?? 'TallyCare Notification',
            body: notification.body ?? '',
            payload: message.data['link'],
          );
        }
      });
    } catch (e) {
      debugPrint("PushNotificationService.init error: $e");
    }

    _initialized = true;
  }

  /// Fetches the current FCM token and sends it to Supabase for the active agent
  Future<void> saveTokenToSupabase([String? agentId]) async {
    try {
      String? targetAgentId = agentId;
      if (targetAgentId == null) {
        // Retrieve agent ID from SharedPreferences if not passed
        final prefs = await SharedPreferences.getInstance();
        final rawAgent = prefs.getString('auth.agent');
        if (rawAgent != null && rawAgent.contains('"id"')) {
          final match = RegExp(r'"id"\s*:\s*"([^"]+)"').firstMatch(rawAgent);
          if (match != null) {
            targetAgentId = match.group(1);
          }
        }
      }

      if (targetAgentId == null || targetAgentId.isEmpty) {
        debugPrint("PushNotificationService: No agent ID available yet to associate FCM token.");
        return;
      }

      if (Firebase.apps.isNotEmpty) {
        final fcmToken = await _fcm.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );
        if (fcmToken != null) {
          await _updateTokenInSupabase(fcmToken, targetAgentId).timeout(
            const Duration(seconds: 5),
            onTimeout: () => null,
          );
        }
      }
    } catch (e) {
      debugPrint("Failed to get/save FCM token: $e");
    }
  }

  Future<void> _updateTokenInSupabase(String token, [String? agentId]) async {
    try {
      String? targetAgentId = agentId;
      if (targetAgentId == null) {
        final prefs = await SharedPreferences.getInstance();
        final rawAgent = prefs.getString('auth.agent');
        if (rawAgent != null) {
          final match = RegExp(r'"id"\s*:\s*"([^"]+)"').firstMatch(rawAgent);
          if (match != null) targetAgentId = match.group(1);
        }
      }

      if (targetAgentId == null) return;

      // 1. Try RPC function with SECURITY DEFINER
      try {
        await _supabase.rpc('set_agent_fcm_token', params: {
          'p_agent_id': targetAgentId,
          'p_token': token,
        });
        debugPrint("FCM token successfully registered via RPC for agent $targetAgentId");
        return;
      } catch (rpcErr) {
        debugPrint("RPC set_agent_fcm_token failed, trying direct update: $rpcErr");
      }

      // 2. Fallback to direct table update
      await _supabase
          .from('agents')
          .update({'fcm_token': token})
          .eq('id', targetAgentId);

      debugPrint("FCM token successfully registered in Supabase for agent $targetAgentId");
    } catch (e) {
      debugPrint("Error updating FCM token in Supabase: $e");
    }
  }

  Future<void> deleteToken([String? agentId]) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await _fcm.deleteToken();
      }
      
      if (agentId != null) {
        await _supabase
            .from('agents')
            .update({'fcm_token': null})
            .eq('id', agentId);
      }
    } catch (e) {
      debugPrint("Error deleting FCM token: $e");
    }
  }
}
