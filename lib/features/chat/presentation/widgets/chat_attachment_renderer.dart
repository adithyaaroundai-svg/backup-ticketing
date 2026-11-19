import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../../core/design_system/theme/app_colors.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/chat_provider.dart';
import '../../../tickets/presentation/widgets/voice_note_widget.dart';
import '../../../../core/utils/download_helper.dart';
import 'video_message_widget.dart';
import '../../../../core/utils/storage_utils.dart';

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

  /// Tracks precached URLs so images are only scheduled once, eliminating scroll stutter.
  static final Set<String> _precachedUrls = {};

  const ChatAttachmentRenderer({
    super.key,
    required this.message,
    this.isMe = false,
  });

  Future<void> _downloadFile(String url, String fileName) async {
    await downloadFileDirectly(url, fileName);
  }

  /// Returns the best display/download filename.
  /// Prefers message.fileName, then falls back to extracting from the URL path,
  /// then appends the extension from fileType if still missing.
  String _resolveFileName(String? fileName, String? fileType, String? url) {
    // 1. Use provided filename if it looks valid (has extension)
    if (fileName != null && fileName.trim().isNotEmpty && fileName.contains('.')) {
      return fileName.trim();
    }

    // 2. Extract from URL
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        final segments = uri.pathSegments;
        if (segments.isNotEmpty) {
          // URL path often has timestamp_originalname.ext — decode %20 etc.
          final rawName = Uri.decodeComponent(segments.last);
          if (rawName.isNotEmpty && rawName.contains('.')) {
            return rawName;
          }
        }
      } catch (_) {}
    }

    // 3. Use provided filename + append fileType extension
    if (fileName != null && fileName.trim().isNotEmpty && fileType != null) {
      return '${fileName.trim()}.${fileType.toLowerCase()}';
    }

    // 4. Generic fallback with extension
    final ext = fileType != null && fileType.isNotEmpty ? '.${fileType.toLowerCase()}' : '';
    return 'file$ext';
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
                              onPressed: () {
                                if (url.startsWith('temp://')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('File is currently uploading, please wait...')),
                                  );
                                  return;
                                }
                                _downloadFile(url, _resolveFileName(fileName, null, url));
                              },
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
                              child: ChatImageMemoryCache.contains(url)
                                  ? Image.memory(
                                      ChatImageMemoryCache.get(url)!,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    )
                                  : (!kIsWeb && !url.startsWith('http') && !url.startsWith('temp://') && File(url).existsSync())
                                      ? Image.file(
                                          File(url),
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        )
                                      : url.startsWith('http')
                                          ? Image.network(
                                              url,
                                              fit: BoxFit.contain,
                                              gaplessPlayback: true,
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
                                            )
                                          : const Center(
                                              child: Icon(Icons.image, size: 48, color: Colors.white38),
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
    final timeStr = DateFormat('h:mm a').format(message.createdAt.toLocal());
    final readBy = ReadReceiptsTracker.getReadBy(message.id);
    final isRead = message.receiverId != null && message.receiverId!.isNotEmpty
        ? readBy.contains(message.receiverId!.trim().toLowerCase())
        : readBy.any((id) => id != message.senderId.trim().toLowerCase());

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
            timestamp: timeStr,
          ),
        );
        break;
      case ChatAttachmentType.gif:
      case ChatAttachmentType.image:
        final cachedBytes = ChatImageMemoryCache.get(message.fileUrl!);
        final isGif = type == ChatAttachmentType.gif;

        // Schedule background precache of full image at most once per remote URL
        if (message.fileUrl != null &&
            message.fileUrl!.startsWith('http') &&
            !ChatImageMemoryCache.contains(message.fileUrl!) &&
            _precachedUrls.add(message.fileUrl!)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              precacheImage(NetworkImage(message.fileUrl!), context).catchError((_) {});
            }
          });
        }

        Widget imageWidget;
        if (cachedBytes != null) {
          imageWidget = Image.memory(
            cachedBytes,
            width: 200,
            fit: BoxFit.cover,
            cacheWidth: isGif ? null : 600,
            gaplessPlayback: true,
          );
        } else if (!kIsWeb && message.fileUrl != null && !message.fileUrl!.startsWith('http') && !message.fileUrl!.startsWith('temp://') && File(message.fileUrl!).existsSync()) {
          imageWidget = Image.file(
            File(message.fileUrl!),
            width: 200,
            fit: BoxFit.cover,
            cacheWidth: isGif ? null : 600,
            gaplessPlayback: true,
          );
        } else if (message.fileUrl!.startsWith('http')) {
          imageWidget = Image.network(
            message.fileUrl!,
            width: 200,
            fit: BoxFit.cover,
            cacheWidth: isGif ? null : 600,
            gaplessPlayback: true,
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
          );
        } else {
          imageWidget = Container(
            width: 200,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.image, size: 36, color: AppColors.slate400),
            ),
          );
        }

        contentWidget = Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: GestureDetector(
            onTap: () => _showFullScreenImage(context, message.fileUrl!, message.fileName ?? 'image'),
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageWidget,
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 3),
                          Icon(
                            isRead ? LucideIcons.checkCheck : LucideIcons.check,
                            size: 12,
                            color: isRead ? const Color(0xFF60A5FA) : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
      case ChatAttachmentType.video:
        if (message.fileUrl!.startsWith('temp://')) {
          final displayName = _resolveFileName(message.fileName, message.fileType, message.fileUrl);
          contentWidget = _FileAttachmentCard(
            displayName: displayName,
            fileType: 'video',
            fileUrl: message.fileUrl!,
            onDownload: () async {},
            timestamp: timeStr,
            isMe: isMe,
            isRead: isRead,
          );
        } else {
          contentWidget = Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: VideoMessageWidget(
              videoUrl: message.fileUrl!,
              fileName: _resolveFileName(message.fileName, message.fileType, message.fileUrl),
              onDownload: () => _downloadFile(message.fileUrl!, _resolveFileName(message.fileName, message.fileType, message.fileUrl)),
              timestamp: timeStr,
              isMe: isMe,
              isRead: isRead,
            ),
          );
        }
        break;
      case ChatAttachmentType.document:
      case ChatAttachmentType.file:
      case ChatAttachmentType.none:
        // Derive best available filename — prefer message.fileName, fallback to extracting from URL
        final displayName = _resolveFileName(message.fileName, message.fileType, message.fileUrl);
        contentWidget = _FileAttachmentCard(
          displayName: displayName,
          fileType: message.fileType,
          fileUrl: message.fileUrl!,
          onDownload: () => _downloadFile(message.fileUrl!, displayName),
          timestamp: timeStr,
          isMe: isMe,
          isRead: isRead,
        );
        break;
    }

    if (uploadState != null) {
      if (uploadState.status == AttachmentUploadStatus.uploading) {
        final progress = uploadState.progress.clamp(0.0, 1.0);
        final pct = (progress * 100).toInt();
        final displayName = _resolveFileName(message.fileName, message.fileType, message.fileUrl);
        final isDrive = (message.fileType == 'gdrive') ||
            (message.fileUrl?.contains('drive.google.com') ?? false) ||
            displayName.toLowerCase().endsWith('.zip') ||
            displayName.toLowerCase().endsWith('.7z') ||
            displayName.toLowerCase().endsWith('.rar');

        return Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
          decoration: BoxDecoration(
            color: context.isDarkMode
                ? context.adaptiveSlate800.withValues(alpha: 0.8)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF1A73E8).withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cloud_upload_rounded,
                      color: Color(0xFF1A73E8),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: context.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isDrive
                              ? 'Uploading to Google Drive...'
                              : 'Uploading file...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1A73E8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pct%',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A73E8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Live Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 6,
                  backgroundColor: context.isDarkMode
                      ? context.adaptiveSlate700
                      : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A73E8)),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$pct% complete',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: context.adaptiveSlate400,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded, size: 11, color: Color(0xFF16A34A)),
                      const SizedBox(width: 3),
                      const Text(
                        'Drive Sync',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: context.adaptiveSlate400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      } else if (uploadState.status == AttachmentUploadStatus.failed) {
        final errorText = uploadState.error ?? 'Upload failed';
        String displayError = errorText;
        if (displayError.contains('DetailedApiRequestError') ||
            displayError.contains('401') ||
            displayError.toLowerCase().contains('invalid authentication') ||
            displayError.toLowerCase().contains('oauth 2')) {
          displayError = 'Google Drive session expired. Please re-connect Company Google Drive in Settings -> Google Drive.';
        }
        final isCleanMessage = displayError.toLowerCase().contains('exceed') ||
            displayError.toLowerCase().contains('google drive') ||
            displayError.toLowerCase().contains('settings');
        final bannerText = isCleanMessage ? displayError : 'Upload failed: $displayError';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            contentWidget,
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Tooltip(
                      message: displayError,
                      child: Text(
                        bannerText,
                        style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (uploadState.onRetry != null) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: uploadState.onRetry,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text('Retry', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const Text('·', style: TextStyle(color: AppColors.slate400)),
                  ],
                  const SizedBox(width: 4),
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

class _FileAttachmentCard extends StatefulWidget {
  final String displayName;
  final String? fileType;
  final String fileUrl;
  final Future<void> Function() onDownload;
  final String? timestamp;
  final bool isMe;
  final bool isRead;

  const _FileAttachmentCard({
    required this.displayName,
    required this.fileType,
    required this.fileUrl,
    required this.onDownload,
    this.timestamp,
    this.isMe = false,
    this.isRead = false,
  });

  @override
  State<_FileAttachmentCard> createState() => _FileAttachmentCardState();
}

class _FileAttachmentCardState extends State<_FileAttachmentCard> with SingleTickerProviderStateMixin {
  bool _isDownloading = false;
  bool _isHovering = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDownload() async {
    if (_isDownloading) return;

    if (widget.fileUrl.startsWith('temp://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File is currently uploading, please wait...'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isDownloading = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Download started...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await widget.onDownload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download completed'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return Icons.insert_drive_file;
    final type = fileType.toLowerCase();
    if (type == 'gdrive') return Icons.cloud_done;
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(type)) return Icons.image;
    if (['mp4', 'mov', 'avi'].contains(type)) return Icons.videocam;
    if (['mp3', 'wav', 'webm', 'm4a', 'opus', 'voice'].contains(type)) return Icons.audio_file;
    if (['doc', 'docx'].contains(type)) return Icons.description;
    if (['xls', 'xlsx'].contains(type)) return Icons.table_chart;
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(type)) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  @override
  Widget build(BuildContext context) {
    final isGoogleDrive = widget.fileType == 'gdrive' ||
        widget.fileUrl.contains('drive.google.com') ||
        widget.fileUrl.contains('docs.google.com');

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? context.adaptiveSlate800.withValues(alpha: 0.6)
            : (isGoogleDrive ? const Color(0xFFF8FAFC) : Colors.grey.shade50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isGoogleDrive
              ? const Color(0xFF4285F4).withValues(alpha: 0.3)
              : (context.isDarkMode ? context.adaptiveSlate700 : Colors.grey.shade200),
          width: isGoogleDrive ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isGoogleDrive
                      ? const Color(0xFF4285F4).withValues(alpha: 0.12)
                      : (context.isDarkMode ? context.adaptiveSlate700 : AppColors.primary.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isGoogleDrive ? Icons.cloud_done_rounded : _getFileIcon(widget.fileType),
                  size: 24,
                  color: isGoogleDrive
                      ? const Color(0xFF1A73E8)
                      : (context.isDarkMode ? Colors.white70 : AppColors.primary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: context.isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (isGoogleDrive) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF34A853).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Drive',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E8E3E),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isDownloading
                          ? (isGoogleDrive ? 'Opening Google Drive...' : 'Downloading...')
                          : (isGoogleDrive ? 'Google Drive · Click to open' : 'Click to download'),
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDownloading
                            ? AppColors.primary
                            : (isGoogleDrive ? const Color(0xFF1A73E8) : context.adaptiveSlate400),
                        fontWeight: (_isDownloading || isGoogleDrive) ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              MouseRegion(
                onEnter: (_) => setState(() => _isHovering = true),
                onExit: (_) => setState(() => _isHovering = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTapDown: (_) => _controller.forward(),
                  onTapUp: (_) => _controller.reverse(),
                  onTapCancel: () => _controller.reverse(),
                  onTap: _handleDownload,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? (_isHovering ? context.adaptiveSlate600 : context.adaptiveSlate700)
                            : (_isHovering
                                ? (isGoogleDrive ? const Color(0xFF4285F4).withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.1))
                                : Colors.white),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!context.isDarkMode && !_isHovering)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isGoogleDrive ? LucideIcons.externalLink : LucideIcons.download,
                              size: 16,
                              color: _isHovering
                                  ? (isGoogleDrive ? const Color(0xFF1A73E8) : AppColors.primary)
                                  : (context.isDarkMode
                                      ? Colors.white70
                                      : (isGoogleDrive ? const Color(0xFF1A73E8) : AppColors.slate600)),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36), // Buffer for the drop-down arrow
            ],
          ),
          if (widget.timestamp != null && widget.timestamp!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Text(
                  widget.timestamp!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: widget.isMe
                        ? (context.isDarkMode ? Colors.white60 : AppColors.primary.withValues(alpha: 0.6))
                        : (context.isDarkMode ? Colors.white54 : AppColors.slate400),
                  ),
                ),
                if (widget.isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    widget.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                    size: 13,
                    color: widget.isRead
                        ? (context.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                        : (context.isDarkMode ? Colors.white60 : AppColors.primary.withValues(alpha: 0.6)),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
