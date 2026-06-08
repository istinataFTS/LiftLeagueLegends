import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../data/datasources/remote/voice_remote_datasource.dart';
import '../../../../domain/services/voice_stt_service.dart';

/// Whisper-backed [VoiceSttService] — records audio locally, uploads to the
/// `voice-transcribe` Edge Function on stop, emits a single synthetic final
/// [VoiceSttResult]. No partials (Whisper is one-shot).
///
/// Lifecycle:
///   - [listen] starts recording to a temp m4a file and arms two timers:
///     a hard-cap timer at [VoiceConstants.whisperMaxAudioDuration] and an
///     amplitude-based silence monitor at
///     [VoiceConstants.whisperSilenceTimeout].
///   - Either timer firing calls [stop] internally, which reads the file,
///     posts it to the function, emits the transcript, and closes the stream.
///   - [cancel] discards the file without uploading.
class WhisperVoiceSttService implements VoiceSttService {
  WhisperVoiceSttService({
    required VoiceRemoteDataSource remoteDataSource,
    AudioRecorder? recorder,
  }) : _remote = remoteDataSource,
       _recorder = recorder ?? AudioRecorder();

  final VoiceRemoteDataSource _remote;
  final AudioRecorder _recorder;

  StreamController<VoiceSttResult>? _controller;
  String? _activePath;
  StreamSubscription<Amplitude>? _amplitudeSub;
  Timer? _hardCapTimer;
  DateTime? _lastVoiceAt;
  bool _isInitialized = false;
  bool _isListeningInternal = false;
  bool _cancelled = false;
  bool _firstAmplitudeLogged = false;

  /// True once any amplitude sample crossed [VoiceConstants.whisperSilenceAmplitudeDbfs]
  /// during this recording. When it stays false the clip is silence-only and
  /// must NOT be uploaded — Whisper hallucinates canned phrases (e.g.
  /// "For more information visit www.FEMA.gov") on silent audio.
  /// See KNOWN_ISSUES.md #voice-whisper-hallucinates-on-silent-audio.
  bool _voiceDetected = false;

  /// Log category for all events from this service. Tagged so a developer
  /// running `adb logcat | grep voice/stt/whisper` sees the entire recording
  /// + upload lifecycle of one utterance.
  static const String _logCategory = 'voice/stt/whisper';

  @override
  Future<void> initialize() async {
    // Recorder is lazy — actual platform initialization happens at `start()`.
    // We only flip the readiness flag so `isAvailable` reflects the intended
    // lifecycle, matching the on-device STT contract.
    _isInitialized = true;
  }

  @override
  bool get isAvailable => _isInitialized;

  @override
  bool get isListening => _isListeningInternal;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) {
    if (_isListeningInternal) {
      throw StateError(
        'WhisperVoiceSttService.listen() called while already listening',
      );
    }
    _cancelled = false;
    _lastVoiceAt = null;

    // Single-subscription stream — the bloc attaches one listener and gets
    // exactly one terminal event (final result, error, or onDone).
    final controller = StreamController<VoiceSttResult>(
      onCancel: () {
        if (_isListeningInternal) {
          unawaited(cancel());
        }
      },
    );
    _controller = controller;

    final language = (localeId == null || localeId.isEmpty)
        ? null
        : localeId.split('-').first;
    unawaited(_startRecording(language: language));
    return controller.stream;
  }

  Future<void> _startRecording({String? language}) async {
    final controller = _controller;
    if (controller == null) return;

    _firstAmplitudeLogged = false;
    _voiceDetected = false;

    try {
      if (!await _recorder.hasPermission()) {
        AppLogger.warning(
          'WhisperVoiceSttService: recorder reported no microphone permission',
          category: _logCategory,
        );
        _emitError(
          controller,
          const VoiceSttException(VoiceSttErrorKind.permissionDenied),
        );
        await _closeController();
        return;
      }

      final tmpDir = await getTemporaryDirectory();
      final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final path = p.join(tmpDir.path, filename);
      _activePath = path;

      AppLogger.info(
        'WhisperVoiceSttService: starting recorder '
        '(sampleRate=${VoiceConstants.whisperAudioSampleRate}Hz, '
        'bitRate=${VoiceConstants.whisperAudioBitrate}bps, '
        'language=${language ?? 'en'})',
        category: _logCategory,
      );

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: VoiceConstants.whisperAudioBitrate,
          sampleRate: VoiceConstants.whisperAudioSampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      _isListeningInternal = true;

      _hardCapTimer = Timer(VoiceConstants.whisperMaxAudioDuration, () {
        if (_isListeningInternal) {
          unawaited(
            _stopAndTranscribe(language: language, stopReason: 'hard-cap'),
          );
        }
      });

      _amplitudeSub = _recorder
          .onAmplitudeChanged(VoiceConstants.whisperAmplitudePollInterval)
          .listen((amp) {
            if (!_isListeningInternal) return;
            if (!_firstAmplitudeLogged) {
              _firstAmplitudeLogged = true;
              // Diagnostic: confirms the mic is actually delivering signal.
              // If the user's "tap → nothing" symptom is mic-side, this line
              // will be absent or stuck at -inf / very low dBFS.
              AppLogger.info(
                'WhisperVoiceSttService: first amplitude '
                '${amp.current.toStringAsFixed(1)} dBFS '
                '(silence threshold ${VoiceConstants.whisperSilenceAmplitudeDbfs} dBFS)',
                category: _logCategory,
              );
            }
            final now = DateTime.now();
            if (amp.current > VoiceConstants.whisperSilenceAmplitudeDbfs) {
              _voiceDetected = true;
              _lastVoiceAt = now;
            } else if (_lastVoiceAt != null) {
              final silenceFor = now.difference(_lastVoiceAt!);
              if (silenceFor >= VoiceConstants.whisperSilenceTimeout) {
                unawaited(
                  _stopAndTranscribe(language: language, stopReason: 'silence'),
                );
              }
            }
          });
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recording failed to start',
        category: _logCategory,
        error: error,
        stackTrace: stackTrace,
      );
      _emitError(
        controller,
        VoiceSttException(VoiceSttErrorKind.unknown, error.toString()),
      );
      await _closeController();
    }
  }

  @override
  Future<void> stop() async {
    if (!_isListeningInternal) return;
    await _stopAndTranscribe(language: null, stopReason: 'manual');
  }

  /// Stops recording, reads the file, uploads it, and emits the transcript.
  /// Internal because both the public `stop()` and the auto-stop timers
  /// drive the same flow. [stopReason] is logged so a developer can tell
  /// from the trace whether the user, the silence detector, or the hard-cap
  /// timer ended the session.
  Future<void> _stopAndTranscribe({
    String? language,
    required String stopReason,
  }) async {
    if (!_isListeningInternal) return;
    _isListeningInternal = false;
    AppLogger.info(
      'WhisperVoiceSttService: stopping recorder (reason=$stopReason)',
      category: _logCategory,
    );
    final controller = _controller;
    final path = _activePath;
    await _teardownTimersAndSubscription();

    String? finalPath;
    try {
      finalPath = await _recorder.stop();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recorder.stop() failed',
        category: _logCategory,
        error: error,
        stackTrace: stackTrace,
      );
    }
    finalPath ??= path;

    if (controller == null || _cancelled) {
      await _deleteFile(finalPath);
      await _closeController();
      return;
    }

    Uint8List? bytes;
    if (finalPath != null) {
      try {
        final file = File(finalPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } catch (error, stackTrace) {
        AppLogger.warning(
          'WhisperVoiceSttService: failed to read recorded audio',
          category: _logCategory,
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _deleteFile(finalPath);

    if (bytes == null || bytes.isEmpty) {
      AppLogger.warning(
        'WhisperVoiceSttService: recorded file was empty — '
        'mic probably did not capture any audio',
        category: _logCategory,
      );
      _emitError(
        controller,
        const VoiceSttException(VoiceSttErrorKind.noSpeech),
      );
      await _closeController();
      return;
    }

    if (!shouldTranscribe(voiceDetected: _voiceDetected, byteCount: bytes.length)) {
      AppLogger.info(
        'WhisperVoiceSttService: no voice detected during recording '
        '(voiceDetected=$_voiceDetected, ${bytes.length} bytes) — '
        'skipping upload to avoid silence hallucination',
        category: _logCategory,
      );
      _emitError(
        controller,
        const VoiceSttException(VoiceSttErrorKind.noSpeech),
      );
      await _closeController();
      return;
    }

    final uploadKb = (bytes.length / 1024).toStringAsFixed(1);
    AppLogger.info(
      'WhisperVoiceSttService: uploading $uploadKb KB to voice-transcribe',
      category: _logCategory,
    );

    try {
      final transcript = await _remote.transcribe(
        audioBytes: bytes,
        filename: finalPath != null ? p.basename(finalPath) : 'utterance.m4a',
        language: language ?? 'en',
      );
      if (transcript.trim().isEmpty) {
        AppLogger.info(
          'WhisperVoiceSttService: server returned an empty transcript',
          category: _logCategory,
        );
        _emitError(
          controller,
          const VoiceSttException(VoiceSttErrorKind.noSpeech),
        );
      } else {
        AppLogger.info(
          'WhisperVoiceSttService: transcription received '
          '(${transcript.trim().length} chars)',
          category: _logCategory,
        );
        _emit(
          controller,
          VoiceSttResult(transcript: transcript.trim(), isFinal: true),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: transcription request failed',
        category: _logCategory,
        error: error,
        stackTrace: stackTrace,
      );
      final kind = _classifyTranscribeError(error);
      _emitError(controller, VoiceSttException(kind, error.toString()));
    }

    await _closeController();
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    if (!_isListeningInternal) {
      await _closeController();
      return;
    }
    _isListeningInternal = false;
    AppLogger.info(
      'WhisperVoiceSttService: cancelling recorder (user cancel)',
      category: _logCategory,
    );
    await _teardownTimersAndSubscription();
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recorder.cancel() failed',
        category: _logCategory,
        error: error,
        stackTrace: stackTrace,
      );
    }
    await _deleteFile(_activePath);
    await _closeController();
  }

  @override
  Future<void> dispose() async {
    await _teardownTimersAndSubscription();
    try {
      await _recorder.dispose();
    } catch (_) {
      // Best-effort — the recorder may already be torn down.
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Whether a finished recording should be uploaded for transcription.
  ///
  /// A clip is uploaded only if (1) at least one amplitude sample crossed the
  /// voice threshold during recording and (2) the file is non-empty. Silence-
  /// only clips are dropped to prevent Whisper hallucinating canned phrases on
  /// silence. Pure so it is unit-testable without the `record` plugin.
  @visibleForTesting
  static bool shouldTranscribe({
    required bool voiceDetected,
    required int byteCount,
  }) => voiceDetected && byteCount > 0;

  /// Classifies an error from `_remote.transcribe(...)` into the closest
  /// [VoiceSttErrorKind]. The remote layer encodes Edge Function failures as
  /// `ServerFailure('CODE|status|message')` (see [
  /// SupabaseVoiceRemoteDataSource._throwFromErrorBody]); we decode the
  /// prefix here. Transport-layer failures (no JSON body, dropped socket)
  /// collapse to [VoiceSttErrorKind.network]; anything we can't recognise
  /// becomes [VoiceSttErrorKind.unknown] with the original message attached.
  ///
  /// Exposed (in spirit) via a tested helper so this mapping is the single
  /// source of truth for converting upstream codes to user-visible kinds.
  @visibleForTesting
  static VoiceSttErrorKind classifyTranscribeError(Object error) {
    if (error is ServerFailure) {
      final encoded = error.message;
      // Try the structured "CODE|status|message" form first.
      final firstPipe = encoded.indexOf('|');
      if (firstPipe > 0) {
        final code = encoded.substring(0, firstPipe).toUpperCase();
        switch (code) {
          case 'UNAUTHORIZED':
          case 'GUEST_FORBIDDEN':
            return VoiceSttErrorKind.auth;
          case 'BUDGET_EXCEEDED':
            return VoiceSttErrorKind.budgetExceeded;
          case 'INVALID_REQUEST':
            // 413 = audio exceeded MAX_AUDIO_BYTES; other 400s are
            // genuinely unexpected and stay as `unknown`.
            final parts = encoded.split('|');
            if (parts.length >= 2 && parts[1] == '413') {
              return VoiceSttErrorKind.audioTooLarge;
            }
            return VoiceSttErrorKind.unknown;
          case 'OPENAI_UNAVAILABLE':
          case 'RATE_LIMITED':
            return VoiceSttErrorKind.serverUnavailable;
          case 'TIMEOUT':
            return VoiceSttErrorKind.network;
          case 'INTERNAL':
            return VoiceSttErrorKind.serverUnavailable;
        }
      }
      // Legacy / unencoded ServerFailure — fall back to keyword sniffing.
      final upper = encoded.toUpperCase();
      if (upper.contains('TIMEOUT') || upper.contains('NETWORK')) {
        return VoiceSttErrorKind.network;
      }
    }
    if (error is SocketException || error is HttpException) {
      return VoiceSttErrorKind.network;
    }
    return VoiceSttErrorKind.unknown;
  }

  VoiceSttErrorKind _classifyTranscribeError(Object error) =>
      classifyTranscribeError(error);

  void _emit(
    StreamController<VoiceSttResult> controller,
    VoiceSttResult result,
  ) {
    if (!controller.isClosed) controller.add(result);
  }

  void _emitError(
    StreamController<VoiceSttResult> controller,
    VoiceSttException error,
  ) {
    if (!controller.isClosed) controller.addError(error);
  }

  Future<void> _teardownTimersAndSubscription() async {
    _hardCapTimer?.cancel();
    _hardCapTimer = null;
    await _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _lastVoiceAt = null;
  }

  Future<void> _closeController() async {
    final controller = _controller;
    _controller = null;
    _activePath = null;
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Best-effort — the OS will eventually GC the temp directory.
    }
  }
}
