class MuscleGroups {
  static const List<String> all = [
    'shoulder',
    'traps',
    'lats',
    'chest',
    'biceps',
    'triceps',
    'neck',
    'forearms',
    'obliques',
    'abs',
    'lower back',
    'glutes',
    'hamstring',
    'quads',
    'calves',
  ];

  /// Display names for muscle groups (for UI)
  static const Map<String, String> displayNames = {
    'shoulder': 'Shoulders',
    'traps': 'Traps',
    'lats': 'Lats',
    'chest': 'Chest',
    'biceps': 'Biceps',
    'triceps': 'Triceps',
    'neck': 'Neck',
    'forearms': 'Forearms',
    'obliques': 'Obliques',
    'abs': 'Abs',
    'lower back': 'Lower Back',
    'glutes': 'Glutes',
    'hamstring': 'Hamstrings',
    'quads': 'Quads',
    'calves': 'Calves',
  };

  /// Maps granular taxonomy keys (used in seed data / [MuscleStimulus]) to
  /// their corresponding simple taxonomy keys (used in [MuscleGroups.all]).
  ///
  /// Used when loading saved [MuscleFactor] rows into the exercise dialog so
  /// that granular seed factors can be averaged and displayed on the simple-key
  /// sliders.  Keys that are already simple (e.g. `'quads'`, `'biceps'`) are
  /// listed here too so callers need only a single lookup.
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
    'lovehandles': 'obliques', // nearest simple equivalent
    'lower-back': 'lower back',
    'glutes': 'glutes',
    'hipadductors': 'hamstring', // nearest simple equivalent
    'quads': 'quads',
    'hamstrings': 'hamstring',
    'calves': 'calves',
  };

  /// Validate if a muscle group name is valid
  static bool isValid(String muscleGroup) {
    return all.contains(muscleGroup.toLowerCase());
  }

  /// Get display name for a muscle group
  static String getDisplayName(String muscleGroup) {
    return displayNames[muscleGroup.toLowerCase()] ?? muscleGroup;
  }
}
