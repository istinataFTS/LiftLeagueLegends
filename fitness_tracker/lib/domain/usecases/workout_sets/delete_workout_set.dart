import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/workout_set_repository.dart';
import '../muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';

/// Use case for deleting a workout set.
class DeleteWorkoutSet {
  final WorkoutSetRepository repository;
  final AppSessionRepository appSessionRepository;
  final RebuildMuscleStimulusFromWorkoutHistory
  rebuildMuscleStimulusFromWorkoutHistory;

  const DeleteWorkoutSet(
    this.repository, {
    required this.appSessionRepository,
    required this.rebuildMuscleStimulusFromWorkoutHistory,
  });

  Future<Either<Failure, void>> call(String id) async {
    final sessionResult = await appSessionRepository.getCurrentSession();
    final userId = sessionResult.fold((_) => '', (session) => session.user.id);

    final deleteResult = await repository.deleteSet(id);

    return deleteResult.fold(
      (failure) async => Left(failure),
      (_) async => rebuildMuscleStimulusFromWorkoutHistory(userId),
    );
  }
}
