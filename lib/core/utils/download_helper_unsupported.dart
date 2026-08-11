import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

Future<void> downloadFileDirectly(String url, String fileName) async {
  try {
    final uri = Uri.parse(url);
    await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
  } catch (e) {
    debugPrint('Could not launch $url: $e');
  }
}
