import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../../core/design_system/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../tickets/presentation/widgets/voice_note_widget.dart';
import '../../../../core/utils/download_helper.dart';
import 'video_message_widget.dart';

enum ChatAttachmentType {
  none,
  voice,
  gif,
  image,
  video,
  audio,
  document,
  file,
}

class ChatAttachmentRenderer extends ConsumerWidget {
  final ChatMessage message;
  final bool isMe;

  const ChatAttachmentRenderer({
    super.key,
    required this.message,
    this.isMe = false,
  });

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;
    final type = fileType.toLowerCase();
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(type)) return Icons.image;
    if (['mp4', 'mov', 'avi'].contains(type)) return Icons.videocam;
    if (['mp3', 'wav', 'webm', 'm4a', 'opus', 'voice'].contains(type)) return Icons.audio_file;
    if (['doc', 'docx'].contains(type)) return Icons.description;
    if (['xls', 'xlsx'].contains(type)) return Icons.table_chart;
    if (['zip', 'rar'].contains(type)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  Future<void> _downloadFile(String url, String fileName) async {
    await downloadFileDirectly(url, fileName);
  }

  ChatAttachmentType _getType(String? fileType, String? fileName) {
    if (fileType == null && fileName == null) return ChatAttachmentType.none;
    final type = (fileType ?? '').toLowerCase();
    final name = (fileName ?? '').toLowerCase();

    if (type == 'voice' || name.startsWith('voice_')) {
      return ChatAttachmentType.voice;
    }
    if (type == 'gif' || name.endsWith('.gif')) return ChatAttachmentType.gif;
    if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(type) ||
        name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp')) {
      return ChatAttachmentType.image;
    }
    if (['mp3', 'wav', 'aac', 'flac', 'webm', 'opus', 'm4a'].contains(type)) return ChatAttachmentType.audio;
    if (['mp4', 'mov', 'avi', 'mkv'].contains(type)) return ChatAttachmentType.video;
    if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt'].contains(type)) return ChatAttachmentType.document;
    return ChatAttachmentType.file;
  }

  int _parseDuration(String? fileName) {
    if (fileName == null) return 0;
    if (fileName.startsWith('voice_')) {
      final parts = fileName.split('_');
      if (parts.length >= 2) {
        final duration = int.tryParse(parts[1]);
        if (duration != null) return duration;
      }
    }
    return 0;
  }

  void _showFullScreenImage(BuildContext context, String url, String fileName) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxW = screenSize.width < 700
        ? screenSize.width * 0.96
        : (screenSize.width * 0.90).clamp(600.0, 1280.0);
    final maxH = screenSize.height < 700
        ? screenSize.height * 0.94
        : (screenSize.height * 0.88).clamp(600.0, 920.0);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(ctx).pop(),
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent click inside dialog from closing
                child: Container(
                  width: maxW,
                  height: maxH,
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Header bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.image,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.download,
                                color: Colors.white70,
                                size: 20,
                              ),
                              tooltip: 'Download',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => _downloadFile(url, fileName),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white70,
                                size: 20,
                              ),
                              tooltip: 'Close',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),
                      ),
                      // Image body
                      Expanded(
                        child: Container(
                          color: const Color(0xFF090D16),
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: InteractiveViewer(
                              panEnabled: true,
                              minScale: 0.5,
                              maxScale: 4.0,
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder: (_, child, progress) =>
                                    progress == null
                                        ? child
                                        : const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white70,
                                              ),
                                            ),
                                          ),
                                errorBuilder: (_, __, ___) => const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        color: Colors.white38,
                                        size: 48,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Failed to load image',
                                        style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (message.fileUrl == null || message.fileUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    final uploadState = ref.watch(attachmentUploadStateProvider)[message.id];
    final type = _getType(message.fileType, message.fileName);

    Widget contentWidget;
    switch (type) {
      case ChatAttachmentType.voice:
      case ChatAttachmentType.audio:
        final duration = _parseDuration(message.fileName);
        contentWidget = Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: VoiceNoteWidget(
            voiceUrl: message.fileUrl!,
            duration: duration,
            isMe: isMe,
          ),
        );
        break;
      case ChatAttachmentType.gif:
      case ChatAttachmentType.image:
        contentWidget = Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, message.fileUrl!, message.fileName ?? 'image'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                message.fileUrl!,
                width: 200,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        width: 200,
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      ),
                errorBuilder: (_, __, ___) => Container(
                  width: 200,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_not_supported, size: 32, color: AppColors.slate400),
                  ),
                ),
              ),
            ),
          ),
        );
        break;
      case ChatAttachmentType.video:
        contentWidget = Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: VideoMessageWidget(
            videoUrl: message.fileUrl!,
            fileName: message.fileName ?? 'video',
            onDownload: () => _downloadFile(message.fileUrl!, message.fileName ?? 'video'),
          ),
        );
        break;
      case ChatAttachmentType.document:
      case ChatAttachmentType.file:
      case ChatAttachmentType.none:
      default:
        contentWidget = GestureDetector(
          onTap: () => _downloadFile(message.fileUrl!, message.fileName ?? 'file'),
          child: Container(
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.isDarkMode ? context.adaptiveSlate800 : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: context.isDarkMode ? context.adaptiveSlate700 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_getFileIcon(message.fileType), size: 16, color: context.adaptiveSlate400),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    message.fileName ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.download, size: 14, color: context.adaptiveSlate400),
              ],
            ),
          ),
        );
        break;
    }

    if (uploadState != null) {
      if (uploadState.status == AttachmentUploadStatus.uploading) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: 0.6, child: contentWidget),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 8),
                  Text('Uploading...', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      } else if (uploadState.status == AttachmentUploadStatus.failed) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            contentWidget,
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  const Text('Upload failed', style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: uploadState.onRetry,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const Text('·', style: TextStyle(color: AppColors.slate400)),
                  InkWell(
                    onTap: () {
                      ref.read(chatControllerProvider.notifier).deleteMessage(
                        message.id,
                        receiverId: message.receiverId,
                        channel: message.channel,
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('Delete', style: TextStyle(color: AppColors.slate500, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }
    }

    return contentWidget;
  }
}
