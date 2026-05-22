import 'dart:async';

import 'package:fitness_tracker/features/voice/data/services/flutter_tts_voice_tts_service.dart';
import 'package:fitness_tracker/domain/services/voice_tts_service.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mock
// ---------------------------------------------------------------------------

class MockFlutterTts extends Mock implements FlutterTts {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets up a [FlutterTtsVoiceTtsService] with a [MockFlutterTts] and
/// captures the completion / error handlers so tests can fire them manually.
class _TtsHarness {
  final MockFlutterTts tts = MockFlutterTts();
  VoidCallback? completionHandler;
  Function(dynamic)? errorHandler;

  late final FlutterTtsVoiceTtsService service;

  _TtsHarness() {
    // Capture the handler references when they are registered via initialize().
    when(() => tts.setCompletionHandler(any())).thenAnswer((invocation) {
      completionHandler = invocation.positionalArguments[0] as VoidCallback;
    });
    when(() => tts.setErrorHandler(any())).thenAnswer((invocation) {
      errorHandler = invocation.positionalArguments[0] as Function(dynamic);
    });

    // Stub all Future-returning plugin calls used by the service.
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setVolume(any())).thenAnswer((_) async => 1);
    when(() => tts.setSpeechRate(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);

    service = FlutterTtsVoiceTtsService(tts);
  }

  /// Simulates the TTS engine signalling that speech has completed.
  void fireCompletion() => completionHandler?.call();

  /// Simulates the TTS engine signalling an error during speech.
  void fireError([dynamic message = 'engine error']) =>
      errorHandler?.call(message);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FlutterTtsVoiceTtsService', () {
    // ── Interface contract ──────────────────────────────────────────────────

    test('implements VoiceTtsService', () {
      final h = _TtsHarness();
      expect(h.service, isA<VoiceTtsService>());
    });

    // ── initialize ──────────────────────────────────────────────────────────

    test('initialize registers handlers and configures language', () async {
      final h = _TtsHarness();
      await h.service.initialize(volume: 0.8, speechRate: 0.5);

      verify(() => h.tts.setCompletionHandler(any())).called(1);
      verify(() => h.tts.setErrorHandler(any())).called(1);
      verify(() => h.tts.setLanguage('en-US')).called(1);
    });

    test('initialize is idempotent — plugin calls happen only once', () async {
      final h = _TtsHarness();
      await h.service.initialize();
      await h.service.initialize(); // second call should be a no-op

      verify(() => h.tts.setLanguage(any())).called(1);
    });

    // ── speak / Completer lifecycle ─────────────────────────────────────────

    test('speak() completes when TTS engine fires completion handler',
        () async {
      final h = _TtsHarness();
      await h.service.initialize();

      final speakFuture = h.service.speak('Hello trainer');

      // Let the speak() call begin.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Simulate TTS engine signalling it has finished.
      h.fireCompletion();

      await expectLater(speakFuture, completes);
      verify(() => h.tts.speak('Hello trainer')).called(1);
    });

    test('speak() completes when TTS engine fires error handler', () async {
      final h = _TtsHarness();
      await h.service.initialize();

      final speakFuture = h.service.speak('Hello');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Simulate an engine error — the future should still complete
      // (not throw), so the bloc never hangs waiting for speech.
      h.fireError('synthesis error');

      await expectLater(speakFuture, completes);
    });

    test('speak() on empty string returns immediately without calling plugin',
        () async {
      final h = _TtsHarness();
      await h.service.initialize();

      await h.service.speak('');

      verifyNever(() => h.tts.speak(any()));
    });

    // ── stop ───────────────────────────────────────────────────────────────

    test('stop() completes any in-flight speak()', () async {
      final h = _TtsHarness();
      await h.service.initialize();

      final speakFuture = h.service.speak('Long sentence...');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      // Stop before the engine fires completion.
      await h.service.stop();

      await expectLater(speakFuture, completes);
      verify(() => h.tts.stop()).called(greaterThanOrEqualTo(1));
    });

    test('stop() is safe to call when nothing is playing', () async {
      final h = _TtsHarness();
      await h.service.initialize();

      // Should not throw.
      await expectLater(h.service.stop(), completes);
    });

    // ── setVolume / setSpeechRate ───────────────────────────────────────────

    test('setVolume clamps to [0.0, 1.0]', () async {
      final h = _TtsHarness();
      await h.service.initialize();

      await h.service.setVolume(1.5); // too high
      await h.service.setVolume(-0.5); // too low

      final captured =
          verify(() => h.tts.setVolume(captureAny())).captured.cast<double>();
      for (final v in captured) {
        expect(v, inInclusiveRange(0.0, 1.0),
            reason: 'volume must be clamped to [0, 1], got $v');
      }
    });

    test('setSpeechRate clamps to plugin-safe range', () async {
      final h = _TtsHarness();
      await h.service.initialize();

      await h.service.setSpeechRate(999.0); // above max
      await h.service.setSpeechRate(-1.0); // below min

      final captured = verify(() => h.tts.setSpeechRate(captureAny()))
          .captured
          .cast<double>();
      for (final v in captured) {
        expect(v, greaterThanOrEqualTo(0.0),
            reason: 'rate must be >= 0, got $v');
      }
    });

    // ── dispose ────────────────────────────────────────────────────────────

    test('dispose() stops any in-flight speech and calls plugin stop', () async {
      final h = _TtsHarness();
      await h.service.initialize();
      unawaited(h.service.speak('something'));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      await h.service.dispose();

      verify(() => h.tts.stop()).called(greaterThanOrEqualTo(1));
    });
  });
}
