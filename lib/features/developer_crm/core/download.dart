import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a file-download URL (built with the `?token=` fallback per
/// API.md) in a new tab/external app.
Future<void> openDownload(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the download link.')),
    );
  }
}
