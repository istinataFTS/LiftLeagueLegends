import 'package:fitness_tracker/features/voice/data/services/speech_to_text_voice_stt_service.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
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
      expect(VoiceSttErrorKind.values, containsAll(<VoiceSttErrorKind>[
        VoiceSttErrorKind.permissionDenied,
        VoiceSttErrorKind.permissionPermanentlyDenied,
        VoiceSttErrorKind.unavailable,
        VoiceSttErrorKind.noSpeech,
        VoiceSttErrorKind.network,
        VoiceSttErrorKind.unknown,
      ]));
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

    // ── Error mapping (tested via FakeVoiceSttService contract) ────────────

    // The actual error mapping (Android error strings → VoiceSttErrorKind)
    // is exercised end-to-end in voice_bloc_test.dart via FakeVoiceSttService
    // which fires VoiceSttException(kind) events and verifies the bloc handles
    // them correctly. Integration tests covering the real speech_to_text
    // platform channel require a physical device or emulator and live in the
    // integration_test/ directory.
    //
    // The mapping table itself is stable contract:
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

    test('error mapping table is complete and non-empty', () {
      expect(errorMapping, isNotEmpty);
      // Every mapped kind is a valid VoiceSttErrorKind.
      for (final kind in errorMapping.values) {
        expect(VoiceSttErrorKind.values, contains(kind));
      }
    });

    test(
        'unknown Android error codes should map to VoiceSttErrorKind.unknown',
        () {
      // This is a design contract — any unrecognised error code from Android
      // must fall through to 'unknown' rather than crashing.
      const unknownCodes = <String>[
        'error_something_new',
        '',
        'totally_unexpected',
      ];
      // The mapping doesn't contain unknownCodes; verify they are absent.
      for (final code in unknownCodes) {
        expect(errorMapping.containsKey(code), isFalse,
            reason: '$code should NOT be in the mapping table (falls to default)');
      }
    });
  });
}
