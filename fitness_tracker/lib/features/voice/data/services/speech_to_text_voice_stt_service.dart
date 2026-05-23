import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' show SpeechListenOptions;

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/services/voice_stt_service.dart';

/// Device-native STT via the `speech_to_text` plugin.
///
/// Wraps [stt.SpeechToText]'s callback-based API into the stream contract
/// expected by [VoiceSttService]. The underlying plugin uses Android
/// [SpeechRecognizer] / iOS [SFSpeechRecognizer] — no audio leaves the
/// device and no API key is required.
class SpeechToTextVoiceSttService implements VoiceSttService {
  /// [speech] can be injected in tests; omit in production to use the real engine.
  SpeechToTextVoiceSttService([stt.SpeechToText? speech])
    : _speech = speech ?? stt.SpeechToText();

  final stt.SpeechToText _speech;
  StreamController<VoiceSttResult>? _controller;
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
    _closeController();
    _controller = StreamController<VoiceSttResult>.broadcast();

    // `cancelOnError` is intentionally false: Android's SpeechRecognizer fires
    // `error_no_match` and `error_speech_timeout` as normal "didn't hear any
    // speech" signals during recogniser warm-up (especially on Samsung). Those
    // are reclassified in [_onError] as a graceful end-of-stream, not an error,
    // so the plugin-level cancel-on-error would terminate the session before
    // the user has even started speaking. See KNOWN_ISSUES.md
    // #voice-stt-no-match-is-not-an-error.
    _speech.listen(
      onResult: _onResult,
      listenFor: VoiceConstants.sttListenTimeout,
      pauseFor: VoiceConstants.sttSilenceTimeout,
      localeId: localeId ?? 'en-US',
      listenOptions: SpeechListenOptions(),
    );

    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _closeController();
  }

  @override
  Future<void> dispose() async {
    await cancel();
    _initialized = false;
  }

  // ── Internal callbacks ──────────────────────────────────────────────────────

  void _onResult(SpeechRecognitionResult result) {
    if (_controller == null || _controller!.isClosed) return;
    _controller!.add(
      VoiceSttResult(
        transcript: result.recognizedWords,
        isFinal: result.finalResult,
      ),
    );
    if (result.finalResult) {
      _closeController();
    }
  }

  void _onStatus(String status) {
    // 'done' / 'notListening' means the engine stopped. The plugin normally
    // fires a final result before 'done' on normal termination; this handles
    // the edge case where it stopped with no result (e.g. pure silence).
    if (status == 'done' || status == 'notListening') {
      _closeController();
    }
  }

  void _onError(SpeechRecognitionError error) {
    final kind = classifyErrorCode(error.errorMsg);

    // `noSpeech` (Android `error_no_match` / `error_speech_timeout`) is not a
    // failure — it is the recogniser saying "I heard nothing recognisable".
    // Close the result stream gracefully via `onDone` so the bloc reverts to
    // idle the same way it would after a natural pause. See KNOWN_ISSUES.md
    // #voice-stt-no-match-is-not-an-error.
    if (isGracefulSilence(kind)) {
      AppLogger.info(
        'SpeechToTextVoiceSttService: no speech detected '
        '(${error.errorMsg}); closing stream gracefully.',
      );
      _closeController();
      return;
    }

    AppLogger.warning(
      'SpeechToTextVoiceSttService error: ${error.errorMsg} '
      '(permanent: ${error.permanent})',
    );
    _controller?.addError(VoiceSttException(kind, error.errorMsg));
    _closeController();
  }

  void _closeController() {
    if (_controller != null && !_controller!.isClosed) {
      _controller!.close();
    }
    _controller = null;
  }

  // ── Pure classification helpers (testable without the plugin) ───────────────

  /// Maps a raw `speech_to_text` error code to the public [VoiceSttErrorKind]
  /// taxonomy. Unrecognised codes fall through to [VoiceSttErrorKind.unknown]
  /// rather than throwing — the Android side has historically added new error
  /// strings without notice.
  ///
  /// Exposed for tests so the mapping table is verified in one place instead
  /// of being mirrored across the test file.
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
  /// This is the single source of truth for the
  /// [VoiceSttService.listen] error-vs-end-of-speech contract.
  @visibleForTesting
  static bool isGracefulSilence(VoiceSttErrorKind kind) =>
      kind == VoiceSttErrorKind.noSpeech;
}
