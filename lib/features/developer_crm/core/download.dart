import 'package:flutter/material.dart';
import '../../../../core/utils/download_helper.dart';
import 'crm_storage_service.dart';

/// Opens or initiates a file download for CRM attachments.
/// Builds a clean URL with `?download=filename` and uses [downloadFileDirectly]
/// to save the file properly on both Web and Native desktop platforms.
Future<void> openDownload(BuildContext context, String storagePathOrUrl, {String? filename}) async {
  try {
    final effectiveUrl = CrmStorageService.getDownloadUrl(storagePathOrUrl, filename: filename);
    if (effectiveUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is empty or invalid.')),
        );
      }
      return;
    }

    final effectiveName = filename ?? storagePathOrUrl.split('/').last.split('?').first;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $effectiveName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await downloadFileDirectly(effectiveUrl, effectiveName);
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not download file: $e')),
      );
    }
  }
}
