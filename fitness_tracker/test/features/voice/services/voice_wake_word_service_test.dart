import 'dart:async';

import 'package:fitness_tracker/domain/entities/voice_settings.dart'
    show WakeWordPreset, WakeWordPresetLabel;
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// In-test fake — a stream-controllable VoiceWakeWordService
// ---------------------------------------------------------------------------

/// Pure-Dart test double for [VoiceWakeWordService].
///
/// Lets tests drive the detection stream and error stream without any
/// Porcupine native binaries. The same pattern is used by [VoiceFab]
/// and [VoiceOverlayPage] in widget tests.
class _FakeWakeWordService implements VoiceWakeWordService {
  final StreamController<WakeWordPreset> _detectedController =
      StreamController<WakeWordPreset>.broadcast();
  final StreamController<VoiceWakeWordException> _errorController =
      StreamController<VoiceWakeWordException>.broadcast();

  bool _running = false;

  // ── Helpers for driving the fake ─────────────────────────────────────────

  void triggerDetection(WakeWordPreset preset) =>
      _detectedController.add(preset);

  void triggerError(VoiceWakeWordException ex) => _errorController.add(ex);

  // ── VoiceWakeWordService interface ────────────────────────────────────────

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async {
    _running = true;
  }

  @override
  Future<void> stop() async {
    _running = false;
  }

  @override
  Future<void> dispose() async {
    await _detectedController.close();
    await _errorController.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── VoiceWakeWordErrorKind ──────────────────────────────────────────────

  group('VoiceWakeWordErrorKind', () {
    test('enum has all expected values', () {
      expect(
        VoiceWakeWordErrorKind.values,
        containsAll(<VoiceWakeWordErrorKind>[
          VoiceWakeWordErrorKind.noAccessKey,
          VoiceWakeWordErrorKind.modelNotFound,
          VoiceWakeWordErrorKind.engineError,
          VoiceWakeWordErrorKind.audioError,
        ]),
      );
    });
  });

  // ── VoiceWakeWordException ──────────────────────────────────────────────

  group('VoiceWakeWordException', () {
    test('toString includes kind', () {
      const ex = VoiceWakeWordException(VoiceWakeWordErrorKind.noAccessKey);
      expect(ex.toString(), contains('noAccessKey'));
    });

    test('toString includes optional message when provided', () {
      const ex = VoiceWakeWordException(
        VoiceWakeWordErrorKind.modelNotFound,
        'trainer_android.ppn is zero bytes',
      );
      expect(ex.toString(), contains('modelNotFound'));
      expect(ex.toString(), contains('trainer_android.ppn'));
    });

    test('message is null by default', () {
      const ex = VoiceWakeWordException(VoiceWakeWordErrorKind.engineError);
      expect(ex.message, isNull);
    });

    test(
      'non-const instances are distinct objects (each throw is a new event)',
      () {
        // Without 'const', Dart allocates a new instance on every call.
        final a = VoiceWakeWordException(
          VoiceWakeWordErrorKind.audioError,
          'a',
        );
        final b = VoiceWakeWordException(
          VoiceWakeWordErrorKind.audioError,
          'a',
        );
        expect(a, isNot(same(b)));
      },
    );
  });

  // ── _FakeWakeWordService (stream contract) ─────────────────────────────

  group('VoiceWakeWordService stream contract (via fake)', () {
    late _FakeWakeWordService service;

    setUp(() => service = _FakeWakeWordService());
    tearDown(() => service.dispose());

    test('isRunning starts as false', () {
      expect(service.isRunning, isFalse);
    });

    test('start() sets isRunning to true', () async {
      await service.start(WakeWordPreset.samoLevski);
      expect(service.isRunning, isTrue);
    });

    test('stop() sets isRunning to false', () async {
      await service.start(WakeWordPreset.trainer);
      await service.stop();
      expect(service.isRunning, isFalse);
    });

    test('onWakeWordDetected emits the preset that was detected', () async {
      final detected = <WakeWordPreset>[];
      final sub = service.onWakeWordDetected.listen(detected.add);

      service.triggerDetection(WakeWordPreset.samoLevski);
      service.triggerDetection(WakeWordPreset.trainer);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(detected, <WakeWordPreset>[
        WakeWordPreset.samoLevski,
        WakeWordPreset.trainer,
      ]);

      await sub.cancel();
    });

    test('onError emits VoiceWakeWordException events', () async {
      const ex = VoiceWakeWordException(
        VoiceWakeWordErrorKind.engineError,
        'native crash',
      );

      final errors = <VoiceWakeWordException>[];
      final sub = service.onError.listen(errors.add);

      service.triggerError(ex);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(errors.length, 1);
      expect(errors.first.kind, VoiceWakeWordErrorKind.engineError);

      await sub.cancel();
    });

    test(
      'onWakeWordDetected is a broadcast stream — multiple listeners OK',
      () async {
        final first = <WakeWordPreset>[];
        final second = <WakeWordPreset>[];

        final s1 = service.onWakeWordDetected.listen(first.add);
        final s2 = service.onWakeWordDetected.listen(second.add);

        service.triggerDetection(WakeWordPreset.thomas);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(first, <WakeWordPreset>[WakeWordPreset.thomas]);
        expect(second, <WakeWordPreset>[WakeWordPreset.thomas]);

        await s1.cancel();
        await s2.cancel();
      },
    );

    test('start() is idempotent for same preset', () async {
      await service.start(WakeWordPreset.samoLevski);
      await service.start(WakeWordPreset.samoLevski); // should not throw
      expect(service.isRunning, isTrue);
    });

    test('stop() before start() does not throw', () async {
      await expectLater(service.stop(), completes);
    });
  });

  // ── WakeWordPreset integration ─────────────────────────────────────────

  group('WakeWordPreset', () {
    test('has expected preset values', () {
      expect(WakeWordPreset.values, hasLength(3));
      expect(
        WakeWordPreset.values,
        containsAll(<WakeWordPreset>[
          WakeWordPreset.samoLevski,
          WakeWordPreset.trainer,
          WakeWordPreset.thomas,
        ]),
      );
    });

    test('each preset has a non-empty displayName', () {
      for (final preset in WakeWordPreset.values) {
        expect(preset.displayName, isNotEmpty);
      }
    });
  });
}
