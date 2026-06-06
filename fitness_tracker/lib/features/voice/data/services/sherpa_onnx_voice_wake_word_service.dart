import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

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
    keywordsScore: 1.0,
    keywordsThreshold: 0.25,
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
  }) : _kwsFactory = kwsFactory ?? _defaultKwsHandleFactory,
       _audioSessionFactory = audioSessionFactory ?? _defaultAudioSession;

  final KwsHandleFactory _kwsFactory;
  final AudioSessionFactory _audioSessionFactory;

  KwsHandle? _handle;
  Future<void> Function()? _stopAudio;
  StreamSubscription<Uint8List>? _audioSub;
  bool _running = false;
  WakeWordPreset? _activePreset;

  final _detectedController = StreamController<WakeWordPreset>.broadcast();
  final _errorController = StreamController<VoiceWakeWordException>.broadcast();

  // ── VoiceWakeWordService interface ──────────────────────────────────────────

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async {
    if (_running && _activePreset == preset) return;
    await stop();

    KwsHandle handle;
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

    try {
      final session = await _audioSessionFactory(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ),
      );
      _stopAudio = session.stop;
      _audioSub = session.stream.listen(
        _onAudioFrame,
        onError: _onAudioError,
        cancelOnError: false,
      );
    } catch (e, st) {
      AppLogger.warning(
        'SherpaOnnxVoiceWakeWordService: audio capture failed',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      handle.free();
      throw VoiceWakeWordException(
        VoiceWakeWordErrorKind.audioError,
        'Failed to start audio capture: $e',
      );
    }

    _handle = handle;
    _running = true;
    _activePreset = preset;
    AppLogger.info(
      'SherpaOnnxVoiceWakeWordService: started for preset $preset',
      category: 'voice',
    );
  }

  @override
  Future<void> stop() async {
    if (!_running && _handle == null) return;
    try {
      await _audioSub?.cancel();
      _audioSub = null;
      await _stopAudio?.call();
      _stopAudio = null;
      _handle?.free();
      _handle = null;
    } catch (e, st) {
      AppLogger.warning(
        'SherpaOnnxVoiceWakeWordService: error on stop',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
    } finally {
      _running = false;
      _activePreset = null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _detectedController.close();
    await _errorController.close();
  }

  // ── Internal ────────────────────────────────────────────────────────────────

  void _onAudioFrame(Uint8List pcm16) {
    final handle = _handle;
    if (handle == null || !_running) return;

    final samples = pcm16ToFloat32(pcm16);
    handle.acceptWaveform(samples: samples, sampleRate: 16000);

    while (handle.isReady) {
      handle.decode();
      final kw = handle.keyword;
      if (kw.isNotEmpty) {
        handle.reset();
        final active = _activePreset;
        if (active != null && kw == active.wakePhrase) {
          AppLogger.debug(
            'SherpaOnnxVoiceWakeWordService: detected "$kw"',
            category: 'voice',
          );
          _detectedController.add(active);
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
  return tokenizedLineForPreset(contents, preset);
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
