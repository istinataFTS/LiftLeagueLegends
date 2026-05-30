import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/workout_set.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/workout_set_repository.dart';
import '../muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';

/// Use case for updating an existing workout set
/// This allows users to edit past workout logs
class UpdateWorkoutSet {
  final WorkoutSetRepository repository;
  final AppSessionRepository appSessionRepository;
  final RebuildMuscleStimulusFromWorkoutHistory
  rebuildMuscleStimulusFromWorkoutHistory;

  const UpdateWorkoutSet(
    this.repository, {
    required this.appSessionRepository,
    required this.rebuildMuscleStimulusFromWorkoutHistory,
  });

  /// Update a workout set
  ///
  /// Parameters:
  /// - [set]: The updated WorkoutSet entity
  ///
  /// Returns: Either a Failure or void on success
  Future<Either<Failure, void>> call(WorkoutSet set) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    return await sessionResult.fold((failure) async => Left(failure), (
      session,
    ) async {
      final userId = session.user.id;
      final preparedSet = set.ownerUserId == userId
          ? set
          : set.copyWith(ownerUserId: userId);

      final updateResult = await repository.updateSet(preparedSet);

      return updateResult.fold(
        (failure) async => Left(failure),
        (_) async => rebuildMuscleStimulusFromWorkoutHistory(userId),
      );
    });
  }
}
