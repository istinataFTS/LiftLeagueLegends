import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';

class MuscleGroups {
  /// The 18 canonical muscle groups. Delegates to [MuscleStimulus.allMuscleGroups]
  /// so there is a single source of truth.
  static const List<String> all = MuscleStimulus.allMuscleGroups;

  /// Display names keyed by canonical muscle key. Delegates to
  /// [MuscleStimulus.displayNames] to prevent contract drift.
  static const Map<String, String> displayNames = MuscleStimulus.displayNames;

  /// Returns true for any canonical or legacy key. Delegates to
  /// [MuscleStimulus.isValidMuscleGroup].
  static bool isValid(String muscleGroup) =>
      MuscleStimulus.isValidMuscleGroup(muscleGroup);

  /// Returns the display name for [muscleGroup], canonicalising the key first.
  /// Delegates to [MuscleStimulus.getDisplayName].
  static String getDisplayName(String muscleGroup) =>
      MuscleStimulus.getDisplayName(muscleGroup);
}
