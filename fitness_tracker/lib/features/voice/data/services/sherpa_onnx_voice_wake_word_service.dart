import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../../../core/constants/voice_constants.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../domain/entities/voice_settings.dart'
    show WakeWordPreset, WakeWordPresetPhrase;
import '../../../../domain/services/voice_wake_word_service.dart';
import 'pcm_utils.dart';

// ---------------------------------------------------------------------------
// Testability seams
// ---------------------------------------------------------------------------

/// A running keyword spotter + stream combined into one handle.
/// The real instance delegates to [sherpa_onnx.KeywordSpotter]; unit tests
/// inject a controllable fake to verify glue-code without native ONNX.
abstract class KwsHandle {
  void acceptWaveform({required Float32List samples, required int sampleRate});
  bool get isReady;
  void decode();
  String get keyword;
  void reset();
  void free();
}

/// Creates a [KwsHandle] for [preset].  The real factory extracts model
/// assets from the bundle and initialises the ONNX engine; test factories
/// return fakes without touching the asset bundle or native code.
typedef KwsHandleFactory = Future<KwsHandle> Function(WakeWordPreset preset);

/// Pairs the PCM audio stream with its stop callback, allowing the audio
/// source to be replaced in unit tests with a [StreamController<Uint8List>].
class AudioSession {
  const AudioSession({required this.stream, required this.stop});
  final Stream<Uint8List> stream;
  final Future<void> Function() stop;
}

typedef AudioSessionFactory = Future<AudioSession> Function(RecordConfig cfg);

// ---------------------------------------------------------------------------
// Config builder (pure Dart — no native calls; unit-testable)
// ---------------------------------------------------------------------------

/// Builds the [sherpa_onnx.KeywordSpotterConfig] for the in-memory keywords
/// buffer path.
///
/// CRITICAL: sherpa-onnx's C-api reconstructs the keywords as
/// `std::string(keywords_buf, keywords_buf_size)`. When `keywords_buf_size`
/// is left at its default of 0 the buffer is read as an empty string and
/// engine creation fails with "Please provide either a keywords-file or the
/// keywords-buf". [keywordsBufSize] must therefore be set to the UTF-8 byte
/// length of [keywordsBuf]. A trailing newline is appended so the buffer
/// matches the one-keyword-per-line file format the parser expects.
///
/// Constructing the config objects is pure Dart — no native code runs until
/// [sherpa_onnx.KeywordSpotter] is instantiated — so this is unit-testable
/// without the ONNX runtime.
sherpa_onnx.KeywordSpotterConfig buildKeywordSpotterConfig({
  required String encoderPath,
  required String decoderPath,
  required String joinerPath,
  required String tokensPath,
  required String keywordsBuf,
}) {
  final keywords = keywordsBuf.endsWith('\n') ? keywordsBuf : '$keywordsBuf\n';
  final modelCfg = sherpa_onnx.OnlineModelConfig(
    transducer: sherpa_onnx.OnlineTransducerModelConfig(
      encoder: encoderPath,
      decoder: decoderPath,
      joiner: joinerPath,
    ),
    tokens: tokensPath,
    numThreads: 1,
    debug: false,
  );
  return sherpa_onnx.KeywordSpotterConfig(
    model: modelCfg,
    keywordsBuf: keywords,
    keywordsBufSize: utf8.encode(keywords).length,
    keywordsScore: VoiceConstants.wakeWordKeywordsScore,
    keywordsThreshold: VoiceConstants.wakeWordKeywordsThreshold,
  );
}

// ---------------------------------------------------------------------------
// Real KwsHandle implementation
// ---------------------------------------------------------------------------

class _RealKwsHandle implements KwsHandle {
  _RealKwsHandle._({
    required sherpa_onnx.KeywordSpotter spotter,
    required sherpa_onnx.OnlineStream stream,
  }) : _spotter = spotter,
       _stream = stream;

  static Future<_RealKwsHandle> create({
    required String encoderPath,
    required String decoderPath,
    required String joinerPath,
    required String tokensPath,
    required String keywordsBuf,
  }) async {
    if (!_bindingsReady) {
      sherpa_onnx.initBindings();
      _bindingsReady = true;
    }
    final cfg = buildKeywordSpotterConfig(
      encoderPath: encoderPath,
      decoderPath: decoderPath,
      joinerPath: joinerPath,
      tokensPath: tokensPath,
      keywordsBuf: keywordsBuf,
    );
    final spotter = sherpa_onnx.KeywordSpotter(cfg);
    final stream = spotter.createStream();
    return _RealKwsHandle._(spotter: spotter, stream: stream);
  }

  static bool _bindingsReady = false;

  final sherpa_onnx.KeywordSpotter _spotter;
  final sherpa_onnx.OnlineStream _stream;

  @override
  void acceptWaveform({
    required Float32List samples,
    required int sampleRate,
  }) => _stream.acceptWaveform(samples: samples, sampleRate: sampleRate);

  @override
  bool get isReady => _spotter.isReady(_stream);

  @override
  void decode() => _spotter.decode(_stream);

  @override
  String get keyword => _spotter.getResult(_stream).keyword;

  @override
  void reset() => _spotter.reset(_stream);

  @override
  void free() {
    _stream.free();
    _spotter.free();
  }
}

// ---------------------------------------------------------------------------
// Real factory (asset extraction + spotter creation)
// ---------------------------------------------------------------------------

Future<KwsHandle> _defaultKwsHandleFactory(WakeWordPreset preset) async {
  final paths = await _extractModelAssets();
  final keywordsBuf = await _keywordsBufForPreset(preset);
  return _RealKwsHandle.create(
    encoderPath: paths.encoder,
    decoderPath: paths.decoder,
    joinerPath: paths.joiner,
    tokensPath: paths.tokens,
    keywordsBuf: keywordsBuf,
  );
}

Future<AudioSession> _defaultAudioSession(RecordConfig cfg) async {
  final recorder = AudioRecorder();
  final stream = await recorder.startStream(cfg);
  return AudioSession(
    stream: stream,
    stop: () async {
      await recorder.stop();
      recorder.dispose();
    },
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// sherpa-onnx KWS implementation of [VoiceWakeWordService].
///
/// Foreground-only: [VoiceFab]'s [WidgetsBindingObserver] starts the engine
/// on resume and stops it on background.  The engine holds the microphone
/// while armed; [VoiceFab] calls [stop] before handing the mic to the STT
/// overlay and re-arms via [start] after the overlay closes.
///
/// No access key required — sherpa-onnx is fully offline, Apache-2.0.
class SherpaOnnxVoiceWakeWordService implements VoiceWakeWordService {
  SherpaOnnxVoiceWakeWordService({
    KwsHandleFactory? kwsFactory,
    AudioSessionFactory? audioSessionFactory,
    Future<void> Function(Duration)? sleep,
  }) : _kwsFactory = kwsFactory ?? _defaultKwsHandleFactory,
       _audioSessionFactory = audioSessionFactory ?? _defaultAudioSession,
       _sleep = sleep ?? Future<void>.delayed;

  final KwsHandleFactory _kwsFactory;
  final AudioSessionFactory _audioSessionFactory;
  final Future<void> Function(Duration) _sleep;

  // The native spotter handle is cached across stop()/start() cycles and freed
  // only on a preset switch (in _doStart) or dispose(). Arming/disarming happens
  // many times per session (every STT/TTS phase, app resume, overlay close);
  // rebuilding the 3-model ONNX engine each time was a synchronous FFI init on
  // the UI isolate and stalled route animations. Splitting the handle lifetime
  // from the mic lifetime makes the native init happen once per preset choice.
  KwsHandle? _cachedHandle;
  WakeWordPreset? _cachedHandlePreset;
  Future<void> Function()? _stopAudio;
  StreamSubscription<Uint8List>? _audioSub;
  bool _running = false;
  WakeWordPreset? _activePreset;
  bool _disposed = false;

  final _detectedController = StreamController<WakeWordPreset>.broadcast();
  final _errorController = StreamController<VoiceWakeWordException>.broadcast();

  // Serialises start()/stop()/dispose() so concurrent callers (VoiceFab
  // initState, app-resume, settings BlocListener, overlay-close re-arm) cannot
  // run two overlapping audio sessions. Each public call enqueues behind the
  // previous op; the dedup guard then sees a settled _running/_activePreset.
  Future<void> _opChain = Future<void>.value();

  Future<T> _enqueue<T>(Future<T> Function() op) {
    final next = _opChain.then((_) => op());
    // Keep the chain alive whether or not THIS op throws; the caller still
    // sees the real result/error via `next`.
    _opChain = next.then((_) {}, onError: (_) {});
    return next;
  }

  // ── VoiceWakeWordService interface ──────────────────────────────────────────

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) {
    if (_disposed) {
      return Future<void>.error(
        StateError('SherpaOnnxVoiceWakeWordService has been disposed'),
      );
    }
    return _enqueue(() => _doStart(preset));
  }

  @override
  Future<void> stop() => _disposed ? Future<void>.value() : _enqueue(_doStop);

  @override
  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    _disposed = true;
    // Enqueue dispose as a terminal op so any already-queued start/stop drains
    // first; the controller closes happen inside the queue, preventing a racing
    // start() from writing to a closed stream after disposal.
    return _enqueue(() async {
      await _doStop();
      // _doStop no longer frees the handle — free the cached engine here so the
      // native session is released exactly once at end of life.
      _cachedHandle?.free();
      _cachedHandle = null;
      _cachedHandlePreset = null;
      await _detectedController.close();
      await _errorController.close();
    });
  }

  // ── Private operation bodies (called only from _enqueue) ────────────────────

  Future<void> _doStart(WakeWordPreset preset) async {
    if (_running && _activePreset == preset) return;
    await _doStop();

    if (_cachedHandle != null && _cachedHandlePreset == preset) {
      // Same preset as the cached engine — reuse it without a native re-init.
      // Reset first so any partial hypothesis left from the previous arm is
      // dropped before this session starts feeding audio.
      _cachedHandle!.reset();
    } else {
      // First arm, or the preset changed: free the stale engine (if any) and
      // build a fresh one for this preset.
      _cachedHandle?.free();
      _cachedHandle = null;
      _cachedHandlePreset = null;
      final KwsHandle handle;
      try {
        handle = await _kwsFactory(preset);
      } on VoiceWakeWordException {
        rethrow;
      } catch (e, st) {
        AppLogger.warning(
          'SherpaOnnxVoiceWakeWordService: engine creation failed',
          error: e,
          stackTrace: st,
          category: 'voice',
        );
        throw VoiceWakeWordException(
          VoiceWakeWordErrorKind.engineError,
          'Failed to create keyword spotter: $e',
        );
      }
      _cachedHandle = handle;
      _cachedHandlePreset = preset;
    }

    AudioSession? session;
    VoiceWakeWordException? lastError;
    for (
      var attempt = 1;
      attempt <= VoiceConstants.wakeWordMicAcquireMaxAttempts;
      attempt++
    ) {
      try {
        session = await _audioSessionFactory(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        );
        break;
      } catch (e, st) {
        lastError = VoiceWakeWordException(
          VoiceWakeWordErrorKind.audioError,
          'Failed to start audio capture (attempt $attempt/'
          '${VoiceConstants.wakeWordMicAcquireMaxAttempts}): $e',
        );
        AppLogger.warning(
          'SherpaOnnxVoiceWakeWordService: mic acquire failed '
          '(attempt $attempt/${VoiceConstants.wakeWordMicAcquireMaxAttempts})',
          error: e,
          stackTrace: st,
          category: 'voice',
        );
        if (attempt < VoiceConstants.wakeWordMicAcquireMaxAttempts) {
          await _sleep(VoiceConstants.wakeWordMicAcquireRetryDelay);
        }
      }
    }
    if (session == null) {
      // The engine handle stays cached so the next arm can reuse it without a
      // native re-init; only mic acquisition failed here.
      throw lastError!;
    }
    _stopAudio = session.stop;
    _audioSub = session.stream.listen(
      _onAudioFrame,
      onError: _onAudioError,
      cancelOnError: false,
    );

    _running = true;
    _activePreset = preset;
    AppLogger.info(
      'SherpaOnnxVoiceWakeWordService: started for preset $preset',
      category: 'voice',
    );
  }

  Future<void> _doStop() async {
    if (!_running && _audioSub == null && _stopAudio == null) return;
    // Stops the mic only — the native KWS handle is deliberately retained in
    // _cachedHandle so the next arm reuses it without a costly re-init (it is
    // freed on a preset switch in _doStart or in dispose). Attempt every
    // cleanup step independently so a failure in one does not leave the recorder
    // alive and leaked. State is always cleared so the dedup guard in _doStart
    // sees a settled _running value. The first captured error is reThrown so
    // _enqueue callers (and their .catchError handlers) see real failures
    // instead of silent success.
    Object? firstError;
    StackTrace? firstSt;

    // Null each field BEFORE awaiting/calling so a thrown exception never
    // leaves a stale reference that the early-return guard would then skip on
    // the next _doStop() call.
    try {
      final sub = _audioSub;
      _audioSub = null;
      await sub?.cancel();
    } catch (e, st) {
      firstError = e;
      firstSt = st;
    }

    try {
      final stopFn = _stopAudio;
      _stopAudio = null;
      await stopFn?.call();
    } catch (e, st) {
      firstError ??= e;
      firstSt ??= st;
    }

    // The native handle is intentionally NOT freed here — it is cached for
    // reuse (see _cachedHandle). It is freed only on a preset switch in
    // _doStart or in dispose.

    _running = false;
    _activePreset = null;

    if (firstError != null) {
      AppLogger.warning(
        'SherpaOnnxVoiceWakeWordService: error on stop',
        error: firstError,
        stackTrace: firstSt,
        category: 'voice',
      );
      Error.throwWithStackTrace(firstError, firstSt ?? StackTrace.empty);
    }
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _onAudioFrame(Uint8List pcm16) {
    final handle = _cachedHandle;
    if (handle == null || !_running) return;

    final samples = pcm16ToFloat32(pcm16);
    handle.acceptWaveform(samples: samples, sampleRate: 16000);

    while (handle.isReady) {
      handle.decode();
      final kw = handle.keyword;
      if (kw.isNotEmpty) {
        handle.reset();
        final active = _activePreset;
        if (active != null && active.acceptedPhrases.contains(kw)) {
          AppLogger.debug(
            'SherpaOnnxVoiceWakeWordService: detected "$kw"',
            category: 'voice',
          );
          _detectedController.add(active);
        } else {
          // B3: never drop a firing silently — this is the only signal we have
          // for diagnosing phrase-contract or preset mismatches on device.
          AppLogger.info(
            'SherpaOnnxVoiceWakeWordService: keyword "$kw" ignored '
            '(active preset: $active)',
            category: 'voice',
          );
        }
      }
    }
  }

  void _onAudioError(Object error, StackTrace st) {
    AppLogger.warning(
      'SherpaOnnxVoiceWakeWordService: audio stream error',
      error: error,
      stackTrace: st,
      category: 'voice',
    );
    _errorController.add(
      VoiceWakeWordException(
        VoiceWakeWordErrorKind.audioError,
        'Audio stream error: $error',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Asset helpers (used by the real factory only)
// ---------------------------------------------------------------------------

Future<_ModelPaths> _extractModelAssets() async {
  const base = 'assets/wake_words/kws';
  final encoder = await _extractAsset(
    '$base/encoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
  );
  final decoder = await _extractAsset(
    '$base/decoder-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
  );
  final joiner = await _extractAsset(
    '$base/joiner-epoch-12-avg-2-chunk-16-left-64.int8.onnx',
  );
  final tokens = await _extractAsset('$base/tokens.txt');
  return _ModelPaths(
    encoder: encoder,
    decoder: decoder,
    joiner: joiner,
    tokens: tokens,
  );
}

/// Extracts a bundled asset to `<tmpDir>/sherpa_kws/<filename>`, skipping
/// the write when a file of the correct size already exists.
Future<String> _extractAsset(String assetPath) async {
  final ByteData byteData;
  try {
    byteData = await rootBundle.load(assetPath);
  } catch (e, st) {
    AppLogger.warning(
      'SherpaOnnxVoiceWakeWordService: asset not found: $assetPath',
      error: e,
      stackTrace: st,
      category: 'voice',
    );
    throw VoiceWakeWordException(
      VoiceWakeWordErrorKind.modelLoadError,
      'Asset $assetPath not found: $e',
    );
  }
  if (byteData.lengthInBytes == 0) {
    throw VoiceWakeWordException(
      VoiceWakeWordErrorKind.modelLoadError,
      'Asset $assetPath is empty — replace with a real model.',
    );
  }

  final dir = await getTemporaryDirectory();
  final fileName = assetPath.split('/').last;
  final file = File('${dir.path}/sherpa_kws/$fileName');

  if (!await file.exists() || await file.length() != byteData.lengthInBytes) {
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
  }
  return file.path;
}

Future<String> _keywordsBufForPreset(WakeWordPreset preset) async {
  final contents = await rootBundle.loadString(
    'assets/wake_words/kws/keywords.txt',
  );
  return tokenizedLinesForPreset(contents, preset);
}

// ── Value type ───────────────────────────────────────────────────────────────

class _ModelPaths {
  const _ModelPaths({
    required this.encoder,
    required this.decoder,
    required this.joiner,
    required this.tokens,
  });

  final String encoder;
  final String decoder;
  final String joiner;
  final String tokens;
}
