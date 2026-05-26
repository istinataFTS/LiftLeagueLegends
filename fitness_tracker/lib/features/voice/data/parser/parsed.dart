/// Sealed hierarchy of all results the offline intent parser can produce.
///
/// Each subtype maps 1-to-1 to a VoiceBloc tool name so the
/// [OfflineVoiceCoordinator] can convert directly to a [VoiceToolCall].
///
/// [ParsedUnrecognized] is the catch-all when no matcher fires.
/// Supported offline commands:
///   - log / edit / delete workout set
///   - log / delete nutrition log
///   - query: weekly volume, daily macros, recent sets
sealed class ParsedIntent {
  const ParsedIntent();
}

// ---------------------------------------------------------------------------
// Workout set mutations
// ---------------------------------------------------------------------------

/// Log a new workout set.
/// [weightUnit] is null when the user did not specify a unit;
/// the coordinator defaults to the user's AppSettings preference.
final class ParsedLogWorkoutSet extends ParsedIntent {
  const ParsedLogWorkoutSet({
    required this.exerciseName,
    required this.reps,
    required this.weight,
    this.weightUnit,
  });

  final String exerciseName;
  final int reps;
  final double weight;

  /// 'kg' | 'lbs' | null
  final String? weightUnit;
}

/// Edit the most-recently logged workout set.
/// Only non-null fields are applied; all others keep their existing values.
final class ParsedEditWorkoutSet extends ParsedIntent {
  const ParsedEditWorkoutSet({this.reps, this.weight, this.weightUnit});

  final int? reps;
  final double? weight;

  /// 'kg' | 'lbs' | null
  final String? weightUnit;
}

/// Delete the most-recently logged workout set.
final class ParsedDeleteWorkoutSet extends ParsedIntent {
  const ParsedDeleteWorkoutSet();
}

// ---------------------------------------------------------------------------
// Nutrition log mutations
// ---------------------------------------------------------------------------

/// Log a new nutrition entry.
final class ParsedLogNutrition extends ParsedIntent {
  const ParsedLogNutrition({
    required this.mealName,
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
  });

  final String mealName;
  final double? calories;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
}

/// Edit the most-recently logged nutrition entry.
/// Only non-null fields are applied; all others keep their existing values.
final class ParsedEditNutrition extends ParsedIntent {
  const ParsedEditNutrition({
    this.calories,
    this.proteinGrams,
    this.carbsGrams,
    this.fatGrams,
  });

  final double? calories;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
}

/// Delete the most-recently logged nutrition entry.
final class ParsedDeleteNutrition extends ParsedIntent {
  const ParsedDeleteNutrition();
}

// ---------------------------------------------------------------------------
// Query intents
// ---------------------------------------------------------------------------

/// Query weekly volume (set count + exercise breakdown for the current week).
final class ParsedQueryWeeklyVolume extends ParsedIntent {
  const ParsedQueryWeeklyVolume();
}

/// Query daily macros (total calories, protein, carbs, fat for today).
final class ParsedQueryDailyMacros extends ParsedIntent {
  const ParsedQueryDailyMacros();
}

/// Query recent sets logged in the last 24 hours.
final class ParsedQueryRecentSets extends ParsedIntent {
  const ParsedQueryRecentSets();
}

// ---------------------------------------------------------------------------
// Fallthrough
// ---------------------------------------------------------------------------

/// No matcher recognised the utterance.
/// The [OfflineVoiceCoordinator] will speak a "not supported offline" reply.
final class ParsedUnrecognized extends ParsedIntent {
  const ParsedUnrecognized();
}
