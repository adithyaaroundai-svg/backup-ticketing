import 'dart:html' as html;

void requestWebNotificationPermission() {
  if (html.Notification.supported) {
    if (html.Notification.permission != 'granted' && html.Notification.permission != 'denied') {
      html.Notification.requestPermission();
    }
  }
}

void showWebNotification(String title, String body) {
  if (html.Notification.supported && html.Notification.permission == 'granted') {
    final notification = html.Notification(title, body: body);
    notification.onClick.listen((_) {
      notification.close();
    });
  }
}
