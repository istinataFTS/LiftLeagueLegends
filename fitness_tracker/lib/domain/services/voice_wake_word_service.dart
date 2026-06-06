import '../../../../domain/entities/voice_settings.dart' show WakeWordPreset;

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

enum VoiceWakeWordErrorKind {
  modelLoadError, // bundled KWS model assets missing or zero-bytes
  engineError, // wake-word engine runtime error
  audioError, // microphone access failure
}

class VoiceWakeWordException implements Exception {
  const VoiceWakeWordException(this.kind, [this.message]);

  final VoiceWakeWordErrorKind kind;
  final String? message;

  @override
  String toString() => 'VoiceWakeWordException($kind, $message)';
}

// ---------------------------------------------------------------------------
// Abstract port
// ---------------------------------------------------------------------------

/// Abstract port for wake-word detection.
///
/// Implemented by [SherpaOnnxVoiceWakeWordService] (offline, no credentials).
/// Tests can inject a simple stream-controller fake without touching native code.
abstract class VoiceWakeWordService {
  /// Broadcast stream that emits the active [WakeWordPreset] each time the
  /// wake word is detected. Never errors — runtime errors are emitted on
  /// [onError] instead.
  Stream<WakeWordPreset> get onWakeWordDetected;

  /// Errors that occur during active detection (after a successful [start]).
  /// Does not include errors thrown from [start] itself.
  Stream<VoiceWakeWordException> get onError;

  /// Whether the engine is currently running.
  bool get isRunning;

  /// Start wake-word detection for [preset]. Stops any currently running
  /// engine first (idempotent if already running the same preset).
  ///
  /// Throws [VoiceWakeWordException] with kind [VoiceWakeWordErrorKind.modelLoadError]
  /// if the bundled KWS model assets for [preset] are missing or zero-bytes.
  Future<void> start(WakeWordPreset preset);

  /// Stop wake-word detection and release the microphone.
  Future<void> stop();

  /// Release all native resources. Called at app shutdown.
  Future<void> dispose();
}
