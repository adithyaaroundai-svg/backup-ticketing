import 'dart:async';

abstract class VoiceNotePlayer {
  bool get isPlaying;
  bool get canPlay;
  Duration get position;
  Duration get duration;

  Stream<Duration> get onPositionChanged;
  Stream<Duration> get onDurationChanged;
  Stream<void> get onComplete;
  Stream<String> get onError;

  Future<void> play();
  Future<void> pause();
  void dispose();
}

VoiceNotePlayer createVoiceNotePlayer(String url) =>
    createVoiceNotePlayerImpl(url);

VoiceNotePlayer createVoiceNotePlayerImpl(String url) =>
    throw UnimplementedError('No player implemented for the current platform.');
