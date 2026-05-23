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

    test('different owners with the same name yield different ids', () {
      // The property that lets per-account catalogs co-exist without
      // primary-key collisions: guest's "Bench Press" and an authenticated
      // user's "Bench Press" are distinct rows with distinct ids.
      final guestId = DeterministicCatalogId.forOwner(
        ownerUserId: '',
        name: 'Bench Press',
      );
      final userId = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-1',
        name: 'Bench Press',
      );
      expect(guestId, isNot(userId));
    });

    test('different owners always disagree on at least one default', () {
      // Stronger guard: scoping must actually shift every id, not just one.
      final guest = DeterministicCatalogId.forOwner(
        ownerUserId: '',
        name: 'Squat',
      );
      final userA = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-A',
        name: 'Squat',
      );
      final userB = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-B',
        name: 'Squat',
      );
      expect({guest, userA, userB}.length, 3);
    });

    test('guest owner collapses to the legacy name-only formula', () {
      // Back-compat invariant: rows seeded under earlier app versions had
      // ids equal to fromName(name); a guest reseed under the new scheme
      // must produce the same id so existing data stays addressable.
      for (final name in ['Bench Press', 'Squat', 'Deadlift']) {
        expect(
          DeterministicCatalogId.forOwner(ownerUserId: '', name: name),
          DeterministicCatalogId.fromName(name),
        );
        expect(
          DeterministicCatalogId.forOwner(ownerUserId: null, name: name),
          DeterministicCatalogId.fromName(name),
        );
      }
    });

    test('owner is whitespace-normalised before scoping', () {
      // Cosmetic owner differences (leading/trailing whitespace, an
      // all-whitespace owner) must not produce divergent ids — that would
      // re-introduce collisions for guest-equivalent inputs.
      expect(
        DeterministicCatalogId.forOwner(
          ownerUserId: '   ',
          name: 'Bench Press',
        ),
        DeterministicCatalogId.fromName('Bench Press'),
      );
    });
  });
}
