/// Error categories surfaced by [VoiceSttService].
///
/// The first six values are device-native concepts. The last four
/// ([auth], [audioTooLarge], [budgetExceeded], [serverUnavailable]) only ever
/// surface from the Whisper-backed STT path — but they live on the shared
/// enum so [VoiceBloc] has one place to map errors to user-facing copy.
enum VoiceSttErrorKind {
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  noSpeech,
  network,
  unknown,
  auth,
  audioTooLarge,
  budgetExceeded,
  serverUnavailable,
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
  /// partial transcripts, then a final result with [isFinal] == true.
  /// On unrecoverable error the stream adds a [VoiceSttException] via
  /// `onError`.
  ///
  /// ### Continuous-listening session model
  ///
  /// The stream stays open until one of the following occurs:
  ///   (a) A final transcript is emitted (`isFinal == true`).
  ///   (b) The hard [VoiceConstants.sttListenTimeout] envelope elapses.
  ///   (c) [cancel] or [stop] is called by the caller.
  ///   (d) A non-recoverable error fires (see below).
  ///
  /// Transient `noSpeech` outcomes inside the envelope are handled
  /// *internally* by the implementation:
  ///   - If a partial transcript was already collected, it is promoted to
  ///     a synthetic final result (Claude-voice-style auto-finalise on
  ///     silence) and the stream closes normally.
  ///   - If no partial exists yet, the underlying recogniser is silently
  ///     restarted up to [VoiceConstants.sttMaxNoMatchRestarts] times
  ///     (handles Samsung warm-up quirk). The caller sees uninterrupted
  ///     "Listening…" state.
  ///   - Once the restart budget is exhausted with still no speech, the
  ///     stream closes via `onDone` without error.
  ///
  /// Callers **must not** assume that a `noSpeech` outcome will ever reach
  /// them as an `onError` event — the implementation absorbs it.
  ///
  /// ### Error vs end-of-speech
  ///
  /// [VoiceSttErrorKind.noSpeech] outcomes are handled internally (see
  /// above). Only [permissionDenied], [permissionPermanentlyDenied],
  /// [unavailable], [network], and [unknown] kinds are propagated as
  /// stream errors.
  ///
  /// ### Stream-completion contract
  ///
  /// The returned stream **must** complete (fire `onDone`) in every
  /// terminal scenario. [VoiceBloc] relies on this to escape
  /// `VoiceStatus.listening` and re-arm the wake-word engine.
  ///
  /// [localeId] overrides the device default locale (e.g. `'en-US'`).
  /// Pass null to use the device default.
  Stream<VoiceSttResult> listen({String? localeId});

  /// Stop listening gracefully and **commit** the utterance. Unlike [cancel],
  /// `stop()` is not a discard: the implementation MUST deliver the captured
  /// utterance's outcome AFTER this call, reaching the caller's existing
  /// result/error handlers, by emitting either:
  ///   - a final [VoiceSttResult] (`isFinal == true`) — a pending partial is
  ///     promoted to a final (on-device), or the recorded clip is transcribed
  ///     and emitted (Whisper); or
  ///   - a terminal error via `onError` — e.g. network / unavailable, or
  ///     [VoiceSttErrorKind.noSpeech] / an empty final when nothing
  ///     intelligible was captured.
  ///
  /// This post-stop emission is what [VoiceBloc] relies on to finalize a manual
  /// Stop (see `_onListenStopRequested` + the `_manualStopFinalize` path in
  /// `voice_bloc.dart`) instead of dropping the turn. NOTE: an explicit `stop()`
  /// is the one path where a `noSpeech` outcome MAY surface via `onError` — the
  /// in-envelope absorption described on [listen] applies only while listening,
  /// not once the caller has committed with `stop()`.
  ///
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
