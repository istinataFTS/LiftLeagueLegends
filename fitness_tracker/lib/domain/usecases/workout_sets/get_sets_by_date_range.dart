import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../entities/workout_set.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/workout_set_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

/// Use case for getting workout sets filtered by date range and optionally by muscle group
/// This encapsulates the business logic for history filtering
class GetSetsByDateRange {
  final WorkoutSetRepository workoutSetRepository;
  final ExerciseRepository exerciseRepository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetSetsByDateRange({
    required this.workoutSetRepository,
    required this.exerciseRepository,
    required this.sourcePreferenceResolver,
  });

  /// Get sets filtered by date range and optionally by muscle group
  ///
  /// Parameters:
  /// - [startDate]: Start of date range (inclusive)
  /// - [endDate]: End of date range (inclusive)
  /// - [muscleGroup]: Optional muscle group filter (if null, returns all sets)
  ///
  /// Returns: Either a Failure or a List of WorkoutSets
  Future<Either<Failure, List<WorkoutSet>>> call({
    required DateTime startDate,
    required DateTime endDate,
    String? muscleGroup,
  }) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    final setsResult = await workoutSetRepository.getSetsByDateRange(
      startDate,
      endDate,
      sourcePreference: sourcePreference,
    );

    if (muscleGroup == null) {
      return setsResult;
    }

    return setsResult.fold((failure) => Left(failure), (sets) async {
      final exercisesResult = await exerciseRepository.getAllExercises(
        sourcePreference: sourcePreference,
      );

      return exercisesResult.fold((failure) => Left(failure), (exercises) {
        final exerciseMap = <String, Exercise>{
          for (final exercise in exercises) exercise.id: exercise,
        };

        final filteredSets = sets.where((set) {
          final exercise = exerciseMap[set.exerciseId];
          if (exercise == null) {
            return false;
          }

          return exercise.muscleGroups.contains(muscleGroup);
        }).toList();

        return Right(filteredSets);
      });
    });
  }
}
