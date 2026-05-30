import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../muscle_factors/sync_exercise_muscle_factors.dart';
import '../muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';

class UpdateExercise {
  final ExerciseRepository repository;
  final AppSessionRepository appSessionRepository;
  final SyncExerciseMuscleFactors syncExerciseMuscleFactors;
  final RebuildMuscleStimulusFromWorkoutHistory
  rebuildMuscleStimulusFromWorkoutHistory;

  const UpdateExercise(
    this.repository, {
    required this.appSessionRepository,
    required this.syncExerciseMuscleFactors,
    required this.rebuildMuscleStimulusFromWorkoutHistory,
  });

  Future<Either<Failure, void>> call(
    Exercise exercise, {
    Map<String, double>? muscleFactors,
  }) async {
    // Normalize muscle group names to lowercase at save time so the stored
    // data is always consistent, regardless of how the exercise was built
    // (UI chip selection, import, sync, etc.).
    final normalizedExercise = exercise.copyWith(
      muscleGroups: exercise.muscleGroups
          .map((m) => m.toLowerCase().trim())
          .toList(),
    );

    final sessionResult = await appSessionRepository.getCurrentSession();

    return await sessionResult.fold((failure) async => Left(failure), (
      session,
    ) async {
      final userId = session.user.id;
      final preparedExercise = normalizedExercise.ownerUserId == userId
          ? normalizedExercise
          : normalizedExercise.copyWith(ownerUserId: userId);

      final updateResult = await repository.updateExercise(preparedExercise);

      return updateResult.fold((failure) async => Left(failure), (_) async {
        final syncResult = await syncExerciseMuscleFactors(
          preparedExercise,
          muscleFactors: muscleFactors,
        );
        return syncResult.fold(
          (failure) async => Left(failure),
          (_) async => rebuildMuscleStimulusFromWorkoutHistory(userId),
        );
      });
    });
  }
}
