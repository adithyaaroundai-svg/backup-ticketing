import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Top-level function for handling background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp();

  debugPrint("Handling a background message: ${message.messageId}");
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

  Future<void> init() async {
    if (_initialized) return;

    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions (especially for iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('User granted permission: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      
      // Update token to supabase on first initialization
      await saveTokenToSupabase();

      // Listen for token refresh
      _fcm.onTokenRefresh.listen((fcmToken) {
        _updateTokenInSupabase(fcmToken);
      }).onError((err) {
        debugPrint("Error getting FCM token: $err");
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // Note: If you want to show a heads up notification while the app is in the foreground,
          // you should use flutter_local_notifications plugin.
        }
      });
    }

    _initialized = true;
  }

  /// Fetches the current FCM token and sends it to Supabase using our RPC function
  Future<void> saveTokenToSupabase() async {
    try {
      // If we are not authenticated, we shouldn't save the token
      if (_supabase.auth.currentUser == null) return;

      if (Firebase.apps.isNotEmpty) {
        final fcmToken = await _fcm.getToken();
        if (fcmToken != null) {
          await _updateTokenInSupabase(fcmToken);
        }
      }
    } catch (e) {
      debugPrint("Failed to get/save FCM token: $e");
    }
  }

  Future<void> _updateTokenInSupabase(String token) async {
    try {
      if (_supabase.auth.currentUser == null) return;

      // Call the RPC function we created in the migration
      await _supabase.rpc('update_agent_fcm_token', params: {
        'new_token': token
      });
      debugPrint("FCM token successfully saved to Supabase.");
    } catch (e) {
      debugPrint("Error updating FCM token in Supabase: $e");
    }
  }

  Future<void> deleteToken() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await _fcm.deleteToken();
      }
      
      // Remove from supabase as well (pass null or empty string depending on db constraints)
      if (_supabase.auth.currentUser != null) {
        await _supabase.rpc('update_agent_fcm_token', params: {
          'new_token': null
        });
      }
    } catch (e) {
      debugPrint("Error deleting FCM token: $e");
    }
  }
}
