import 'dart:typed_data';

import 'package:fitness_tracker/domain/entities/voice_settings.dart'
    show WakeWordPreset, WakeWordPresetPhrase;
import 'package:fitness_tracker/features/voice/data/services/pcm_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ── pcm16ToFloat32 ─────────────────────────────────────────────────────────

  group('pcm16ToFloat32', () {
    test('silence (0x00 0x00) → 0.0', () {
      final result = pcm16ToFloat32(Uint8List.fromList([0x00, 0x00]));
      expect(result, hasLength(1));
      expect(result[0], 0.0);
    });

    test('min int16 (0x00 0x80 = -32768) → -1.0', () {
      // Little-endian: 0x00 (low byte), 0x80 (high byte) = 0x8000 = -32768
      final result = pcm16ToFloat32(Uint8List.fromList([0x00, 0x80]));
      expect(result, hasLength(1));
      expect(result[0], closeTo(-1.0, 1e-6));
    });

    test('max int16 (0xFF 0x7F = 32767) → ≈+1.0', () {
      // Little-endian: 0xFF (low), 0x7F (high) = 0x7FFF = 32767
      final result = pcm16ToFloat32(Uint8List.fromList([0xFF, 0x7F]));
      expect(result, hasLength(1));
      expect(result[0], closeTo(32767 / 32768.0, 1e-6));
    });

    test('two samples are decoded independently', () {
      // [0x00 0x80] = -32768 → -1.0, [0xFF 0x7F] = 32767 → ≈+1.0
      final result = pcm16ToFloat32(
        Uint8List.fromList([0x00, 0x80, 0xFF, 0x7F]),
      );
      expect(result, hasLength(2));
      expect(result[0], closeTo(-1.0, 1e-6));
      expect(result[1], closeTo(32767 / 32768.0, 1e-6));
    });

    test('empty input → empty output', () {
      final result = pcm16ToFloat32(Uint8List(0));
      expect(result, isEmpty);
    });
  });

  // ── tokenizedLinesForPreset ────────────────────────────────────────────────

  group('tokenizedLinesForPreset', () {
    const kwContents =
        '▁SA MO ▁LE V S K I\n'
        '▁HE Y ▁SA MO ▁LE V S K I\n'
        '▁TRA IN ER :2.0\n'
        '▁HE Y ▁TRA IN ER :2.0\n'
        '▁TH OM AS :2.0\n'
        '▁HE Y ▁TH OM AS :2.0\n';

    test('samoLevski → bare + Hey lines', () {
      expect(
        tokenizedLinesForPreset(kwContents, WakeWordPreset.samoLevski),
        '▁SA MO ▁LE V S K I\n▁HE Y ▁SA MO ▁LE V S K I',
      );
    });

    test('trainer → bare + Hey lines', () {
      expect(
        tokenizedLinesForPreset(kwContents, WakeWordPreset.trainer),
        '▁TRA IN ER :2.0\n▁HE Y ▁TRA IN ER :2.0',
      );
    });

    test('thomas → bare + Hey lines', () {
      expect(
        tokenizedLinesForPreset(kwContents, WakeWordPreset.thomas),
        '▁TH OM AS :2.0\n▁HE Y ▁TH OM AS :2.0',
      );
    });

    test('fewer than 6 non-empty lines → throws ArgumentError', () {
      expect(
        () => tokenizedLinesForPreset(
          'l1\nl2\nl3\nl4\nl5\n',
          WakeWordPreset.thomas,
        ),
        throwsArgumentError,
      );
    });

    test('extra blank lines are ignored', () {
      const withBlanks =
          '\n▁SA MO ▁LE V S K I\n\n▁HE Y ▁SA MO ▁LE V S K I\n'
          '▁TRA IN ER :2.0\n▁HE Y ▁TRA IN ER :2.0\n\n'
          '▁TH OM AS :2.0\n▁HE Y ▁TH OM AS :2.0\n\n';
      expect(
        tokenizedLinesForPreset(withBlanks, WakeWordPreset.trainer),
        '▁TRA IN ER :2.0\n▁HE Y ▁TRA IN ER :2.0',
      );
    });
  });

  // ── WakeWordPreset.wakePhrase ──────────────────────────────────────────────

  group('WakeWordPreset.wakePhrase', () {
    test('samoLevski → HEY SAMO LEVSKI', () {
      expect(WakeWordPreset.samoLevski.wakePhrase, 'HEY SAMO LEVSKI');
    });

    test('trainer → HEY TRAINER', () {
      expect(WakeWordPreset.trainer.wakePhrase, 'HEY TRAINER');
    });

    test('thomas → HEY THOMAS', () {
      expect(WakeWordPreset.thomas.wakePhrase, 'HEY THOMAS');
    });
  });
}
