import '../../../core/constants/muscle_groups.dart';
import '../../../domain/entities/exercise.dart';

class LibraryExerciseFilters {
  const LibraryExerciseFilters._();

  static List<Exercise> apply({
    required List<Exercise> exercises,
    required String query,
    required String? selectedMuscle,
  }) {
    final String normalizedQuery = query.trim().toLowerCase();

    return exercises
        .where((Exercise exercise) {
          final bool matchesQuery =
              normalizedQuery.isEmpty ||
              exercise.name.toLowerCase().contains(normalizedQuery) ||
              exercise.muscleGroups.any(
                (String muscle) => MuscleGroups.getDisplayName(
                  muscle,
                ).toLowerCase().contains(normalizedQuery),
              );

          final bool matchesMuscle =
              selectedMuscle == null ||
              exercise.muscleGroups.contains(selectedMuscle);

          return matchesQuery && matchesMuscle;
        })
        .toList(growable: false);
  }
}
