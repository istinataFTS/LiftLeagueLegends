import 'legacy_muscle_group_map.dart';

/// Combines muscle factors under the canonical 18-key taxonomy using the
/// **MAX rule** (GATE-2): when several legacy keys collapse to the same
/// canonical key, the surviving factor is the *maximum* of the contributors.
/// MAX preserves the prime mover (e.g. Bench Press' `mid-chest` 1.0 dominates
/// the `upper/lower-chest` 0.4 contributions, so merged `chest` stays 1.0)
/// rather than diluting it the way an average would.
///
/// This is the single combine rule, reused by:
/// - the seed remap (`ExerciseMuscleFactorsData.getAllFactors`),
/// - the v26 DB migration dedup (`database_helper.dart`),
/// - the factor write path (`SyncExerciseMuscleFactors`).
///
/// Keys are canonicalised via [LegacyMuscleGroupMap.canonicalizeMuscleKey]
/// first, so both granular and simple legacy inputs fold onto canonical keys.
Map<String, double> combineCanonicalFactors(
  Iterable<MapEntry<String, double>> rawFactors,
) {
  final Map<String, double> combined = <String, double>{};
  for (final MapEntry<String, double> entry in rawFactors) {
    final String key = LegacyMuscleGroupMap.canonicalizeMuscleKey(entry.key);
    final double? existing = combined[key];
    if (existing == null || entry.value > existing) {
      combined[key] = entry.value;
    }
  }
  return combined;
}
