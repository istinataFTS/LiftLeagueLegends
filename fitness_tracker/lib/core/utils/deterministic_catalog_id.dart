import 'package:uuid/uuid.dart';

/// Stable, name-derived identity for default catalog rows (exercises & meals).
///
/// A default catalog entry must have **one id for a given (owner, canonical
/// name) pair**, identical across every device, reseed and account, forever.
/// We achieve this with a UUIDv5 derived from a fixed app namespace plus
/// `"<owner>|<canonicalName>"`, instead of a random v4 per seed run.
///
/// Why this matters: the local `*.id` is what `workout_sets.exercise_id` /
/// `nutrition_logs.meal_id` reference and what the remote upsert keys on.
/// A random id per seed makes that reference diverge on every reseed,
/// breaking sign-in sync and producing "Unknown exercise" history rows.
///
/// **Owner scoping** (per-user catalog model): under the isolation invariant
/// every account owns its own copy of the default catalog. If the id were
/// derived from name alone, two accounts' "Bench Press" rows would collide
/// on the primary key. Scoping the id by owner eliminates that collision.
///
/// After guest-mode removal there is no "unowned" catalog state at runtime:
/// every catalog row belongs to exactly one authenticated user. [forOwner]
/// therefore asserts a non-empty owner — passing an empty string is now a
/// caller bug we want to surface, not silently absorb.
///
/// User-*created* catalog rows keep a random v4 id (they are already unique
/// per user); only the curated defaults use this deterministic scheme.
class DeterministicCatalogId {
  DeterministicCatalogId._();

  /// Fixed application namespace for default-catalog UUIDv5 derivation.
  ///
  /// This value is part of the on-disk/remote contract — changing it would
  /// re-mint every default id and reintroduce the divergence this util
  /// exists to prevent. It must never change.
  static const String namespace = 'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e';

  static const Uuid _uuid = Uuid();

  /// Canonicalizes a catalog name so cosmetic differences (case, leading /
  /// trailing space, repeated inner whitespace) map to the same identity.
  ///
  /// Only used to derive the id — the human-facing name is stored verbatim.
  static String canonicalName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  /// Deterministic id for a default catalog entry owned by [ownerUserId]
  /// with [name].
  ///
  /// - Same `(owner, canonical name)` ⇒ same id.
  /// - Different owners with the same name ⇒ different ids (the property
  ///   that lets per-account catalogs co-exist without PK collisions).
  ///
  /// [ownerUserId] must be a non-empty authenticated user id. Passing an
  /// empty string trips an assertion — guest-flavored ids are no longer
  /// supported (see `KNOWN_ISSUES.md#guest-catalog-pk-collision-blocks-initial-sign-in`).
  static String forOwner({required String name, required String ownerUserId}) {
    assert(
      ownerUserId.trim().isNotEmpty,
      'DeterministicCatalogId.forOwner requires a non-empty authenticated '
      'owner id; guest-flavored ids are no longer supported.',
    );
    final canonicalOwner = ownerUserId.trim();
    final canonical = canonicalName(name);
    return _uuid.v5(namespace, '$canonicalOwner|$canonical');
  }
}
