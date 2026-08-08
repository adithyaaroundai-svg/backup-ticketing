import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

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
  late final AudioPlayer _player;
  bool _unsupported = false;
  bool _isPlaying = false;
  String? _errorMessage;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _position = Duration.zero);
    });
    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _totalDuration = dur);
    });
    _loadSource();
  }

  Future<void> _loadSource() async {
    try {
      await _player.setSourceUrl(widget.voiceUrl);
      if (widget.duration > 0) {
        _totalDuration = Duration(seconds: widget.duration);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unsupported = true;
          _errorMessage = 'Unable to play this voice note.';
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_unsupported) return;
    try {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _unsupported = true;
          _errorMessage = 'Failed to play voice note.';
          _isPlaying = false;
        });
      }
    }
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _progressValue {
    final totalMs = _totalDuration.inMilliseconds;
    if (totalMs == 0) return 0;
    return (_position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveDuration = _totalDuration > Duration.zero
        ? _totalDuration
        : (widget.duration > 0 ? Duration(seconds: widget.duration) : Duration.zero);
    final durationLabel = _format(effectiveDuration);
    final positionLabel = _format(_position);
    final displayLabel = _isPlaying || _position > Duration.zero
        ? '$positionLabel / $durationLabel'
        : durationLabel;

    final colorScheme = Theme.of(context).colorScheme;
    final primaryTextColor = widget.isMe ? Colors.white : colorScheme.onSurface;
    final buttonBg = widget.isMe ? Colors.white : colorScheme.primary;
    final iconColor = widget.isMe ? colorScheme.primary : Colors.white;

    return Container(
      constraints: const BoxConstraints(maxWidth: 240, minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isMe
            ? colorScheme.primary.withValues(alpha: 0.95)
            : colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: widget.isMe ? Colors.white24 : colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 10),
              ),
            ),
          Row(
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
                  icon: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: iconColor,
                    size: 18,
                  ),
                  onPressed: _unsupported ? null : _togglePlayPause,
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
                    value: _progressValue,
                    onChanged: _unsupported
                        ? null
                        : (val) {
                            final totalMs = effectiveDuration.inMilliseconds;
                            if (totalMs > 0) {
                              _player.seek(Duration(milliseconds: (val * totalMs).round()));
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
        ],
      ),
    );
  }
}
