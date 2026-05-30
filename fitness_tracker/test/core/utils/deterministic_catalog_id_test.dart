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

  group('DeterministicCatalogId.forOwner', () {
    test('same (owner, name) yields the same id', () {
      expect(
        DeterministicCatalogId.forOwner(
          ownerUserId: 'user-1',
          name: 'Bench Press',
        ),
        DeterministicCatalogId.forOwner(
          ownerUserId: 'user-1',
          name: 'Bench Press',
        ),
      );
    });

    test('cosmetic name differences resolve to the same id', () {
      final a = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-1',
        name: 'Bench Press',
      );
      final b = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-1',
        name: '  bench   PRESS ',
      );
      expect(a, b);
    });

    test('different names yield different ids', () {
      expect(
        DeterministicCatalogId.forOwner(
          ownerUserId: 'user-1',
          name: 'Bench Press',
        ),
        isNot(
          DeterministicCatalogId.forOwner(ownerUserId: 'user-1', name: 'Squat'),
        ),
      );
    });

    test('different owners with the same name yield different ids', () {
      // The property that lets per-account catalogs co-exist without
      // primary-key collisions.
      final userA = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-A',
        name: 'Bench Press',
      );
      final userB = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-B',
        name: 'Bench Press',
      );
      expect(userA, isNot(userB));
    });

    test('produces a canonical lowercase UUID string', () {
      final id = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-1',
        name: 'Deadlift',
      );
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('namespace is pinned (regression guard)', () {
      // Pins the on-disk/remote contract. If this changes, every default
      // catalog id changes — which is exactly the divergence to avoid.
      expect(
        DeterministicCatalogId.namespace,
        'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e',
      );
    });

    test('asserts on empty owner', () {
      // Guest-flavored ids are no longer supported — passing an empty owner
      // is a caller bug, not a back-compat path.
      expect(
        () => DeterministicCatalogId.forOwner(
          ownerUserId: '',
          name: 'Bench Press',
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => DeterministicCatalogId.forOwner(
          ownerUserId: '   ',
          name: 'Bench Press',
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
