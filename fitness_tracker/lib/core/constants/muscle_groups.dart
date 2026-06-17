import 'package:fitness_tracker/core/constants/legacy_muscle_group_map.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';

class MuscleGroups {
  /// The 18 canonical muscle groups, shared by the edit dialog, body map, and
  /// all read/write paths as of schema v26.
  static const List<String> all = <String>[
    MuscleStimulus.shoulders,
    MuscleStimulus.rearDelts,
    MuscleStimulus.upperTraps,
    MuscleStimulus.lowerTraps,
    MuscleStimulus.chest,
    MuscleStimulus.lats,
    MuscleStimulus.biceps,
    MuscleStimulus.triceps,
    MuscleStimulus.forearms,
    MuscleStimulus.abs,
    MuscleStimulus.obliques,
    MuscleStimulus.lovehandles,
    MuscleStimulus.lowerBack,
    MuscleStimulus.glutes,
    MuscleStimulus.hipadductors,
    MuscleStimulus.quads,
    MuscleStimulus.hamstrings,
    MuscleStimulus.calves,
  ];

  /// Display names keyed by canonical muscle key.
  static const Map<String, String> displayNames = <String, String>{
    MuscleStimulus.shoulders: 'Shoulders',
    MuscleStimulus.rearDelts: 'Rear Delts',
    MuscleStimulus.upperTraps: 'Upper Traps',
    MuscleStimulus.lowerTraps: 'Lower Traps',
    MuscleStimulus.chest: 'Chest',
    MuscleStimulus.lats: 'Lats',
    MuscleStimulus.biceps: 'Biceps',
    MuscleStimulus.triceps: 'Triceps',
    MuscleStimulus.forearms: 'Forearms',
    MuscleStimulus.abs: 'Abs',
    MuscleStimulus.obliques: 'Obliques',
    MuscleStimulus.lovehandles: 'Love Handles',
    MuscleStimulus.lowerBack: 'Lower Back',
    MuscleStimulus.glutes: 'Glutes',
    MuscleStimulus.hipadductors: 'Hip Adductors',
    MuscleStimulus.quads: 'Quads',
    MuscleStimulus.hamstrings: 'Hamstrings',
    MuscleStimulus.calves: 'Calves',
  };

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

  /// Returns true for any canonical key or any legacy key that resolves to a
  /// canonical key via [LegacyMuscleGroupMap].
  static bool isValid(String muscleGroup) {
    return all.contains(
      LegacyMuscleGroupMap.canonicalizeMuscleKey(muscleGroup.toLowerCase()),
    );
  }

  /// Returns the display name for [muscleGroup], canonicalising the key first
  /// so that legacy keys (granular or simple) resolve correctly.
  static String getDisplayName(String muscleGroup) {
    final String canonical = LegacyMuscleGroupMap.canonicalizeMuscleKey(
      muscleGroup.toLowerCase(),
    );
    return displayNames[canonical] ?? muscleGroup;
  }
}
