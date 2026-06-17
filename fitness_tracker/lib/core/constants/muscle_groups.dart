import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';

class MuscleGroups {
  /// The 18 canonical muscle groups. Delegates to [MuscleStimulus.allMuscleGroups]
  /// so there is a single source of truth.
  static const List<String> all = MuscleStimulus.allMuscleGroups;

  /// Display names keyed by canonical muscle key. Delegates to
  /// [MuscleStimulus.displayNames] to prevent contract drift.
  static const Map<String, String> displayNames = MuscleStimulus.displayNames;

  /// Legacy mapping of granular taxonomy keys to their former simple equivalents.
  /// Removed in A2 once all callers are migrated to canonical keys.
  static const Map<String, String> granularToSimple = <String, String>{
    // Shoulders
    'front-delts': 'shoulder',
    'side-delts': 'shoulder',
    'rear-delts': 'shoulder',
    // Traps
    'upper-traps': 'traps',
    'middle-traps': 'traps',
    'lower-traps': 'traps',
    // Chest
    'upper-chest': 'chest',
    'mid-chest': 'chest',
    'lower-chest': 'chest',
    // Already-simple keys included for single-lookup convenience
    'lats': 'lats',
    'biceps': 'biceps',
    'triceps': 'triceps',
    'forearms': 'forearms',
    'abs': 'abs',
    'obliques': 'obliques',
    'lovehandles': 'obliques',
    'lower-back': 'lower back',
    'glutes': 'glutes',
    'hipadductors': 'hamstring',
    'quads': 'quads',
    'hamstrings': 'hamstring',
    'calves': 'calves',
  };

  /// Returns true for any canonical or legacy key. Delegates to
  /// [MuscleStimulus.isValidMuscleGroup].
  static bool isValid(String muscleGroup) =>
      MuscleStimulus.isValidMuscleGroup(muscleGroup);

  /// Returns the display name for [muscleGroup], canonicalising the key first.
  /// Delegates to [MuscleStimulus.getDisplayName].
  static String getDisplayName(String muscleGroup) =>
      MuscleStimulus.getDisplayName(muscleGroup);
}
