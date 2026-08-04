class VoiceNotePlayer {
  VoiceNotePlayer(String url);

  bool get canPlay => false;
  Duration get duration => Duration.zero;
  Duration get position => Duration.zero;

  Stream<Duration> get onTimeUpdate => const Stream.empty();
  Stream<Duration> get onLoadedMetadata => const Stream.empty();
  Stream<void> get onComplete => const Stream.empty();
  Stream<String> get onError => const Stream.empty();

  Future<void> play() async {}
  Future<void> pause() async {}
  void dispose() {}
}
