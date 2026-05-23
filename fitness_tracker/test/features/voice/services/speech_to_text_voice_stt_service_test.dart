import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/features/voice/data/services/speech_to_text_voice_stt_service.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// VoiceSttResult — data class
// ---------------------------------------------------------------------------

void main() {
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

  // ── SpeechToTextVoiceSttService ───────────────────────────────────────────

  group('SpeechToTextVoiceSttService', () {
    test('implements VoiceSttService', () {
      final service = SpeechToTextVoiceSttService();
      expect(service, isA<VoiceSttService>());
    });

    test('isAvailable returns false before initialization', () {
      final service = SpeechToTextVoiceSttService();
      // Without calling initialize(), the plugin engine is not running.
      expect(service.isAvailable, isFalse);
    });

    test('isListening returns false before any listen() call', () {
      final service = SpeechToTextVoiceSttService();
      expect(service.isListening, isFalse);
    });

    test('cancel() completes without error even when not listening', () async {
      final service = SpeechToTextVoiceSttService();
      // Should not throw even though no stream is open.
      await expectLater(service.cancel(), completes);
    });

    test('dispose() completes without error when never initialized', () async {
      final service = SpeechToTextVoiceSttService();
      await expectLater(service.dispose(), completes);
    });

    // ── Error classification (pure, exercised via the public seams) ───────

    // The full code → kind mapping. Driven through the production helper so
    // there is exactly one source of truth — change the service, change here.
    final errorMapping = <String, VoiceSttErrorKind>{
      'error_permission': VoiceSttErrorKind.permissionDenied,
      'error_audio': VoiceSttErrorKind.permissionDenied,
      'error_no_match': VoiceSttErrorKind.noSpeech,
      'error_speech_timeout': VoiceSttErrorKind.noSpeech,
      'error_network': VoiceSttErrorKind.network,
      'error_network_timeout': VoiceSttErrorKind.network,
      'error_recognizer_busy': VoiceSttErrorKind.unavailable,
      'error_client': VoiceSttErrorKind.unavailable,
    };

    test('classifyErrorCode matches the documented mapping table', () {
      for (final entry in errorMapping.entries) {
        expect(
          SpeechToTextVoiceSttService.classifyErrorCode(entry.key),
          entry.value,
          reason: '${entry.key} should map to ${entry.value}',
        );
      }
    });

    test(
      'classifyErrorCode falls through to unknown for unrecognised codes',
      () {
        // Contract: any unrecognised error code from the platform must fall
        // through to `unknown` rather than throwing — the Android side has
        // historically added new error strings without notice.
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
      },
    );

    // ── Graceful-silence contract ─────────────────────────────────────────
    //
    // The VoiceSttService.listen() doc states that `noSpeech` outcomes must
    // close the stream via onDone, never via onError. These tests pin the
    // classification so a future refactor that "treats no_match as a real
    // error again" fails CI immediately.

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

    test(
      'Android no-speech codes round-trip into graceful-silence classification',
      () {
        // Regression guard for the original bug: `error_no_match` arriving
        // 2-3 s into a session would tear the stream down as a fatal error,
        // killing the mic before the user could even speak. The fix is that
        // every code that maps to `noSpeech` must also be classified as
        // graceful silence.
        const noSpeechCodes = <String>[
          'error_no_match',
          'error_speech_timeout',
        ];
        for (final code in noSpeechCodes) {
          final kind = SpeechToTextVoiceSttService.classifyErrorCode(code);
          expect(
            SpeechToTextVoiceSttService.isGracefulSilence(kind),
            isTrue,
            reason: '$code must round-trip into graceful silence',
          );
        }
      },
    );

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
          reason: '$code must remain a real error, not graceful silence',
        );
      }
    });
  });
}
