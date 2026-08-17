import 'dart:html' as html;

void requestWebNotificationPermission() {
  if (html.Notification.supported) {
    if (html.Notification.permission != 'granted' && html.Notification.permission != 'denied') {
      html.Notification.requestPermission();
    }
  }
}

void showWebNotification(String title, String body) {
  if (!html.Notification.supported) return;

  if (html.Notification.permission == 'granted') {
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
    } catch (_) {
      try {
        html.Notification(title, body: body);
      } catch (_) {}
    }
  } else if (html.Notification.permission != 'denied') {
    html.Notification.requestPermission().then((perm) {
      if (perm == 'granted') {
        try {
          html.Notification(
            title,
            body: body,
            icon: 'favicon.png',
            tag: 'crm_notif_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (_) {}
      }
    });
  }
}
