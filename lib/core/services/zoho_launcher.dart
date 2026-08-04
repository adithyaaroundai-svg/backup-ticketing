import 'web_eval_stub.dart' if (dart.library.js) 'web_eval_web.dart';

/// Launches Zoho Cliq desktop app by navigating to the zohocliqapp:// protocol.
/// Uses window.location.href via JS eval — the only reliable way to trigger
/// a custom protocol handler from a Flutter web app running on localhost
/// without getting blocked by Chrome's security prompt.
void launchZohoCliqUser(String zohoUserId) {
  final url = 'zohocliqapp://users/$zohoUserId';
  // Setting window.location.href triggers the OS protocol handler directly.
  // This avoids the "This site is trying to open..." Chrome security dialog
  // that blocks url_launcher from working on localhost origins.
  evalJs("window.location.href = '$url';");
}
