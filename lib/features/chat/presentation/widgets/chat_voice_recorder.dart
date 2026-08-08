import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import '../../../../core/design_system/theme/app_colors.dart';

enum RecorderState { idle, recording }

class ChatVoiceRecorder extends StatefulWidget {
  final ValueChanged<bool> onRecordingStateChanged;
  final void Function(String localPath, int durationSeconds) onRecordComplete;
  final bool disabled;

  const ChatVoiceRecorder({
    super.key,
    required this.onRecordingStateChanged,
    required this.onRecordComplete,
    this.disabled = false,
  });

  @override
  State<ChatVoiceRecorder> createState() => _ChatVoiceRecorderState();
}

class _ChatVoiceRecorderState extends State<ChatVoiceRecorder> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  RecorderState _state = RecorderState.idle;
  int _durationSeconds = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    if (widget.disabled || _state != RecorderState.idle) return;

    try {
      String? path;
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Microphone permission is required to record audio')),
            );
          }
          return;
        }
        final tempDir = await getTemporaryDirectory();
        path = '${tempDir.path}/chat_voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      } else {
        path = 'chat_voice_${DateTime.now().millisecondsSinceEpoch}.webm';
      }

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.opus,
          bitRate: 128000,
          sampleRate: 48000,
        ),
        path: path,
      );

      setState(() {
        _state = RecorderState.recording;
        _durationSeconds = 0;
      });
      widget.onRecordingStateChanged(true);

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _durationSeconds++);
        }
      });
    } catch (e) {
      debugPrint('Failed to start audio recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording({required bool cancel}) async {
    _timer?.cancel();
    final resultingPath = await _audioRecorder.stop();

    final recordedDuration = _durationSeconds <= 0 ? 1 : _durationSeconds;

    if (cancel) {
      if (resultingPath != null && !kIsWeb) {
        try {
          await File(resultingPath).delete();
        } catch (_) {}
      }
    } else if (resultingPath != null) {
      widget.onRecordComplete(resultingPath, recordedDuration);
    }

    setState(() {
      _state = RecorderState.idle;
      _durationSeconds = 0;
    });
    widget.onRecordingStateChanged(false);
  }

  @override
  Widget build(BuildContext context) {
    if (_state == RecorderState.recording) {
      return Expanded(
        child: Row(
          children: [
            const Icon(LucideIcons.mic, color: AppColors.error, size: 20),
            const SizedBox(width: 8),
            Text(
              _formatDuration(_durationSeconds),
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Recording audio...',
                style: TextStyle(color: AppColors.slate500, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(LucideIcons.trash2, color: AppColors.slate500, size: 18),
              tooltip: 'Cancel recording',
              onPressed: () => _stopRecording(cancel: true),
            ),
            IconButton(
              icon: const Icon(LucideIcons.send, color: AppColors.primary, size: 18),
              tooltip: 'Send voice note',
              onPressed: () => _stopRecording(cancel: false),
            ),
          ],
        ),
      );
    }

    return IgnorePointer(
      ignoring: widget.disabled,
      child: Opacity(
        opacity: widget.disabled ? 0.4 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(
              LucideIcons.mic,
              color: Colors.white,
              size: 18,
            ),
            onPressed: _startRecording,
            tooltip: 'Record voice note',
          ),
        ),
      ),
    );
  }
}
