import 'package:equatable/equatable.dart';

import '../../../../core/constants/muscle_groups.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';

class HistoryWorkoutSummary extends Equatable {
  /// Muscle counts sorted descending by [HistoryMuscleCount.directSetCount].
  final List<HistoryMuscleCount> muscleCounts;
  final int totalSets;

  const HistoryWorkoutSummary({
    required this.muscleCounts,
    required this.totalSets,
  });

  @override
  List<Object?> get props => [muscleCounts, totalSets];
}

class HistoryMuscleCount extends Equatable {
  final String muscleGroup;
  final String displayName;

  /// Number of sets whose exercise lists this muscle group directly.
  final int directSetCount;

  const HistoryMuscleCount({
    required this.muscleGroup,
    required this.displayName,
    required this.directSetCount,
  });

  @override
  List<Object?> get props => [muscleGroup, directSetCount];
}

class HistoryWorkoutSummaryBuilder {
  const HistoryWorkoutSummaryBuilder._();

  static HistoryWorkoutSummary build({
    required List<WorkoutSet> sets,
    required Map<String, Exercise> exerciseById,
  }) {
    if (sets.isEmpty) {
      return const HistoryWorkoutSummary(muscleCounts: [], totalSets: 0);
    }

    final Map<String, int> counts = <String, int>{};

    for (final WorkoutSet set in sets) {
      final Exercise? exercise = exerciseById[set.exerciseId];
      if (exercise == null) continue;

      for (final String muscleGroup in exercise.muscleGroups) {
        counts[muscleGroup] = (counts[muscleGroup] ?? 0) + 1;
      }
    }

    final List<HistoryMuscleCount> muscleCounts =
        counts.entries
            .map(
              (MapEntry<String, int> e) => HistoryMuscleCount(
                muscleGroup: e.key,
                displayName: MuscleGroups.getDisplayName(e.key),
                directSetCount: e.value,
              ),
            )
            .toList()
          ..sort(
            (HistoryMuscleCount a, HistoryMuscleCount b) =>
                b.directSetCount.compareTo(a.directSetCount),
          );

    return HistoryWorkoutSummary(
      muscleCounts: muscleCounts,
      totalSets: sets.length,
    );
  }
}
