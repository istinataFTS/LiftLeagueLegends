import 'package:uuid/uuid.dart';

/// Stable, name-derived identity for default catalog rows (exercises & meals).
///
/// A default catalog entry must have **one id for a given canonical name**,
/// identical across every device, reseed and account, forever. We achieve
/// this with a UUIDv5 derived from a fixed app namespace plus the canonical
/// (normalized) name, instead of a random v4 per seed run.
///
/// Why this matters: the local `*.id` is what `workout_sets.exercise_id` /
/// `nutrition_logs.meal_id` reference and what the remote upsert keys on.
/// A random id per seed makes that reference diverge on every reseed,
/// breaking sign-in sync and producing "Unknown exercise" history rows.
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

  /// Deterministic id for a default catalog entry with [name].
  ///
  /// Same canonical name ⇒ same id; different names ⇒ different ids.
  static String fromName(String name) {
    return _uuid.v5(namespace, canonicalName(name));
  }
}
