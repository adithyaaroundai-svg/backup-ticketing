import 'dart:html' as html;
import 'package:flutter/foundation.dart';

void requestWebNotificationPermission() {
  if (!html.Notification.supported) {
    debugPrint('Web notifications are not supported in this browser.');
    return;
  }

  void prompt() {
    if (html.Notification.permission == 'default') {
      try {
        html.Notification.requestPermission().then((perm) {
          debugPrint('Web Notification permission response: $perm');
        });
      } catch (e) {
        debugPrint('Error requesting notification permission: $e');
      }
    }
  }

  // 1. Try immediate prompt
  prompt();

  // 2. Attach global user-interaction listeners (click, keypress, touch)
  // This guarantees Edge and Chrome will display the full permission popup
  // the moment the user clicks or types anywhere in the CRM application.
  html.window.onClick.listen((_) => prompt());
  html.window.onKeyDown.listen((_) => prompt());
  html.window.onTouchStart.listen((_) => prompt());
}

void showWebNotification(String title, String body) {
  if (!html.Notification.supported) {
    debugPrint('showWebNotification: Notifications not supported.');
    return;
  }

  final permission = html.Notification.permission;
  debugPrint('showWebNotification: Current permission = $permission, Title = $title');

  if (permission == 'granted') {
    try {
      final notification = html.Notification(
        title,
        body: body,
        icon: 'favicon.png',
        tag: 'crm_notif_${DateTime.now().millisecondsSinceEpoch}',
      );
      notification.onClick.listen((_) {
        notification.close();
      });
      debugPrint('showWebNotification: Notification created successfully.');
    } catch (e) {
      debugPrint('showWebNotification: Primary constructor failed ($e), trying fallback...');
      try {
        html.Notification(title, body: body);
      } catch (e2) {
        debugPrint('showWebNotification: Fallback failed: $e2');
      }
    }
  } else if (permission == 'default') {
    html.Notification.requestPermission().then((perm) {
      debugPrint('showWebNotification requested permission, result: $perm');
      if (perm == 'granted') {
        try {
          html.Notification(title, body: body);
        } catch (_) {}
      }
    });
  }
}
