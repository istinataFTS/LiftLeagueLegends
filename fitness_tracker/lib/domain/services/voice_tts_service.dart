import '../../../../core/constants/voice_constants.dart';

/// Abstract port for device-native text-to-speech playback.
///
/// C-4 provides the `flutter_tts` implementation
/// ([FlutterTtsVoiceTtsService]). Tests can swap in a hand-rolled fake
/// without touching the bloc.
abstract class VoiceTtsService {
  /// One-time setup of the native TTS engine. Calling after a successful
  /// init is a no-op. [VoiceBloc] calls this lazily before the first
  /// [speak] call.
  Future<void> initialize({
    double volume = VoiceConstants.defaultTtsVolume,
    double speechRate = VoiceConstants.defaultTtsSpeechRate,
  });

  /// Speak [text] using the device TTS engine. Completes when speech
  /// finishes or is interrupted by a subsequent [stop] call.
  Future<void> speak(String text);

  /// Interrupt any in-progress speech immediately.
  Future<void> stop();

  /// Set playback volume (0.0 – 1.0). Applied before the next [speak] call.
  Future<void> setVolume(double volume);

  /// Set speech rate (0.5 – 2.0; 1.0 = normal). Applied before the next
  /// [speak] call.
  Future<void> setSpeechRate(double rate);

  /// Release native TTS resources. Called at app shutdown by the DI
  /// framework; never called directly by [VoiceBloc].
  Future<void> dispose();
}
