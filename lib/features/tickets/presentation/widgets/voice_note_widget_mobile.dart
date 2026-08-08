import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceNoteWidget extends StatefulWidget {
  final String voiceUrl;
  final int duration;
  final bool isMe;

  const VoiceNoteWidget({
    super.key,
    required this.voiceUrl,
    required this.duration,
    this.isMe = false,
  });

  @override
  State<VoiceNoteWidget> createState() => _VoiceNoteWidgetState();
}

class _VoiceNoteWidgetState extends State<VoiceNoteWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
        _isLoading = false;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });

    _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() => _totalDuration = duration);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        setState(() => _isLoading = true);
        final isHttp = widget.voiceUrl.startsWith('http://') || widget.voiceUrl.startsWith('https://') || widget.voiceUrl.startsWith('blob:');
        final source = isHttp ? UrlSource(widget.voiceUrl) : DeviceFileSource(widget.voiceUrl);
        await _audioPlayer.play(source);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to play voice note: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = _totalDuration > Duration.zero
        ? _totalDuration
        : (widget.duration > 0 ? Duration(seconds: widget.duration) : Duration.zero);
    final durationLabel = _formatDuration(effectiveDuration);
    final positionLabel = _formatDuration(_position);
    final displayLabel = _isPlaying || _position > Duration.zero
        ? '$positionLabel / $durationLabel'
        : durationLabel;

    final colorScheme = Theme.of(context).colorScheme;
    final primaryTextColor = widget.isMe ? Colors.white : colorScheme.onSurface;
    final buttonBg = widget.isMe ? Colors.white : colorScheme.primary;
    final iconColor = widget.isMe ? colorScheme.primary : Colors.white;
    final totalMs = effectiveDuration.inMilliseconds;
    final val = totalMs > 0 ? (_position.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? colorScheme.primary.withValues(alpha: 0.95)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isMe ? Colors.white24 : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: buttonBg,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: _isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: iconColor,
                      size: 18,
                    ),
              onPressed: _isLoading ? null : _togglePlayPause,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: val,
                onChanged: (v) async {
                  if (totalMs > 0) {
                    await _audioPlayer.seek(
                      Duration(milliseconds: (v * totalMs).round()),
                    );
                  }
                },
                activeColor: widget.isMe ? Colors.white : colorScheme.primary,
                inactiveColor: widget.isMe
                    ? Colors.white.withValues(alpha: 0.3)
                    : colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            displayLabel,
            style: TextStyle(
              color: primaryTextColor.withValues(alpha: 0.9),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
