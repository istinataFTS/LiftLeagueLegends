import '../../domain/entities/muscle_factor.dart';
import 'muscle_stimulus_constants.dart';

class ExerciseMuscleFactorsData {
  ExerciseMuscleFactorsData._();

  static Map<String, List<MuscleFactorData>>? _cachedFactors;
  static Map<String, List<MuscleFactorData>>? _cachedFactorsByNormalizedName;

  /// Normalizes an exercise name for lookup: lowercases and strips every
  /// non-alphanumeric character.
  ///
  /// Why: exercise names flow in from three sources — the local seed
  /// ([getAllFactors] keys), the default-exercises seed
  /// ([default_exercises_data.dart]), and Supabase pulls (which may have
  /// been edited by other devices or older app versions). Spelling drift
  /// between "Sit-ups" / "Sit Ups" / "Push-Ups" / "pushups" would leave an
  /// exercise with no factors and trigger the "couldn't map it to any
  /// muscle group" banner even though biomechanically identical seed data
  /// exists. Normalizing both sides collapses all those variants onto a
  /// single key.
  static String _normalizeName(String name) {
    final buffer = StringBuffer();
    for (final codeUnit in name.toLowerCase().codeUnits) {
      final isLower = codeUnit >= 0x61 && codeUnit <= 0x7a;
      final isDigit = codeUnit >= 0x30 && codeUnit <= 0x39;
      if (isLower || isDigit) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString();
  }

  static Map<String, List<MuscleFactorData>> _factorsByNormalizedName() {
    final cached = _cachedFactorsByNormalizedName;
    if (cached != null) return cached;
    final built = <String, List<MuscleFactorData>>{};
    for (final entry in getAllFactors().entries) {
      built[_normalizeName(entry.key)] = entry.value;
    }
    return _cachedFactorsByNormalizedName = built;
  }

  static Map<String, List<MuscleFactorData>> getAllFactors() {
    return _cachedFactors ??= {
      // ==================== CHEST EXERCISES ====================
      'Bench Press': [
        const MuscleFactorData(MuscleStimulus.midChest, 1.0),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerChest, 0.4),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.triceps, 0.3),
      ],

      'Incline Bench Press': [
        const MuscleFactorData(MuscleStimulus.upperChest, 1.0),
        const MuscleFactorData(MuscleStimulus.midChest, 0.5),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.5),
        const MuscleFactorData(MuscleStimulus.triceps, 0.3),
      ],

      'Dumbbell Flyes': [
        const MuscleFactorData(MuscleStimulus.midChest, 1.0),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.3),
        const MuscleFactorData(MuscleStimulus.lowerChest, 0.3),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.2),
      ],

      'Decline Bench Press': [
        const MuscleFactorData(MuscleStimulus.lowerChest, 1.0),
        const MuscleFactorData(MuscleStimulus.midChest, 0.5),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.3),
        const MuscleFactorData(MuscleStimulus.triceps, 0.3),
      ],

      'Push-ups': [
        const MuscleFactorData(MuscleStimulus.midChest, 1.0),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.3),
        const MuscleFactorData(MuscleStimulus.lowerChest, 0.3),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.3),
        const MuscleFactorData(MuscleStimulus.triceps, 0.3),
        const MuscleFactorData(MuscleStimulus.abs, 0.2), // Stabilizer
      ],

      'Cable Crossover': [
        const MuscleFactorData(MuscleStimulus.midChest, 1.0),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerChest, 0.4),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.2),
      ],

      // ==================== BACK EXERCISES ====================
      'Pull-ups': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.5),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.3),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Chin-ups': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.biceps, 0.7),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.3),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.2),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Dumbbell Row': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.6),
        const MuscleFactorData(MuscleStimulus.lowerTraps, 0.4),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.5),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.2),
      ],

      'Barbell Row': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.6),
        const MuscleFactorData(MuscleStimulus.lowerTraps, 0.4),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.5),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.3), // Stabilizer
      ],

      'Lat Pulldown': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.3),
        const MuscleFactorData(MuscleStimulus.biceps, 0.4),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.2),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Deadlift': [
        const MuscleFactorData(MuscleStimulus.lowerBack, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.8),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.7),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.5),
        const MuscleFactorData(MuscleStimulus.lats, 0.4),
        const MuscleFactorData(MuscleStimulus.forearms, 0.5),
        const MuscleFactorData(MuscleStimulus.abs, 0.3), // Core stabilization
      ],

      'T-Bar Row': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.6),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.3),
      ],

      'Seated Cable Row': [
        const MuscleFactorData(MuscleStimulus.lats, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.5),
        const MuscleFactorData(MuscleStimulus.rearDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerTraps, 0.3),
      ],

      'Face Pulls': [
        const MuscleFactorData(MuscleStimulus.rearDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.6),
        const MuscleFactorData(MuscleStimulus.upperTraps, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.2),
      ],

      // ==================== SHOULDER EXERCISES ====================
      'Overhead Press': [
        const MuscleFactorData(MuscleStimulus.frontDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.sideDelts, 0.5),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.3),
        const MuscleFactorData(MuscleStimulus.triceps, 0.5),
        const MuscleFactorData(MuscleStimulus.upperTraps, 0.3),
        const MuscleFactorData(MuscleStimulus.abs, 0.2), // Stabilizer
      ],

      'Lateral Raises': [
        const MuscleFactorData(MuscleStimulus.sideDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.2),
        const MuscleFactorData(MuscleStimulus.upperTraps, 0.2),
      ],

      'Front Raises': [
        const MuscleFactorData(MuscleStimulus.frontDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.upperChest, 0.2),
      ],

      'Arnold Press': [
        const MuscleFactorData(MuscleStimulus.frontDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.sideDelts, 0.6),
        const MuscleFactorData(MuscleStimulus.triceps, 0.4),
        const MuscleFactorData(MuscleStimulus.upperTraps, 0.3),
      ],

      'Rear Delt Flyes': [
        const MuscleFactorData(MuscleStimulus.rearDelts, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.3),
      ],

      // ==================== ARM EXERCISES ====================
      'Barbell Curl': [
        const MuscleFactorData(MuscleStimulus.biceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.3),
      ],

      'Dumbbell Curl': [
        const MuscleFactorData(MuscleStimulus.biceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.3),
      ],

      'Hammer Curl': [
        const MuscleFactorData(MuscleStimulus.biceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.5),
      ],

      'Preacher Curl': [
        const MuscleFactorData(MuscleStimulus.biceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Tricep Dips': [
        const MuscleFactorData(MuscleStimulus.triceps, 1.0),
        const MuscleFactorData(MuscleStimulus.lowerChest, 0.4),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.3),
      ],

      'Tricep Pushdown': [const MuscleFactorData(MuscleStimulus.triceps, 1.0)],

      'Skull Crushers': [
        const MuscleFactorData(MuscleStimulus.triceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Close-Grip Bench Press': [
        const MuscleFactorData(MuscleStimulus.triceps, 1.0),
        const MuscleFactorData(MuscleStimulus.midChest, 0.6),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.4),
      ],

      'Concentration Curl': [
        const MuscleFactorData(MuscleStimulus.biceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Overhead Tricep Extension': [
        const MuscleFactorData(MuscleStimulus.triceps, 1.0),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2),
      ],

      'Wrist Curl': [const MuscleFactorData(MuscleStimulus.forearms, 1.0)],

      'Reverse Wrist Curl': [
        const MuscleFactorData(MuscleStimulus.forearms, 1.0),
      ],

      // ==================== LEG EXERCISES ====================
      'Squat': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.7),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.3), // Stabilizer
        const MuscleFactorData(MuscleStimulus.abs, 0.3), // Core stabilization
      ],

      'Leg Press': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.6),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.3),
      ],

      'Leg Curl': [const MuscleFactorData(MuscleStimulus.hamstrings, 1.0)],

      'Leg Extension': [const MuscleFactorData(MuscleStimulus.quads, 1.0)],

      'Calf Raises': [const MuscleFactorData(MuscleStimulus.calves, 1.0)],

      'Romanian Deadlift': [
        const MuscleFactorData(MuscleStimulus.hamstrings, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.7),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.6),
        const MuscleFactorData(MuscleStimulus.forearms, 0.3),
      ],

      'Bulgarian Split Squat': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.7),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.4),
      ],

      'Hack Squat': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.5),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.3),
      ],

      'Front Squat': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.5),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.3),
        const MuscleFactorData(MuscleStimulus.abs, 0.3), // Core stabilization
      ],

      'Nordic Curls': [
        const MuscleFactorData(MuscleStimulus.hamstrings, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.3),
      ],

      'Lunges': [
        const MuscleFactorData(MuscleStimulus.quads, 1.0),
        const MuscleFactorData(MuscleStimulus.glutes, 0.7),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.4),
      ],

      'Hip Thrusts': [
        const MuscleFactorData(MuscleStimulus.glutes, 1.0),
        const MuscleFactorData(MuscleStimulus.hamstrings, 0.4),
      ],

      'Seated Calf Raises': [
        const MuscleFactorData(MuscleStimulus.calves, 1.0),
      ],

      // ==================== CORE EXERCISES ====================
      'Crunches': [const MuscleFactorData(MuscleStimulus.abs, 1.0)],

      'Sit-ups': [
        const MuscleFactorData(MuscleStimulus.abs, 1.0),
        const MuscleFactorData(MuscleStimulus.obliques, 0.2),
      ],

      'Planks': [
        const MuscleFactorData(MuscleStimulus.abs, 1.0),
        const MuscleFactorData(MuscleStimulus.obliques, 0.5),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.3),
      ],

      'Side Planks': [
        const MuscleFactorData(MuscleStimulus.obliques, 1.0),
        const MuscleFactorData(MuscleStimulus.abs, 0.5),
      ],

      'Russian Twists': [
        const MuscleFactorData(MuscleStimulus.obliques, 1.0),
        const MuscleFactorData(MuscleStimulus.abs, 0.5),
      ],

      'Hanging Leg Raises': [
        const MuscleFactorData(MuscleStimulus.abs, 1.0),
        const MuscleFactorData(MuscleStimulus.obliques, 0.3),
        const MuscleFactorData(MuscleStimulus.forearms, 0.2), // Grip
      ],

      'Ab Wheel Rollout': [
        const MuscleFactorData(MuscleStimulus.abs, 1.0),
        const MuscleFactorData(MuscleStimulus.obliques, 0.4),
        const MuscleFactorData(MuscleStimulus.lowerBack, 0.3),
      ],

      'Cable Crunches': [
        const MuscleFactorData(MuscleStimulus.abs, 1.0),
        const MuscleFactorData(MuscleStimulus.obliques, 0.2),
      ],

      // ==================== TRAP EXERCISES ====================
      'Shrugs': [
        const MuscleFactorData(MuscleStimulus.upperTraps, 1.0),
        const MuscleFactorData(MuscleStimulus.middleTraps, 0.4),
        const MuscleFactorData(MuscleStimulus.forearms, 0.3), // Grip
      ],

      'Upright Row': [
        const MuscleFactorData(MuscleStimulus.upperTraps, 1.0),
        const MuscleFactorData(MuscleStimulus.sideDelts, 0.7),
        const MuscleFactorData(MuscleStimulus.frontDelts, 0.4),
        const MuscleFactorData(MuscleStimulus.biceps, 0.3),
      ],
    };
  }

  /// Get total number of exercises with factors
  static int get totalExercises => getAllFactors().length;

  /// Get total number of muscle factor assignments
  static int get totalFactorAssignments {
    int count = 0;

    for (final factors in getAllFactors().values) {
      count += factors.length;
    }

    return count;
  }

  /// Validate that an exercise has factors defined.
  ///
  /// Lookup is name-normalized — see [_normalizeName] — so "Sit-ups",
  /// "Sit Ups", and "sit ups" all resolve to the same seed entry.
  static bool hasFactors(String exerciseName) {
    return _factorsByNormalizedName().containsKey(_normalizeName(exerciseName));
  }

  /// Get factors for a specific exercise (name-normalized lookup).
  static List<MuscleFactorData>? getFactorsForExercise(String exerciseName) {
    return _factorsByNormalizedName()[_normalizeName(exerciseName)];
  }

  /// Get all exercises that target a specific muscle group
  static List<String> getExercisesForMuscle(String muscleGroup) {
    final exercises = <String>[];

    for (final entry in getAllFactors().entries) {
      for (final factor in entry.value) {
        if (factor.muscleGroup == muscleGroup) {
          exercises.add(entry.key);
          break;
        }
      }
    }

    return exercises;
  }

  /// Validate factor assignments (all factors should be 0.1 - 1.0)
  static bool validateFactors() {
    final factors = getAllFactors();

    for (final entry in factors.entries) {
      for (final factor in entry.value) {
        if (factor.factor < 0.1 || factor.factor > 1.0) {
          return false;
        }
      }
    }

    return true;
  }
}

/// Data class for muscle factor seed data
/// Lightweight structure used only for seeding
class MuscleFactorData {
  const MuscleFactorData(this.muscleGroup, this.factor);

  final String muscleGroup;
  final double factor;

  /// Convert to MuscleFactor entity with generated ID
  MuscleFactor toEntity({required String id, required String exerciseId}) {
    return MuscleFactor(
      id: id,
      exerciseId: exerciseId,
      muscleGroup: muscleGroup,
      factor: factor,
    );
  }

  @override
  String toString() => '$muscleGroup: $factor';
}
