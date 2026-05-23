/// Error categories surfaced by [VoiceSttService].
enum VoiceSttErrorKind {
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  noSpeech,
  network,
  unknown,
}

/// A single STT result emitted on the [VoiceSttService.listen] stream.
class VoiceSttResult {
  const VoiceSttResult({required this.transcript, required this.isFinal});

  /// The recognised text so far.
  final String transcript;

  /// True on the final result; false for live partial updates.
  final bool isFinal;
}

/// Thrown on the [VoiceSttService.listen] stream when recognition fails.
class VoiceSttException implements Exception {
  const VoiceSttException(this.kind, [this.message]);

  final VoiceSttErrorKind kind;
  final String? message;

  @override
  String toString() => 'VoiceSttException($kind, $message)';
}

/// Abstract port for device-native speech-to-text.
///
/// C-4 provides the `speech_to_text` implementation
/// ([SpeechToTextVoiceSttService]). The [VoiceBloc] interacts exclusively
/// through this interface so tests can drive it with a simple fake.
abstract class VoiceSttService {
  /// One-time setup. Calling again after successful init is a no-op.
  Future<void> initialize();

  /// Whether the STT engine is available after [initialize].
  bool get isAvailable;

  /// Whether the STT engine is currently listening.
  bool get isListening;

  /// Begin listening and return a broadcast stream of [VoiceSttResult].
  ///
  /// Emits [VoiceSttResult] objects with [isFinal] == false for live
  /// partial transcripts, then optionally a final result with
  /// [isFinal] == true. On error the stream adds a [VoiceSttException]
  /// via `onError`.
  ///
  /// ### Stream-completion contract
  ///
  /// The returned stream **must** complete (fire `onDone`) in every
  /// terminal scenario so callers can revert UI state. Implementations
  /// are required to close the underlying controller when ANY of these
  /// occur:
  ///
  ///   1. A final result has been emitted (isFinal == true).
  ///   2. The engine reports it has stopped listening on its own — e.g.
  ///      the user fell silent past the platform's pause threshold, or
  ///      the hard listen-for timeout fired without recognised speech.
  ///   3. [stop] or [cancel] is invoked.
  ///   4. An error is added via `addError`.
  ///
  /// [VoiceBloc] relies on this contract to escape `VoiceStatus.listening`
  /// when the user is silent — without it the overlay shows "Listening…"
  /// forever and wake-word re-trigger is gated off permanently.
  ///
  /// [localeId] overrides the device default locale (e.g. `'en-US'`).
  /// Pass null to use the device default.
  Stream<VoiceSttResult> listen({String? localeId});

  /// Stop listening gracefully. Any pending partial result is discarded.
  /// Completes the stream returned by the most recent [listen] call
  /// (see stream-completion contract on [listen]).
  Future<void> stop();

  /// Cancel in-progress STT without committing a result. Unlike [stop],
  /// this does NOT emit a final [VoiceSttResult] — any partial transcript
  /// is discarded. Used when the user taps "Cancel" during listening.
  /// Completes the stream returned by the most recent [listen] call
  /// (see stream-completion contract on [listen]).
  Future<void> cancel();

  /// Release native resources. Called at app shutdown by the DI framework;
  /// never called directly by [VoiceBloc].
  Future<void> dispose();
}
