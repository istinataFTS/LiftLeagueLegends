import 'package:fitness_tracker/core/utils/deterministic_catalog_id.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeterministicCatalogId.canonicalName', () {
    test('trims, lowercases and collapses inner whitespace', () {
      expect(
        DeterministicCatalogId.canonicalName('  Bench   Press '),
        'bench press',
      );
      expect(
        DeterministicCatalogId.canonicalName('Chicken\tBreast'),
        'chicken breast',
      );
    });
  });

  group('DeterministicCatalogId.fromName', () {
    test('same name always yields the same id', () {
      expect(
        DeterministicCatalogId.fromName('Bench Press'),
        DeterministicCatalogId.fromName('Bench Press'),
      );
    });

    test('cosmetic differences resolve to the same id', () {
      final a = DeterministicCatalogId.fromName('Bench Press');
      final b = DeterministicCatalogId.fromName('  bench   PRESS ');
      expect(a, b);
    });

    test('different names yield different ids', () {
      expect(
        DeterministicCatalogId.fromName('Bench Press'),
        isNot(DeterministicCatalogId.fromName('Squat')),
      );
    });

    test('produces a canonical lowercase UUID string', () {
      final id = DeterministicCatalogId.fromName('Deadlift');
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('id is stable against the fixed namespace (regression guard)', () {
      // Pins the on-disk/remote contract. If this changes, every default
      // catalog id changes — which is exactly the divergence to avoid.
      expect(
        DeterministicCatalogId.fromName('Bench Press'),
        DeterministicCatalogId.fromName('Bench Press'),
      );
      expect(
        DeterministicCatalogId.namespace,
        'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e',
      );
    });
  });
}
