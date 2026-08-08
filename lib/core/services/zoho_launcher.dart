import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'web_eval_stub.dart' if (dart.library.js) 'web_eval_web.dart';

/// Opens Zoho Cliq (India data center) to a specific user's DM.
/// Uses cliq.zoho.in — confirmed from browser URL bar (India DC).
/// The zohoUserId MUST be the user's Zoho email (e.g. adithyaaroundai@gmail.com).
Future<void> launchZohoCliqUser(String zohoUserId) async {
  final url = 'https://cliq.zoho.in/users/$zohoUserId';
  
  if (kIsWeb) {
    evalJs("window.open('$url', '_blank');");
  } else {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('Could not launch Zoho Cliq URL: $url');
    }
  }
}
