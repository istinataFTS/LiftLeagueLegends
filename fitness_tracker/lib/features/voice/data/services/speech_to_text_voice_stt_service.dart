import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart'
    show ListenMode, SpeechListenOptions;

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/services/voice_stt_service.dart';

// ---------------------------------------------------------------------------
// Plugin port (injectable for testing)
// ---------------------------------------------------------------------------

/// Minimal interface over [stt.SpeechToText] exposing only the methods used
/// by [SpeechToTextVoiceSttService].
///
/// The real plugin uses a factory constructor that returns a singleton, which
/// prevents subclassing. This port lets tests provide a controllable fake
/// without any platform-channel involvement.
abstract class SpeechToTextPort {
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
  });
  bool get isAvailable;
  bool get isListening;
  Future<dynamic> listen({
    void Function(SpeechRecognitionResult)? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechListenOptions? listenOptions,
  });
  Future<void> stop();
  Future<void> cancel();
}

/// Production adapter — wraps the real [stt.SpeechToText] singleton.
class _DefaultSpeechToTextPort implements SpeechToTextPort {
  _DefaultSpeechToTextPort() : _speech = stt.SpeechToText();

  final stt.SpeechToText _speech;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
  }) => _speech.initialize(onError: onError, onStatus: onStatus);

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<dynamic> listen({
    void Function(SpeechRecognitionResult)? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechListenOptions? listenOptions,
  }) => _speech.listen(
    onResult: onResult,
    listenFor: listenFor,
    pauseFor: pauseFor,
    localeId: localeId,
    listenOptions: listenOptions,
  );

  @override
  Future<void> stop() => _speech.stop();

  @override
  Future<void> cancel() => _speech.cancel();
}

// ---------------------------------------------------------------------------
// Session model
// ---------------------------------------------------------------------------

/// Holds the mutable state for a single STT listen session.
///
/// One instance is created per [SpeechToTextVoiceSttService.listen] call and
/// discarded when the session ends. Keeping session state here rather than
/// on the service itself makes it impossible to accidentally carry state
/// across sessions.
class _ListenSession {
  _ListenSession({required this.localeId})
    : controller = StreamController<VoiceSttResult>.broadcast();

  final String? localeId;
  final StreamController<VoiceSttResult> controller;

  /// The most recent partial transcript received in this session.
  /// Promoted to a final result on `noSpeech` if non-empty.
  String latestPartial = '';

  /// How many times the recogniser has been restarted after a `noSpeech`
  /// with no partial (Samsung warm-up quirk handling).
  int restartCount = 0;

  /// True once a final result has been emitted, preventing double-promotion
  /// when both `_onError(noSpeech)` and `_onStatus('done')` fire.
  bool finalEmitted = false;
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Device-native STT via the `speech_to_text` plugin.
///
/// Wraps [SpeechToTextPort] (backed by [stt.SpeechToText] in production) into
/// the continuous-listening stream contract expected by [VoiceSttService]:
///
/// - Uses [ListenMode.dictation] for longer, pause-tolerant utterances.
/// - Tracks the latest partial in every session. On `error_no_match`
///   (Android / Samsung warm-up), promotes the partial to a final result
///   if one exists, or silently restarts up to
///   [VoiceConstants.sttMaxNoMatchRestarts] times if nothing was heard yet.
/// - Promotes an un-finalised partial to a final result on `status='done'`
///   (Samsung sometimes ends without tagging the last result as final).
///
/// The underlying plugin uses Android [SpeechRecognizer] / iOS
/// [SFSpeechRecognizer] — no audio leaves the device and no API key is
/// required.
class SpeechToTextVoiceSttService implements VoiceSttService {
  /// [port] can be injected in tests; omit in production to use the real
  /// plugin adapter.
  SpeechToTextVoiceSttService([SpeechToTextPort? port])
    : _speech = port ?? _DefaultSpeechToTextPort();

  final SpeechToTextPort _speech;
  _ListenSession? _session;
  bool _initialized = false;

  // ── VoiceSttService interface ───────────────────────────────────────────────

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = await _speech.initialize(
      onStatus: _onStatus,
      onError: _onError,
    );
    if (!_initialized) {
      AppLogger.warning(
        'SpeechToTextVoiceSttService: initialize returned false — '
        'STT not available on this device/OS.',
      );
    }
  }

  @override
  bool get isAvailable => _speech.isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) {
    _closeSession();
    _session = _ListenSession(localeId: localeId);
    AppLogger.info(
      'SpeechToTextVoiceSttService: listen() starting '
      '(locale=${localeId ?? 'en-US'}, '
      'listenFor=${VoiceConstants.sttListenTimeout.inSeconds}s, '
      'pauseFor=${VoiceConstants.sttSilenceTimeout.inSeconds}s)',
      category: 'voice/stt/on-device',
    );
    _startListening();
    return _session!.controller.stream;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    // The plugin is contractually required to fire `_onStatus('done')` after
    // stop(), which will close the session. We do NOT close it here so that
    // any pending partial can still be promoted in `_onStatus`.
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _closeSession();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _initialized = false;
  }

  // ── Internal: start a listening pass ───────────────────────────────────────

  void _startListening() {
    _speech.listen(
      onResult: _onResult,
      listenFor: VoiceConstants.sttListenTimeout,
      pauseFor: VoiceConstants.sttSilenceTimeout,
      localeId: _session?.localeId ?? 'en-US',
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
      ),
    );
  }

  // ── Internal callbacks ──────────────────────────────────────────────────────

  void _onResult(SpeechRecognitionResult result) {
    final session = _session;
    if (session == null || session.controller.isClosed) return;

    if (!result.finalResult) {
      // Diagnostic: log when the recogniser produces its *first* partial of
      // the session. Confirms the mic captured speech the engine could parse.
      if (session.latestPartial.isEmpty && result.recognizedWords.isNotEmpty) {
        AppLogger.info(
          'SpeechToTextVoiceSttService: first partial received '
          '(${result.recognizedWords.length} chars)',
          category: 'voice/stt/on-device',
        );
      }
      session.latestPartial = result.recognizedWords;
      session.controller.add(
        VoiceSttResult(transcript: result.recognizedWords, isFinal: false),
      );
      return;
    }

    // Engine-confirmed final result.
    session.finalEmitted = true;
    session.controller.add(
      VoiceSttResult(transcript: result.recognizedWords, isFinal: true),
    );
    _closeSession();
  }

  void _onStatus(String status) {
    final session = _session;
    if (session == null || session.controller.isClosed) return;

    if (status == 'done' || status == 'notListening') {
      // Promote an un-finalised partial to a final result. This handles
      // Samsung's quirk of stopping cleanly via `pauseFor` without tagging
      // the last `_onResult` as final.
      final promoted = promoteOnSilence(session.latestPartial);
      if (promoted != null && !session.finalEmitted) {
        AppLogger.info(
          'SpeechToTextVoiceSttService: promoting partial on "$status": '
          '"$promoted"',
        );
        session.finalEmitted = true;
        session.controller.add(
          VoiceSttResult(transcript: promoted, isFinal: true),
        );
      }
      _closeSession();
    }
  }

  void _onError(SpeechRecognitionError error) {
    final session = _session;
    if (session == null || session.controller.isClosed) return;

    final kind = classifyErrorCode(error.errorMsg);

    if (isGracefulSilence(kind)) {
      // Claude-voice-style auto-finalise: if the user spoke something,
      // promote the latest partial to a final result.
      final promoted = promoteOnSilence(session.latestPartial);
      if (promoted != null && !session.finalEmitted) {
        AppLogger.info(
          'SpeechToTextVoiceSttService: promoting partial on '
          '"${error.errorMsg}": "$promoted"',
        );
        session.finalEmitted = true;
        session.controller.add(
          VoiceSttResult(transcript: promoted, isFinal: true),
        );
        _closeSession();
        return;
      }

      // Nothing heard yet — restart if budget allows (Samsung warm-up quirk).
      if (shouldRestartOnNoMatch(
        session.latestPartial,
        session.restartCount,
        VoiceConstants.sttMaxNoMatchRestarts,
      )) {
        session.restartCount++;
        AppLogger.debug(
          'SpeechToTextVoiceSttService: restarting after '
          '"${error.errorMsg}" '
          '(${session.restartCount}/${VoiceConstants.sttMaxNoMatchRestarts})',
        );
        _startListening();
        return;
      }

      // Restart budget exhausted, nothing was said — close gracefully.
      AppLogger.info(
        'SpeechToTextVoiceSttService: closing gracefully after '
        '"${error.errorMsg}" — no speech in ${session.restartCount} '
        'restart(s).',
      );
      _closeSession();
      return;
    }

    AppLogger.warning(
      'SpeechToTextVoiceSttService error: ${error.errorMsg} '
      '(permanent: ${error.permanent})',
    );
    session.controller.addError(VoiceSttException(kind, error.errorMsg));
    _closeSession();
  }

  void _closeSession() {
    final session = _session;
    if (session != null && !session.controller.isClosed) {
      session.controller.close();
    }
    _session = null;
  }

  // ── Pure classification helpers (testable without the plugin) ───────────────

  /// Maps a raw `speech_to_text` error code to the public [VoiceSttErrorKind]
  /// taxonomy. Unrecognised codes fall through to [VoiceSttErrorKind.unknown]
  /// rather than throwing — the Android side has historically added new error
  /// strings without notice.
  ///
  /// Exposed for tests so the mapping table is verified in one place.
  @visibleForTesting
  static VoiceSttErrorKind classifyErrorCode(String errorCode) {
    switch (errorCode) {
      case 'error_permission':
      case 'error_audio':
        return VoiceSttErrorKind.permissionDenied;
      case 'error_no_match':
      case 'error_speech_timeout':
        return VoiceSttErrorKind.noSpeech;
      case 'error_network':
      case 'error_network_timeout':
        return VoiceSttErrorKind.network;
      case 'error_recognizer_busy':
      case 'error_client':
        return VoiceSttErrorKind.unavailable;
      default:
        return VoiceSttErrorKind.unknown;
    }
  }

  /// Whether a given [VoiceSttErrorKind] is the recogniser's normal "I heard
  /// nothing" signal (graceful end-of-stream) rather than a real error.
  ///
  /// Single source of truth for the [VoiceSttService.listen] error-vs-
  /// end-of-speech contract.
  @visibleForTesting
  static bool isGracefulSilence(VoiceSttErrorKind kind) =>
      kind == VoiceSttErrorKind.noSpeech;

  /// Returns [latestPartial] if it should be promoted to a final result,
  /// null otherwise. Promotion fires whenever a non-empty partial exists —
  /// regardless of restart count — since the user clearly spoke.
  @visibleForTesting
  static String? promoteOnSilence(String latestPartial) =>
      latestPartial.isNotEmpty ? latestPartial : null;

  /// Returns true when the recogniser should be silently restarted after
  /// a `noSpeech` event with no partial collected yet.
  @visibleForTesting
  static bool shouldRestartOnNoMatch(
    String latestPartial,
    int restartCount,
    int maxRestarts,
  ) => latestPartial.isEmpty && restartCount < maxRestarts;
}
