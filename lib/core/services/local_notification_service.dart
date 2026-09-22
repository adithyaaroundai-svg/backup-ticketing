
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'windows_notification_stub.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:ticketing_system/main.dart';
import 'package:go_router/go_router.dart';
import 'web_notification_helper.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  static WindowsNotification? _windowsNotification;
      
  static final Map<int, Timer> _scheduledTimers = {};
  static final Map<String, String> _windowsPayloads = {};
  
  static const MethodChannel _activationChannel = MethodChannel('crm_notification_activation');

  static Future<void> init() async {
    if (kIsWeb) {
      requestWebNotificationPermission();
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.ensureInitialized();
      _windowsNotification = WindowsNotification(applicationId: "AroundTally Ticketing");
      
      _activationChannel.setMethodCallHandler((call) async {
        if (call.method == 'notification_click') {
          final payload = call.arguments as String?;
          if (payload != null) {
            _handlePayload(payload);
          }
        }
      });
      
      try {
        await _activationChannel.invokeMethod('ready');
      } catch (e) {
        print("Failed to signal native ready: $e");
      }
      return;
    }

    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          _handlePayload(details.payload);
        },
      );
      
      // Request permissions for Android 13+
      try {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      } catch (e) {
        debugPrint('Failed to request notifications permission: $e');
      }
          
      // Request exact alarm permissions for Android 12+ (needed for zonedSchedule)
      try {
        await _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestExactAlarmsPermission();
      } catch (e) {
        debugPrint('Failed to request exact alarms permission: $e');
      }
    } catch (e) {
      debugPrint('Error initializing local notifications: $e');
    }
  }
  
  static void _handlePayload(String? payload) async {
    print('Notification clicked! Payload: $payload');
    if (payload == null || payload.isEmpty) return;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
        print('Checking window state...');
        bool isMinimized = await windowManager.isMinimized();
        if (isMinimized) {
          print('Window is minimized. Restoring...');
          await windowManager.restore();
        }
        bool isFocused = await windowManager.isFocused();
        if (!isFocused) {
          print('Window is not focused. Showing and focusing...');
          await windowManager.show();
          await windowManager.focus();
        }
        print('Window should now be visible and focused.');
      }
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        print('Context found, navigating to $payload');
        context.go(payload);
      } else {
        print('rootNavigatorKey.currentContext is null!');
      }
    } catch (e) {
      print('Error handling notification payload: $e');
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) {
      showWebNotification(title, body);
      return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      if (_windowsNotification != null) {
        String customXml = '''
<toast activationType="foreground" launch="${payload ?? ''}">
  <visual>
    <binding template="ToastGeneric">
      <text>$title</text>
      <text>$body</text>
    </binding>
  </visual>
</toast>
''';
        NotificationMessage message = NotificationMessage.fromCustomTemplate(id.toString(), group: 'AroundTally Ticketing');
        _windowsNotification?.showNotificationCustomTemplate(message, customXml);
      }
      return;
    }

    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'tallycare_high_importance_channel',
      'TallyCare High Importance Notifications',
      channelDescription: 'Channel for important alerts',
      importance: Importance.max,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails darwinNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: darwinNotificationDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  static Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    if (kIsWeb) return;
    if (scheduledDate.isBefore(DateTime.now())) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      final delay = scheduledDate.difference(DateTime.now());
      _scheduledTimers[id]?.cancel();
      _scheduledTimers[id] = Timer(delay, () {
        showNotification(id: id, title: title, body: body, payload: payload);
        _scheduledTimers.remove(id);
      });
      return;
    }

    try {
      await _notificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Reminders',
            channelDescription: 'Channel for reminder alerts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error scheduling local notification: $e');
    }
  }

  static Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      _scheduledTimers[id]?.cancel();
      _scheduledTimers.remove(id);
      return;
    }
    
    try {
      await _notificationsPlugin.cancel(id: id);
    } catch (e) {
      debugPrint('Error cancelling local notification: $e');
    }
  }
}
