import 'package:fitness_tracker/core/utils/date_serialization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DateSerialization.toStorageIso', () {
    test('produces a Z-suffixed string', () {
      final local = DateTime(2026, 6, 2, 10, 30, 0);
      final iso = local.toStorageIso();
      expect(iso.endsWith('Z'), isTrue);
    });

    test('round-trip preserves the same instant', () {
      final local = DateTime(2026, 6, 2, 10, 30, 0);
      final roundTripped = parseStorageDate(local.toStorageIso());
      expect(roundTripped.isAtSameMomentAs(local), isTrue);
    });

    test('UTC DateTime round-trips faithfully', () {
      final utc = DateTime.utc(2026, 1, 15, 8, 0, 0);
      final roundTripped = parseStorageDate(utc.toStorageIso());
      expect(roundTripped.isAtSameMomentAs(utc), isTrue);
    });

    test(
      'toStorageIso on an already-UTC DateTime is idempotent in instant',
      () {
        final utc = DateTime.utc(2026, 3, 10, 14, 45);
        final iso = utc.toStorageIso();
        expect(iso.endsWith('Z'), isTrue);
        expect(DateTime.parse(iso).isAtSameMomentAs(utc), isTrue);
      },
    );
  });

  group('parseStorageDate', () {
    test('Z string returns a local DateTime', () {
      const zString = '2026-06-02T09:30:00.000Z';
      final result = parseStorageDate(zString);
      expect(result.isUtc, isFalse);
    });

    test('Z string instant matches the UTC source', () {
      final utcSource = DateTime.utc(2026, 6, 2, 9, 30);
      final result = parseStorageDate('2026-06-02T09:30:00.000Z');
      expect(result.isAtSameMomentAs(utcSource), isTrue);
    });

    test('offset-less (legacy) string is treated as local', () {
      final naive = DateTime(2026, 6, 2, 12, 0, 0);
      final result = parseStorageDate('2026-06-02T12:00:00.000');
      expect(result.isAtSameMomentAs(naive), isTrue);
    });

    test('+00:00 string is equivalent to Z', () {
      final result = parseStorageDate('2026-06-02T09:30:00.000+00:00');
      expect(result.isAtSameMomentAs(DateTime.utc(2026, 6, 2, 9, 30)), isTrue);
    });
  });

  group('parseStorageDateOrNull', () {
    test('returns null for null input', () {
      expect(parseStorageDateOrNull(null), isNull);
    });

    test('returns null for empty string', () {
      expect(parseStorageDateOrNull(''), isNull);
    });

    test('parses a valid Z string to a local DateTime', () {
      final result = parseStorageDateOrNull('2026-06-02T09:30:00.000Z');
      expect(result, isNotNull);
      expect(result!.isUtc, isFalse);
      expect(result.isAtSameMomentAs(DateTime.utc(2026, 6, 2, 9, 30)), isTrue);
    });
  });
}
