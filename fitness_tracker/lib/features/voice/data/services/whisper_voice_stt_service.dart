import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

    try {
      if (!await _recorder.hasPermission()) {
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
          unawaited(_stopAndTranscribe(language: language));
        }
      });

      _amplitudeSub = _recorder
          .onAmplitudeChanged(VoiceConstants.whisperAmplitudePollInterval)
          .listen((amp) {
        if (!_isListeningInternal) return;
        final now = DateTime.now();
        if (amp.current > VoiceConstants.whisperSilenceAmplitudeDbfs) {
          _lastVoiceAt = now;
        } else if (_lastVoiceAt != null) {
          final silenceFor = now.difference(_lastVoiceAt!);
          if (silenceFor >= VoiceConstants.whisperSilenceTimeout) {
            unawaited(_stopAndTranscribe(language: language));
          }
        }
      });
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recording failed to start',
        category: 'voice',
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
    await _stopAndTranscribe(language: null);
  }

  /// Stops recording, reads the file, uploads it, and emits the transcript.
  /// Internal because both the public `stop()` and the auto-stop timers
  /// drive the same flow.
  Future<void> _stopAndTranscribe({String? language}) async {
    if (!_isListeningInternal) return;
    _isListeningInternal = false;
    final controller = _controller;
    final path = _activePath;
    await _teardownTimersAndSubscription();

    String? finalPath;
    try {
      finalPath = await _recorder.stop();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recorder.stop() failed',
        category: 'voice',
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
          category: 'voice',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
    await _deleteFile(finalPath);

    if (bytes == null || bytes.isEmpty) {
      _emitError(
        controller,
        const VoiceSttException(VoiceSttErrorKind.noSpeech),
      );
      await _closeController();
      return;
    }

    try {
      final transcript = await _remote.transcribe(
        audioBytes: bytes,
        filename: finalPath != null ? p.basename(finalPath) : 'utterance.m4a',
        language: language ?? 'en',
      );
      if (transcript.trim().isEmpty) {
        _emitError(
          controller,
          const VoiceSttException(VoiceSttErrorKind.noSpeech),
        );
      } else {
        _emit(
          controller,
          VoiceSttResult(transcript: transcript.trim(), isFinal: true),
        );
      }
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: transcription request failed',
        category: 'voice',
        error: error,
        stackTrace: stackTrace,
      );
      final kind = _classifyTranscribeError(error);
      _emitError(
        controller,
        VoiceSttException(kind, error.toString()),
      );
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
    await _teardownTimersAndSubscription();
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      AppLogger.warning(
        'WhisperVoiceSttService: recorder.cancel() failed',
        category: 'voice',
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

  /// Classifies an error from `_remote.transcribe(...)` into the closest
  /// [VoiceSttErrorKind]. Network-class failures (timeouts, transport
  /// errors) get mapped to `network` so the bloc reads back the
  /// `voiceSpokenNetworkDown` line; everything else collapses to `unknown`.
  VoiceSttErrorKind _classifyTranscribeError(Object error) {
    if (error is ServerFailure) {
      final upper = error.message.toUpperCase();
      if (upper.contains('TIMEOUT') || upper.contains('NETWORK')) {
        return VoiceSttErrorKind.network;
      }
    }
    if (error is SocketException || error is HttpException) {
      return VoiceSttErrorKind.network;
    }
    return VoiceSttErrorKind.unknown;
  }

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
