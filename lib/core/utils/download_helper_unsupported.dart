import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

Future<void> downloadFileDirectly(
  String url,
  String fileName, {
  bool throwOnError = false,
}) async {
  try {
    final uri = Uri.parse(url);
    final launched = await url_launcher.launchUrl(
      uri,
      mode: url_launcher.LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('Could not open download URL in browser.');
    }
  } catch (e) {
    debugPrint('Could not launch $url: $e');
    if (throwOnError) rethrow;
  }
}
