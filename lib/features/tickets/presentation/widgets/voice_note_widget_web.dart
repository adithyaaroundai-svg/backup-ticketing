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
      setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onPlayerComplete.listen((_) {
      setState(() => _position = Duration.zero);
    });
    _player.onPositionChanged.listen((pos) {
      setState(() => _position = pos);
    });
    _player.onDurationChanged.listen((dur) {
      setState(() => _totalDuration = dur);
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
      setState(() {
        _unsupported = true;
        _errorMessage = 'Unable to play this voice note.';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_unsupported) return;
    try {
      if (_player.state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
        setState(() => _isPlaying = true);
      }
    } catch (_) {
      setState(() {
        _unsupported = true;
        _errorMessage = 'Failed to play voice note.';
        _isPlaying = false;
      });
    }
  }

  Color get _primaryTextColor => widget.isMe ? Colors.white : Colors.black87;

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
    final durationLabel = _totalDuration > Duration.zero
        ? _format(_totalDuration)
        : '00:00';
    final positionLabel = _format(_position);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _errorMessage!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.redAccent),
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: widget.isMe
                      ? Colors.white
                      : Theme.of(context).colorScheme.primary,
                ),
                onPressed: _unsupported ? null : _togglePlayPause,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _progressValue,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isMe
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                      minHeight: 4,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$positionLabel / $durationLabel',
                      style: TextStyle(color: _primaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
