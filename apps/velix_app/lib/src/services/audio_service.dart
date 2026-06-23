/// Audio recording and playback abstraction.
abstract class AudioService {
  Future<void> startRecording();
  Future<String?> stopRecording();
  Future<void> play(String path);
  Future<void> pause();
  Future<void> stop();
  Stream<Duration> get positionStream;
  Stream<double> get amplitudeStream;
}
