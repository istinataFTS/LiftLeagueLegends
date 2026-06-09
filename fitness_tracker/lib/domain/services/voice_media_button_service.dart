/// Abstract port for a hardware/headset media-button "tap to wake" signal.
///
/// Implemented on Android by [PlatformChannelVoiceMediaButtonService] over a
/// native MediaSession; [NoopVoiceMediaButtonService] elsewhere. Tests inject a
/// stream-controller fake. Mirrors [VoiceWakeWordService].
abstract class VoiceMediaButtonService {
  /// Broadcast stream; emits once per debounced media-button press.
  Stream<void> get onMediaButtonPressed;

  /// Whether the native session is currently active.
  bool get isRunning;

  /// Begin listening for media-button presses (activates the native session).
  Future<void> start();

  /// Stop listening and release the native session.
  Future<void> stop();
}
