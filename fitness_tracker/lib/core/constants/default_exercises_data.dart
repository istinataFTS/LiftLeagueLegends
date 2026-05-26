import '../../domain/entities/exercise.dart';

class DefaultExercisesData {
  DefaultExercisesData._();

  /// Get all default exercises for seeding
  /// Returns a new list each time to prevent mutation
  static List<ExerciseData> getDefaultExercises() {
    return [
      // ==================== CHEST EXERCISES ====================
      const ExerciseData(
        name: 'Bench Press',
        muscleGroups: ['chest', 'triceps', 'shoulder'],
        category: 'chest',
      ),
      const ExerciseData(
        name: 'Incline Bench Press',
        muscleGroups: ['chest', 'shoulder', 'triceps'],
        category: 'chest',
      ),
      const ExerciseData(
        name: 'Decline Bench Press',
        muscleGroups: ['chest', 'triceps'],
        category: 'chest',
      ),
      const ExerciseData(
        name: 'Dumbbell Flyes',
        muscleGroups: ['chest'],
        category: 'chest',
      ),
      const ExerciseData(
        name: 'Push-ups',
        muscleGroups: ['chest', 'triceps', 'shoulder'],
        category: 'chest',
      ),
      const ExerciseData(
        name: 'Cable Crossover',
        muscleGroups: ['chest'],
        category: 'chest',
      ),

      // ==================== BACK EXERCISES ====================
      const ExerciseData(
        name: 'Pull-ups',
        muscleGroups: ['lats', 'biceps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Chin-ups',
        muscleGroups: ['lats', 'biceps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Barbell Row',
        muscleGroups: ['lats', 'lower back', 'biceps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Dumbbell Row',
        muscleGroups: ['lats', 'lower back', 'biceps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Deadlift',
        muscleGroups: ['lower back', 'glutes', 'hamstring', 'traps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Lat Pulldown',
        muscleGroups: ['lats', 'biceps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'T-Bar Row',
        muscleGroups: ['lats', 'lower back'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Seated Cable Row',
        muscleGroups: ['lats', 'lower back'],
        category: 'back',
      ),

      // ==================== SHOULDER EXERCISES ====================
      const ExerciseData(
        name: 'Overhead Press',
        muscleGroups: ['shoulder', 'triceps'],
        category: 'shoulders',
      ),
      const ExerciseData(
        name: 'Arnold Press',
        muscleGroups: ['shoulder'],
        category: 'shoulders',
      ),
      const ExerciseData(
        name: 'Lateral Raises',
        muscleGroups: ['shoulder'],
        category: 'shoulders',
      ),
      const ExerciseData(
        name: 'Front Raises',
        muscleGroups: ['shoulder'],
        category: 'shoulders',
      ),
      const ExerciseData(
        name: 'Rear Delt Flyes',
        muscleGroups: ['shoulder'],
        category: 'shoulders',
      ),
      const ExerciseData(
        name: 'Face Pulls',
        muscleGroups: ['shoulder', 'traps'],
        category: 'shoulders',
      ),

      // ==================== ARM EXERCISES ====================

      // Biceps
      const ExerciseData(
        name: 'Barbell Curl',
        muscleGroups: ['biceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Dumbbell Curl',
        muscleGroups: ['biceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Hammer Curl',
        muscleGroups: ['biceps', 'forearms'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Preacher Curl',
        muscleGroups: ['biceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Concentration Curl',
        muscleGroups: ['biceps'],
        category: 'arms',
      ),

      // Triceps
      const ExerciseData(
        name: 'Tricep Dips',
        muscleGroups: ['triceps', 'chest'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Tricep Pushdown',
        muscleGroups: ['triceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Overhead Tricep Extension',
        muscleGroups: ['triceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Skull Crushers',
        muscleGroups: ['triceps'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Close-Grip Bench Press',
        muscleGroups: ['triceps', 'chest'],
        category: 'arms',
      ),

      // Forearms
      const ExerciseData(
        name: 'Wrist Curl',
        muscleGroups: ['forearms'],
        category: 'arms',
      ),
      const ExerciseData(
        name: 'Reverse Wrist Curl',
        muscleGroups: ['forearms'],
        category: 'arms',
      ),

      // ==================== LEG EXERCISES ====================

      // Quads/Glutes
      const ExerciseData(
        name: 'Squat',
        muscleGroups: ['quads', 'glutes', 'hamstring'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Front Squat',
        muscleGroups: ['quads', 'glutes'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Leg Press',
        muscleGroups: ['quads', 'glutes'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Lunges',
        muscleGroups: ['quads', 'glutes'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Bulgarian Split Squat',
        muscleGroups: ['quads', 'glutes'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Leg Extension',
        muscleGroups: ['quads'],
        category: 'legs',
      ),

      // Hamstrings
      const ExerciseData(
        name: 'Leg Curl',
        muscleGroups: ['hamstring'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Romanian Deadlift',
        muscleGroups: ['hamstring', 'glutes', 'lower back'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Nordic Curls',
        muscleGroups: ['hamstring'],
        category: 'legs',
      ),

      // Calves
      const ExerciseData(
        name: 'Calf Raises',
        muscleGroups: ['calves'],
        category: 'legs',
      ),
      const ExerciseData(
        name: 'Seated Calf Raises',
        muscleGroups: ['calves'],
        category: 'legs',
      ),

      // ==================== CORE EXERCISES ====================
      const ExerciseData(
        name: 'Crunches',
        muscleGroups: ['abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Sit-ups',
        muscleGroups: ['abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Planks',
        muscleGroups: ['abs', 'obliques'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Side Planks',
        muscleGroups: ['obliques', 'abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Russian Twists',
        muscleGroups: ['obliques', 'abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Hanging Leg Raises',
        muscleGroups: ['abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Ab Wheel Rollout',
        muscleGroups: ['abs'],
        category: 'core',
      ),
      const ExerciseData(
        name: 'Cable Crunches',
        muscleGroups: ['abs'],
        category: 'core',
      ),

      // ==================== TRAPS EXERCISES ====================
      const ExerciseData(
        name: 'Shrugs',
        muscleGroups: ['traps'],
        category: 'back',
      ),
      const ExerciseData(
        name: 'Upright Row',
        muscleGroups: ['traps', 'shoulder'],
        category: 'back',
      ),
    ];
  }

  /// Get exercises count for logging/validation
  static int get exercisesCount => getDefaultExercises().length;

  /// Get exercises grouped by category
  static Map<String, List<ExerciseData>> getExercisesByCategory() {
    final exercises = getDefaultExercises();
    final Map<String, List<ExerciseData>> grouped = {};

    for (final exercise in exercises) {
      if (!grouped.containsKey(exercise.category)) {
        grouped[exercise.category] = [];
      }
      grouped[exercise.category]!.add(exercise);
    }

    return grouped;
  }
}

/// Data class for exercise seed data
/// Lighter than Exercise entity, used only for seeding
class ExerciseData {
  const ExerciseData({
    required this.name,
    required this.muscleGroups,
    required this.category,
  });

  final String name;
  final List<String> muscleGroups;
  final String category; // For organizational purposes

  /// Convert to Exercise entity for database insertion.
  ///
  /// Pass [ownerUserId] to create a user-owned exercise (e.g. for per-user
  /// seeding). Omit it (or pass null) to create a system/shared exercise
  /// with no owner, visible to all users.
  Exercise toEntity(String id, DateTime createdAt, {String? ownerUserId}) {
    return Exercise(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: createdAt,
    );
  }
}
