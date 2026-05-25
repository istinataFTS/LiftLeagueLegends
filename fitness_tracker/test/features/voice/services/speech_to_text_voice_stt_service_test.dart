import 'dart:async';

import 'package:fitness_tracker/core/constants/voice_constants.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/features/voice/data/services/speech_to_text_voice_stt_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' show SpeechListenOptions;

// ---------------------------------------------------------------------------
// Test double implementing SpeechToTextPort
// ---------------------------------------------------------------------------

/// Controllable fake implementing [SpeechToTextPort].
///
/// Stores the callbacks registered by [SpeechToTextVoiceSttService] so test
/// code can fire them at will, simulating the full range of engine behaviour
/// without any platform-channel involvement.
///
/// Note: [stt.SpeechToText] uses a factory constructor (singleton), making
/// subclassing impossible. This fake implements the [SpeechToTextPort]
/// interface instead.
class _FakeSpeechToTextPort implements SpeechToTextPort {
  void Function(SpeechRecognitionError)? _errorListener;
  void Function(String)? _statusListener;
  void Function(SpeechRecognitionResult)? _resultListener;

  /// Number of times [listen] was called across the lifetime of this fake.
  int listenCallCount = 0;

  @override
  Future<bool> initialize({
    void Function(SpeechRecognitionError)? onError,
    void Function(String)? onStatus,
  }) async {
    _errorListener = onError;
    _statusListener = onStatus;
    return true;
  }

  @override
  bool get isAvailable => true;

  @override
  bool get isListening => _resultListener != null;

  @override
  Future<dynamic> listen({
    void Function(SpeechRecognitionResult)? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechListenOptions? listenOptions,
  }) async {
    listenCallCount++;
    _resultListener = onResult;
    return true;
  }

  @override
  Future<void> stop() async => _resultListener = null;

  @override
  Future<void> cancel() async => _resultListener = null;

  // ── Simulation helpers ────────────────────────────────────────────────────

  void firePartial(String text) {
    _resultListener?.call(
      SpeechRecognitionResult([SpeechRecognitionWords(text, null, 1.0)], false),
    );
  }

  void fireFinal(String text) {
    _resultListener?.call(
      SpeechRecognitionResult([SpeechRecognitionWords(text, null, 1.0)], true),
    );
    _resultListener = null;
  }

  void fireError(String errorCode, {bool permanent = false}) {
    _errorListener?.call(SpeechRecognitionError(errorCode, permanent));
  }

  void fireStatus(String status) {
    _statusListener?.call(status);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<SpeechToTextVoiceSttService> _buildService(
  _FakeSpeechToTextPort fake,
) async {
  final service = SpeechToTextVoiceSttService(fake);
  await service.initialize();
  return service;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── VoiceSttResult ─────────────────────────────────────────────────────────

  group('VoiceSttResult', () {
    test('equality is value-based', () {
      const a = VoiceSttResult(transcript: 'hello', isFinal: true);
      const b = VoiceSttResult(transcript: 'hello', isFinal: true);
      expect(a, equals(b));
    });

    test('differs when transcript changes', () {
      const a = VoiceSttResult(transcript: 'hello', isFinal: true);
      const b = VoiceSttResult(transcript: 'world', isFinal: true);
      expect(a, isNot(equals(b)));
    });

    test('differs when isFinal changes', () {
      const a = VoiceSttResult(transcript: 'hello', isFinal: false);
      const b = VoiceSttResult(transcript: 'hello', isFinal: true);
      expect(a, isNot(equals(b)));
    });

    test('isFinal false means partial result', () {
      const r = VoiceSttResult(transcript: 'bench', isFinal: false);
      expect(r.isFinal, isFalse);
      expect(r.transcript, 'bench');
    });
  });

  // ── VoiceSttErrorKind ─────────────────────────────────────────────────────

  group('VoiceSttErrorKind', () {
    test('enum has all expected values', () {
      expect(
        VoiceSttErrorKind.values,
        containsAll(<VoiceSttErrorKind>[
          VoiceSttErrorKind.permissionDenied,
          VoiceSttErrorKind.permissionPermanentlyDenied,
          VoiceSttErrorKind.unavailable,
          VoiceSttErrorKind.noSpeech,
          VoiceSttErrorKind.network,
          VoiceSttErrorKind.unknown,
        ]),
      );
    });
  });

  // ── VoiceSttException ─────────────────────────────────────────────────────

  group('VoiceSttException', () {
    test('toString includes kind and message', () {
      const ex = VoiceSttException(VoiceSttErrorKind.network, 'error_network');
      expect(ex.toString(), contains('network'));
    });

    test('message is optional', () {
      const ex = VoiceSttException(VoiceSttErrorKind.noSpeech);
      expect(ex.message, isNull);
    });
  });

  // ── SpeechToTextVoiceSttService — interface conformance ───────────────────

  group('SpeechToTextVoiceSttService — interface', () {
    test('implements VoiceSttService', () {
      final service = SpeechToTextVoiceSttService();
      expect(service, isA<VoiceSttService>());
    });

    test('isAvailable returns false before initialization', () {
      final service = SpeechToTextVoiceSttService();
      expect(service.isAvailable, isFalse);
    });

    test('isListening returns false before any listen() call', () {
      final service = SpeechToTextVoiceSttService();
      expect(service.isListening, isFalse);
    });

    test('cancel() completes without error even when not listening', () async {
      final service = SpeechToTextVoiceSttService();
      await expectLater(service.cancel(), completes);
    });

    test('dispose() completes without error when never initialized', () async {
      final service = SpeechToTextVoiceSttService();
      await expectLater(service.dispose(), completes);
    });
  });

  // ── Error classification (pure static helpers) ────────────────────────────

  group('classifyErrorCode', () {
    final mapping = <String, VoiceSttErrorKind>{
      'error_permission': VoiceSttErrorKind.permissionDenied,
      'error_audio': VoiceSttErrorKind.permissionDenied,
      'error_no_match': VoiceSttErrorKind.noSpeech,
      'error_speech_timeout': VoiceSttErrorKind.noSpeech,
      'error_network': VoiceSttErrorKind.network,
      'error_network_timeout': VoiceSttErrorKind.network,
      'error_recognizer_busy': VoiceSttErrorKind.unavailable,
      'error_client': VoiceSttErrorKind.unavailable,
    };

    test('matches the documented mapping table', () {
      for (final entry in mapping.entries) {
        expect(
          SpeechToTextVoiceSttService.classifyErrorCode(entry.key),
          entry.value,
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });

    test('falls through to unknown for unrecognised codes', () {
      const unknownCodes = <String>[
        'error_something_new',
        '',
        'totally_unexpected',
      ];
      for (final code in unknownCodes) {
        expect(
          SpeechToTextVoiceSttService.classifyErrorCode(code),
          VoiceSttErrorKind.unknown,
          reason: '$code should classify as unknown',
        );
      }
    });
  });

  // ── Graceful-silence helpers ──────────────────────────────────────────────

  group('isGracefulSilence', () {
    test('noSpeech is the only kind classified as graceful silence', () {
      for (final kind in VoiceSttErrorKind.values) {
        final graceful = SpeechToTextVoiceSttService.isGracefulSilence(kind);
        if (kind == VoiceSttErrorKind.noSpeech) {
          expect(graceful, isTrue, reason: '$kind must be graceful silence');
        } else {
          expect(graceful, isFalse, reason: '$kind must NOT be graceful');
        }
      }
    });

    test('Android no-speech codes round-trip into graceful silence', () {
      const noSpeechCodes = <String>['error_no_match', 'error_speech_timeout'];
      for (final code in noSpeechCodes) {
        final kind = SpeechToTextVoiceSttService.classifyErrorCode(code);
        expect(
          SpeechToTextVoiceSttService.isGracefulSilence(kind),
          isTrue,
          reason: '$code must round-trip into graceful silence',
        );
      }
    });

    test('genuinely fatal codes do NOT classify as graceful silence', () {
      const fatalCodes = <String>[
        'error_permission',
        'error_audio',
        'error_network',
        'error_network_timeout',
        'error_recognizer_busy',
        'error_client',
      ];
      for (final code in fatalCodes) {
        final kind = SpeechToTextVoiceSttService.classifyErrorCode(code);
        expect(
          SpeechToTextVoiceSttService.isGracefulSilence(kind),
          isFalse,
          reason: '$code must remain a real error',
        );
      }
    });
  });

  // ── promoteOnSilence ──────────────────────────────────────────────────────

  group('promoteOnSilence', () {
    test('returns the partial when non-empty', () {
      expect(
        SpeechToTextVoiceSttService.promoteOnSilence('bench press'),
        'bench press',
      );
    });

    test('returns null when partial is empty', () {
      expect(SpeechToTextVoiceSttService.promoteOnSilence(''), isNull);
    });
  });

  // ── shouldRestartOnNoMatch ────────────────────────────────────────────────

  group('shouldRestartOnNoMatch', () {
    const max = VoiceConstants.sttMaxNoMatchRestarts;

    test('true when no partial and restartCount below max', () {
      expect(
        SpeechToTextVoiceSttService.shouldRestartOnNoMatch('', 0, max),
        isTrue,
      );
      expect(
        SpeechToTextVoiceSttService.shouldRestartOnNoMatch('', max - 1, max),
        isTrue,
      );
    });

    test('false when restartCount equals max', () {
      expect(
        SpeechToTextVoiceSttService.shouldRestartOnNoMatch('', max, max),
        isFalse,
      );
    });

    test('false when partial is non-empty (promote instead of restart)', () {
      expect(
        SpeechToTextVoiceSttService.shouldRestartOnNoMatch('something', 0, max),
        isFalse,
      );
    });
  });

  // ── Session behaviour driven through _FakeSpeechToTextPort ───────────────

  group('listen() — session behaviour', () {
    late _FakeSpeechToTextPort fake;
    late SpeechToTextVoiceSttService service;

    setUp(() async {
      fake = _FakeSpeechToTextPort();
      service = await _buildService(fake);
    });

    tearDown(() async {
      await service.dispose();
    });

    // ── Engine-confirmed final result ──────────────────────────────────────

    test(
      'engine final result emits final VoiceSttResult and closes stream',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        final completer = Completer<void>();
        stream.listen(events.add, onDone: completer.complete);

        fake.firePartial('bench press 80');
        fake.fireFinal('bench press 80 by 10');
        await completer.future;

        expect(events.length, 2);
        expect(events[0].isFinal, isFalse);
        expect(events[0].transcript, 'bench press 80');
        expect(events[1].isFinal, isTrue);
        expect(events[1].transcript, 'bench press 80 by 10');
      },
    );

    // ── Partial-promotion on no_match ─────────────────────────────────────

    test(
      'error_no_match after partial → emits synthetic final with partial text',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        VoiceSttException? caughtError;
        final completer = Completer<void>();
        stream.listen(
          events.add,
          onError: (Object e) {
            if (e is VoiceSttException) caughtError = e;
          },
          onDone: completer.complete,
        );

        fake.firePartial('log bench press');
        fake.firePartial('log bench press 80');
        fake.fireError('error_no_match');
        await completer.future;

        expect(
          caughtError,
          isNull,
          reason: 'noSpeech must never reach caller as error',
        );
        expect(events.length, 3);
        expect(events[2].isFinal, isTrue);
        expect(events[2].transcript, 'log bench press 80');
      },
    );

    // ── Restart on no_match with no partial ───────────────────────────────

    test('error_no_match with no partial, restarts < max → stream stays open '
        'and plugin.listen() is invoked again', () async {
      final stream = service.listen();
      final completer = Completer<void>();
      var doneCount = 0;
      stream.listen(
        (_) {},
        onDone: () {
          doneCount++;
          completer.complete();
        },
      );

      expect(fake.listenCallCount, 1);
      fake.fireError('error_no_match');
      await Future<void>.delayed(Duration.zero);

      expect(doneCount, 0, reason: 'stream must remain open after restart');
      expect(
        fake.listenCallCount,
        2,
        reason: 'plugin.listen must be called again',
      );

      // Second restart.
      fake.fireError('error_no_match');
      await Future<void>.delayed(Duration.zero);
      expect(fake.listenCallCount, 3);

      // Third no_match exhausts the budget — stream should close.
      fake.fireError('error_no_match');
      await completer.future;

      expect(doneCount, 1);
    });

    test(
      'error_no_match with no partial, budget exhausted → closes gracefully without error',
      () async {
        final stream = service.listen();
        final errors = <Object>[];
        final completer = Completer<void>();
        stream.listen(
          (_) {},
          onError: errors.add,
          onDone: completer.complete,
          cancelOnError: false,
        );

        // Exhaust restart budget: initial + sttMaxNoMatchRestarts fires.
        for (var i = 0; i <= VoiceConstants.sttMaxNoMatchRestarts; i++) {
          fake.fireError('error_no_match');
          await Future<void>.delayed(Duration.zero);
        }

        await completer.future;
        expect(errors, isEmpty, reason: 'graceful close must not emit errors');
      },
    );

    // ── Promotion on status='done' ────────────────────────────────────────

    test(
      'status=done with non-empty partial and no prior final → emits synthetic final',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        final completer = Completer<void>();
        stream.listen(events.add, onDone: completer.complete);

        fake.firePartial('log squat 100');
        fake.fireStatus('done');
        await completer.future;

        expect(events.last.isFinal, isTrue);
        expect(events.last.transcript, 'log squat 100');
      },
    );

    test(
      'status=done with empty partial → closes without emitting final',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        final completer = Completer<void>();
        stream.listen(events.add, onDone: completer.complete);

        fake.fireStatus('done');
        await completer.future;

        expect(events.where((e) => e.isFinal), isEmpty);
      },
    );

    test(
      'status=done after engine-confirmed final → does not double-emit',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        final completer = Completer<void>();
        stream.listen(events.add, onDone: completer.complete);

        fake.fireFinal('bench 80 by 10');
        // Engine-confirmed final closes the session, so status='done' must
        // be ignored.
        fake.fireStatus('done');
        await completer.future;

        final finals = events.where((e) => e.isFinal).toList();
        expect(finals.length, 1);
        expect(finals[0].transcript, 'bench 80 by 10');
      },
    );

    // ── Real error regression guards ──────────────────────────────────────

    test(
      'error_network → emits VoiceSttException(network) and closes',
      () async {
        final stream = service.listen();
        VoiceSttException? caughtError;
        final completer = Completer<void>();
        stream.listen(
          (_) {},
          onError: (Object e) {
            if (e is VoiceSttException) caughtError = e;
          },
          onDone: completer.complete,
          cancelOnError: false,
        );

        fake.fireError('error_network');
        await completer.future;

        expect(caughtError, isNotNull);
        expect(caughtError!.kind, VoiceSttErrorKind.network);
      },
    );

    test(
      'error_permission → emits VoiceSttException(permissionDenied) and closes',
      () async {
        final stream = service.listen();
        VoiceSttException? caughtError;
        final completer = Completer<void>();
        stream.listen(
          (_) {},
          onError: (Object e) {
            if (e is VoiceSttException) caughtError = e;
          },
          onDone: completer.complete,
          cancelOnError: false,
        );

        fake.fireError('error_permission');
        await completer.future;

        expect(caughtError, isNotNull);
        expect(caughtError!.kind, VoiceSttErrorKind.permissionDenied);
      },
    );

    // ── cancel() ─────────────────────────────────────────────────────────

    test(
      'cancel() closes the stream without emitting a final result',
      () async {
        final stream = service.listen();
        final events = <VoiceSttResult>[];
        final completer = Completer<void>();
        stream.listen(events.add, onDone: completer.complete);

        fake.firePartial('bench press');
        await service.cancel();
        await completer.future;

        expect(events.where((e) => e.isFinal), isEmpty);
      },
    );
  });
}
