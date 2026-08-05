import 'web_eval_stub.dart' if (dart.library.js) 'web_eval_web.dart';

/// Opens Zoho Cliq (India data center) to a specific user's DM in a new tab.
/// Uses cliq.zoho.in — confirmed from browser URL bar (India DC).
/// The zohoUserId MUST be the user's Zoho email (e.g. adithyaaroundai@gmail.com).
void launchZohoCliqUser(String zohoUserId) {
  final url = 'https://cliq.zoho.in/users/$zohoUserId';
  evalJs("window.open('$url', '_blank');");
}
