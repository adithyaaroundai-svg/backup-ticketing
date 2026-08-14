import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../../../../core/design_system/theme/app_colors.dart';

/// Modal dialog for playing video in full screen on 1-tap without downloading
class FullScreenVideoDialog extends StatefulWidget {
  final String videoUrl;
  final String fileName;
  final VoidCallback onDownload;

  const FullScreenVideoDialog({
    super.key,
    required this.videoUrl,
    required this.fileName,
    required this.onDownload,
  });

  static void show(
    BuildContext context, {
    required String videoUrl,
    required String fileName,
    required VoidCallback onDownload,
  }) {
    // On web: open the video directly in a new browser tab — the browser's
    // native video player handles it perfectly without CORS/codec issues.
    if (kIsWeb) {
      url_launcher.launchUrl(
        Uri.parse(videoUrl),
        mode: url_launcher.LaunchMode.externalApplication,
      );
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => FullScreenVideoDialog(
        videoUrl: videoUrl,
        fileName: fileName,
        onDownload: onDownload,
      ),
    );
  }

  @override
  State<FullScreenVideoDialog> createState() => _FullScreenVideoDialogState();
}

class _FullScreenVideoDialogState extends State<FullScreenVideoDialog> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        autoPlay: true,
        looping: false,
        allowFullScreen: true,
        showControls: true,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: _hasError
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, size: 48, color: Colors.white70),
                      const SizedBox(height: 12),
                      const Text(
                        'Failed to load video',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: widget.onDownload,
                        icon: const Icon(Icons.download),
                        label: const Text('Download Instead'),
                      )
                    ],
                  )
                : !_isInitialized
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          SizedBox(height: 16),
                          Text('Loading Video...', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        ],
                      )
                    : AspectRatio(
                        aspectRatio: _videoPlayerController.value.aspectRatio,
                        child: Chewie(controller: _chewieController!),
                      ),
          ),
          // Top Navigation / Actions Bar
          Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white, size: 26),
                  tooltip: 'Download Video',
                  onPressed: widget.onDownload,
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 26),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VideoMessageWidget extends StatelessWidget {
  final String videoUrl;
  final String fileName;
  final VoidCallback onDownload;

  const VideoMessageWidget({
    super.key,
    required this.videoUrl,
    required this.fileName,
    required this.onDownload,
  });

  void _openPlayerModal(BuildContext context) {
    FullScreenVideoDialog.show(
      context,
      videoUrl: videoUrl,
      fileName: fileName,
      onDownload: onDownload,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPlayerModal(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 250,
          height: 140,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            children: [
              // Center Play Button & Icon
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white38, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap to Play Video',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Top Right Download Button
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  icon: const Icon(Icons.download, color: Colors.white70, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(28, 28),
                  ),
                  onPressed: onDownload,
                  tooltip: 'Download Video',
                ),
              ),

              // Bottom Info Bar
              Positioned(
                left: 8,
                bottom: 8,
                right: 40,
                child: Row(
                  children: [
                    const Icon(Icons.videocam, size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


