class WindowsNotification {
  WindowsNotification({String? applicationId});
  Future<void> showNotificationCustomTemplate(dynamic message, String template) async {}
}

class NotificationMessage {
  static NotificationMessage fromCustomTemplate(String id, {String? group}) {
    return NotificationMessage();
  }
}

class WindowManagerStub {
  Future<void> ensureInitialized() async {}
  Future<bool> isMinimized() async => false;
  Future<void> restore() async {}
  Future<bool> isFocused() async => true;
  Future<void> show() async {}
  Future<void> focus() async {}
}

final windowManager = WindowManagerStub();
