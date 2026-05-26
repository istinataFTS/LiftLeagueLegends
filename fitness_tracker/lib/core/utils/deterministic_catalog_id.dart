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
/// derived from name alone, the guest's "Bench Press" and an authenticated
/// user's "Bench Press" would collide on the primary key — and since the
/// guest catalog is seeded at boot before the user signs in, post-sign-in
/// provisioning would always abort with a constraint violation, leaving the
/// new user with an empty library. Scoping the id by owner eliminates the
/// collision.
///
/// **Back-compat with pre-owner-scoping installs**: for the guest owner
/// (`null` or `''`) the formula collapses to the historical name-only
/// derivation, so existing guest rows seeded by earlier app versions keep
/// their ids and remain idempotent on reseed.
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
  /// - Guest owner (`null` or `''`) collapses to the legacy name-only
  ///   formula, keeping older guest rows valid.
  static String forOwner({required String name, String? ownerUserId}) {
    final canonicalOwner = (ownerUserId ?? '').trim();
    final canonical = canonicalName(name);
    final key = canonicalOwner.isEmpty
        ? canonical
        : '$canonicalOwner|$canonical';
    return _uuid.v5(namespace, key);
  }

  /// Legacy alias for guest-equivalent id derivation.
  ///
  /// Equivalent to `forOwner(ownerUserId: '', name: name)`. Retained because
  /// the historical formula is on-disk for guest rows from older app
  /// versions; new call sites should prefer [forOwner] so the id is owner
  /// scoped and the per-user catalog model is honoured.
  static String fromName(String name) => forOwner(name: name, ownerUserId: '');
}
