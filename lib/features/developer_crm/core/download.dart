import 'package:flutter/material.dart';
import '../../../../core/utils/download_helper.dart';
import 'crm_storage_service.dart';

/// Opens or initiates a file download for CRM attachments.
/// Builds a clean URL with `?download=filename` and uses [downloadFileDirectly]
/// to save the file properly on both Web and Native desktop platforms.
Future<void> openDownload(BuildContext context, String storagePathOrUrl, {String? filename}) async {
  final rawPath = storagePathOrUrl.trim();
  final effectiveName = (filename != null && filename.trim().isNotEmpty)
      ? filename.trim()
      : rawPath.split('/').last.split('?').first;
  try {
    if (rawPath.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is empty or invalid.')),
        );
      }
      return;
    }

    final effectiveUrl = CrmStorageService.getDownloadUrl(rawPath, filename: effectiveName);
    if (effectiveUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is empty or invalid.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $effectiveName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    final check = await CrmStorageService.checkDownloadable(
      effectiveUrl,
      storagePath: rawPath,
    );
    if (check.status == DownloadAvailabilityStatus.missing) {
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        final message = check.isLegacyPath
            ? 'File "$effectiveName" is an older attachment that has not been migrated to Supabase Storage.'
            : 'File "$effectiveName" is missing from storage (HTTP ${check.statusCode ?? 404}).';
        messenger.showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    await downloadFileDirectly(effectiveUrl, effectiveName, throwOnError: true);
  } catch (e) {
    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Could not download "$effectiveName": $e')),
      );
    }
  }
}
