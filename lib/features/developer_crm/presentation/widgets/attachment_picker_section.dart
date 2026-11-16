import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/crm_storage_service.dart';

/// Picks one or more files using memory-safe streaming on Web (`withReadStream`)
/// and lazy path access on desktop/mobile (`withData: false`).
Future<List<PlatformFile>> pickCrmUploadFiles({bool allowMultiple = true}) async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: allowMultiple,
    withData: false,
    withReadStream: kIsWeb,
  );
  if (result == null) return const [];
  return result.files;
}

/// Returns true when any selected file is 0 bytes / unreadable.
bool hasInvalidCrmAttachments(Iterable<PlatformFile> files) =>
    files.any((f) => f.size <= 0);

/// Formats a batch progress label such as `"Uploading 2/3 (45%): archive.zip"`.
String formatCrmUploadProgressLabel(
  int currentIndex,
  int totalCount,
  double fileProgress,
  String filename,
) {
  final pct = (fileProgress.clamp(0.0, 1.0) * 100).round();
  if (totalCount <= 1) {
    return 'Uploading $filename ($pct%)...';
  }
  return 'Uploading ${currentIndex + 1}/$totalCount ($pct%): $filename';
}

/// Maps a filename extension to a recognizable document/media icon.
IconData crmAttachmentIcon(String filename) {
  final lower = filename.trim().toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot >= 0 && dot < lower.length - 1 ? lower.substring(dot + 1) : '';
  switch (ext) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
    case 'svg':
      return Icons.image_rounded;
    case 'zip':
    case 'rar':
    case '7z':
    case 'tar':
    case 'gz':
      return Icons.folder_zip_rounded;
    case 'tcp':
    case 'txt':
    case 'json':
    case 'xml':
    case 'sql':
    case 'dart':
    case 'js':
    case 'ts':
    case 'tdl':
      return Icons.code_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

/// Displays newly selected files with sizes, size-limit/empty warnings,
/// per-file removal, and an optional Clear All action.
class PendingAttachmentList extends StatelessWidget {
  final List<PlatformFile> files;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onClearAll;
  final bool enabled;
  final EdgeInsetsGeometry padding;

  const PendingAttachmentList({
    super.key,
    required this.files,
    this.onRemove,
    this.onClearAll,
    this.enabled = true,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final warningColor =
        theme.brightness == Brightness.dark ? Colors.orange.shade300 : Colors.orange.shade800;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (files.length > 1 && onClearAll != null)
            Row(
              children: [
                Text(
                  '${files.length} files selected',
                  style: theme.textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Spacer(),
                TextButton(
                  onPressed: enabled ? onClearAll : null,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Clear all'),
                ),
              ],
            ),
          for (var i = 0; i < files.length; i++) _buildRow(context, i, cs, theme, warningColor),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    int index,
    ColorScheme cs,
    ThemeData theme,
    Color warningColor,
  ) {
    final file = files[index];
    final isEmpty = file.size <= 0;
    final overLimit = file.size > CrmStorageService.currentKnownMaxUploadBytes;
    final iconColor = isEmpty
        ? cs.error
        : overLimit
            ? warningColor
            : cs.primary;
    final subtitleText = isEmpty
        ? '0 B — Empty or unreadable file cannot be uploaded'
        : overLimit
            ? '${CrmStorageService.formatFileSize(file.size)} — Exceeds 50 MB limit unless Supabase bucket limit is raised'
            : CrmStorageService.formatFileSize(file.size);
    final subtitleColor = isEmpty
        ? cs.error
        : overLimit
            ? warningColor
            : cs.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEmpty
              ? cs.error.withValues(alpha: 0.45)
              : overLimit
                  ? warningColor.withValues(alpha: 0.55)
                  : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(crmAttachmentIcon(file.name), size: 18, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitleText,
                  style: theme.textTheme.labelSmall?.copyWith(color: subtitleColor),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Remove file',
              visualDensity: VisualDensity.compact,
              onPressed: enabled ? () => onRemove!(index) : null,
            ),
        ],
      ),
    );
  }
}

/// Compact inline progress indicator shown while attachments are uploading.
class CrmUploadProgressBanner extends StatelessWidget {
  final String label;
  final double? progress;

  const CrmUploadProgressBanner({
    super.key,
    required this.label,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress),
          ),
        ],
      ),
    );
  }
}

