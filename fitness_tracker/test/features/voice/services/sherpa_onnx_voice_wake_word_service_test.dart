import 'dart:async';
import 'dart:typed_data';

import 'package:fitness_tracker/domain/entities/voice_settings.dart'
    show WakeWordPreset, WakeWordPresetPhrase;
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

/// Fake [KwsHandle]. When [setNextKeyword] is called with a non-empty string,
/// the handle reports [isReady]=true on the next audio frame and returns that
/// keyword once before resetting to idle.
class _FakeKwsHandle implements KwsHandle {
  String? _nextKeyword;
  bool _hasResult = false;
  bool freed = false;
  int resetCount = 0;

  void setNextKeyword(String? kw) {
    _nextKeyword = kw;
    _hasResult = kw != null && kw.isNotEmpty;
  }

  @override
  void acceptWaveform({required Float32List samples, required int sampleRate}) {
    if (_nextKeyword != null && _nextKeyword!.isNotEmpty) _hasResult = true;
  }

  @override
  bool get isReady => _hasResult;

  @override
  void decode() {}

  @override
  String get keyword => _hasResult ? (_nextKeyword ?? '') : '';

  @override
  void reset() {
    _hasResult = false;
    resetCount++;
  }

  @override
  void free() => freed = true;
}

/// Fake audio source built around a [StreamController<Uint8List>].
/// Exposes [push] to inject synthetic PCM frames and [stopCalled] to verify
/// teardown.
class _FakeAudioSource {
  _FakeAudioSource() : _controller = StreamController<Uint8List>.broadcast();

  final StreamController<Uint8List> _controller;
  bool stopCalled = false;

  void push(Uint8List frame) => _controller.add(frame);

  Future<AudioSession> get session async => AudioSession(
    stream: _controller.stream,
    stop: () async {
      stopCalled = true;
      await _controller.close();
    },
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Silence frame — two bytes of PCM16 silence.
final _silentFrame = Uint8List.fromList([0x00, 0x00]);

SherpaOnnxVoiceWakeWordService _makeService({
  required _FakeKwsHandle handle,
  required _FakeAudioSource audioSource,
}) {
  return SherpaOnnxVoiceWakeWordService(
    kwsFactory: (_) async => handle,
    audioSessionFactory: (_) => audioSource.session,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── keyword spotter config (regression: keywordsBufSize must be set) ─────────

  group('buildKeywordSpotterConfig', () {
    test('sets keywordsBufSize to the UTF-8 byte length of the buffer', () {
      final cfg = buildKeywordSpotterConfig(
        encoderPath: 'enc',
        decoderPath: 'dec',
        joinerPath: 'join',
        tokensPath: 'tok',
        keywordsBuf: '▁TRA IN ER',
      );
      // Regression guard: a zero size makes the sherpa-onnx C-api read the
      // buffer as empty and fail with "Please provide either a keywords-file
      // or the keywords-buf".
      expect(cfg.keywordsBufSize, greaterThan(0));
      expect(cfg.keywordsBufSize, utf8.encode(cfg.keywordsBuf).length);
    });

    test('appends a trailing newline when missing', () {
      final cfg = buildKeywordSpotterConfig(
        encoderPath: 'enc',
        decoderPath: 'dec',
        joinerPath: 'join',
        tokensPath: 'tok',
        keywordsBuf: '▁TH OM AS',
      );
      expect(cfg.keywordsBuf.endsWith('\n'), isTrue);
      expect(cfg.keywordsBufSize, utf8.encode(cfg.keywordsBuf).length);
    });

    test('does not double the trailing newline', () {
      final cfg = buildKeywordSpotterConfig(
        encoderPath: 'enc',
        decoderPath: 'dec',
        joinerPath: 'join',
        tokensPath: 'tok',
        keywordsBuf: '▁SA MO ▁LE V S K I\n',
      );
      expect(cfg.keywordsBuf.endsWith('\n\n'), isFalse);
      expect(cfg.keywordsBufSize, utf8.encode(cfg.keywordsBuf).length);
    });
  });

  // ── isRunning lifecycle ─────────────────────────────────────────────────────

  group('isRunning lifecycle', () {
    late _FakeKwsHandle handle;
    late _FakeAudioSource audioSource;
    late SherpaOnnxVoiceWakeWordService svc;

    setUp(() {
      handle = _FakeKwsHandle();
      audioSource = _FakeAudioSource();
      svc = _makeService(handle: handle, audioSource: audioSource);
    });

    tearDown(() async => svc.dispose());

    test('false before start', () {
      expect(svc.isRunning, isFalse);
    });

    test('true after start', () async {
      await svc.start(WakeWordPreset.trainer);
      expect(svc.isRunning, isTrue);
    });

    test('false after stop', () async {
      await svc.start(WakeWordPreset.trainer);
      await svc.stop();
      expect(svc.isRunning, isFalse);
    });

    test('false after dispose', () async {
      await svc.start(WakeWordPreset.trainer);
      await svc.dispose();
      expect(svc.isRunning, isFalse);
    });
  });

  // ── Detection ──────────────────────────────────────────────────────────────

  group('detection', () {
    test(
      'matching keyword on audio frame emits preset on onWakeWordDetected',
      () async {
        final handle = _FakeKwsHandle();
        final audioSource = _FakeAudioSource();
        final svc = _makeService(handle: handle, audioSource: audioSource);

        final emitted = <WakeWordPreset>[];
        final sub = svc.onWakeWordDetected.listen(emitted.add);

        await svc.start(WakeWordPreset.trainer);
        // wakePhrase is what sherpa returns after de-tokenising the BPE tokens
        handle.setNextKeyword(WakeWordPreset.trainer.wakePhrase);
        audioSource.push(_silentFrame);

        await Future<void>.delayed(Duration.zero);

        expect(emitted, [WakeWordPreset.trainer]);
        expect(handle.resetCount, 1);

        await sub.cancel();
        await svc.dispose();
      },
    );

    test('non-matching keyword (wrong preset phrase) → no emission', () async {
      final handle = _FakeKwsHandle();
      final audioSource = _FakeAudioSource();
      final svc = _makeService(handle: handle, audioSource: audioSource);

      final emitted = <WakeWordPreset>[];
      final sub = svc.onWakeWordDetected.listen(emitted.add);

      await svc.start(WakeWordPreset.trainer);
      // Armed for trainer but the spotter returns samoLevski phrase
      handle.setNextKeyword(WakeWordPreset.samoLevski.wakePhrase);
      audioSource.push(_silentFrame);

      await Future<void>.delayed(Duration.zero);

      expect(emitted, isEmpty);

      await sub.cancel();
      await svc.dispose();
    });

    test('no audio frame → no emission', () async {
      final handle = _FakeKwsHandle();
      final audioSource = _FakeAudioSource();
      final svc = _makeService(handle: handle, audioSource: audioSource);

      final emitted = <WakeWordPreset>[];
      final sub = svc.onWakeWordDetected.listen(emitted.add);

      await svc.start(WakeWordPreset.thomas);

      await Future<void>.delayed(Duration.zero);
      expect(emitted, isEmpty);

      await sub.cancel();
      await svc.dispose();
    });
  });

  // ── Idempotent / restart behaviour ────────────────────────────────────────

  group('start semantics', () {
    test('start(samePreset) twice does not rebuild the engine', () async {
      int factoryCalls = 0;
      final audioSource = _FakeAudioSource();
      final svc = SherpaOnnxVoiceWakeWordService(
        kwsFactory: (_) async {
          factoryCalls++;
          return _FakeKwsHandle();
        },
        audioSessionFactory: (_) => audioSource.session,
      );

      await svc.start(WakeWordPreset.trainer);
      await svc.start(WakeWordPreset.trainer); // idempotent
      expect(factoryCalls, 1);

      await svc.dispose();
    });

    test(
      'start(otherPreset) tears down old engine and starts new one',
      () async {
        int factoryCalls = 0;
        int audioCalls = 0;
        final audio1 = _FakeAudioSource();
        final audio2 = _FakeAudioSource();
        final svc = SherpaOnnxVoiceWakeWordService(
          kwsFactory: (_) async {
            factoryCalls++;
            return _FakeKwsHandle();
          },
          audioSessionFactory: (_) {
            audioCalls++;
            return audioCalls == 1 ? audio1.session : audio2.session;
          },
        );

        await svc.start(WakeWordPreset.trainer);
        expect(factoryCalls, 1);

        await svc.start(WakeWordPreset.thomas);
        expect(factoryCalls, 2);
        expect(svc.isRunning, isTrue);

        await svc.dispose();
      },
    );
  });

  // ── Failure mapping ────────────────────────────────────────────────────────

  group('failure mapping', () {
    test(
      'factory throws VoiceWakeWordException(modelLoadError) → rethrown as-is',
      () async {
        final svc = SherpaOnnxVoiceWakeWordService(
          kwsFactory: (_) async => throw const VoiceWakeWordException(
            VoiceWakeWordErrorKind.modelLoadError,
            'test: asset missing',
          ),
          audioSessionFactory: (_) async =>
              AudioSession(stream: const Stream.empty(), stop: () async {}),
        );

        await expectLater(
          svc.start(WakeWordPreset.trainer),
          throwsA(
            isA<VoiceWakeWordException>().having(
              (e) => e.kind,
              'kind',
              VoiceWakeWordErrorKind.modelLoadError,
            ),
          ),
        );

        await svc.dispose();
      },
    );

    test(
      'factory throws generic exception → wrapped as VoiceWakeWordException(engineError)',
      () async {
        final svc = SherpaOnnxVoiceWakeWordService(
          kwsFactory: (_) async => throw Exception('native init failed'),
          audioSessionFactory: (_) async =>
              AudioSession(stream: const Stream.empty(), stop: () async {}),
        );

        await expectLater(
          svc.start(WakeWordPreset.trainer),
          throwsA(
            isA<VoiceWakeWordException>().having(
              (e) => e.kind,
              'kind',
              VoiceWakeWordErrorKind.engineError,
            ),
          ),
        );

        await svc.dispose();
      },
    );

    test(
      'audio session factory throws → VoiceWakeWordException(audioError)',
      () async {
        final svc = SherpaOnnxVoiceWakeWordService(
          kwsFactory: (_) async => _FakeKwsHandle(),
          audioSessionFactory: (_) async => throw Exception('mic unavailable'),
        );

        await expectLater(
          svc.start(WakeWordPreset.trainer),
          throwsA(
            isA<VoiceWakeWordException>().having(
              (e) => e.kind,
              'kind',
              VoiceWakeWordErrorKind.audioError,
            ),
          ),
        );

        await svc.dispose();
      },
    );
  });

  // ── stop() teardown ────────────────────────────────────────────────────────

  group('stop teardown', () {
    test('stop calls audio stop and frees the handle', () async {
      final handle = _FakeKwsHandle();
      final audioSource = _FakeAudioSource();
      final svc = _makeService(handle: handle, audioSource: audioSource);

      await svc.start(WakeWordPreset.thomas);
      await svc.stop();

      expect(audioSource.stopCalled, isTrue);
      expect(handle.freed, isTrue);
    });

    test('stop is idempotent', () async {
      final handle = _FakeKwsHandle();
      final audioSource = _FakeAudioSource();
      final svc = _makeService(handle: handle, audioSource: audioSource);

      await svc.start(WakeWordPreset.thomas);
      await svc.stop();
      await svc.stop(); // must not throw
      expect(svc.isRunning, isFalse);

      await svc.dispose();
    });
  });
}
