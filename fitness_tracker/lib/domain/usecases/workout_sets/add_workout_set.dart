import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/workout_set.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/workout_set_repository.dart';
import '../muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';

class AddWorkoutSet {
  final WorkoutSetRepository repository;
  final AppSessionRepository appSessionRepository;
  final RebuildMuscleStimulusFromWorkoutHistory
  rebuildMuscleStimulusFromWorkoutHistory;

  const AddWorkoutSet(
    this.repository, {
    required this.appSessionRepository,
    required this.rebuildMuscleStimulusFromWorkoutHistory,
  });

  Future<Either<Failure, void>> call(WorkoutSet set) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    final userId = sessionResult.fold(
      (_) => '',
      (session) => session.user?.id ?? '',
    );

    final preparedSet = sessionResult.fold((_) => set, (session) {
      if (!session.isAuthenticated || session.user == null) {
        return set;
      }
      return set.copyWith(ownerUserId: session.user!.id);
    });

    final addResult = await repository.addSet(preparedSet);

    return addResult.fold(
      (failure) async => Left(failure),
      // Full rebuild ensures every subsequent date's rolling weekly load
      // reflects the newly-added set, regardless of which date it was
      // logged to. This mirrors the pattern used by DeleteWorkoutSet and
      // UpdateWorkoutSet so that all write paths stay consistent.
      (_) async => rebuildMuscleStimulusFromWorkoutHistory(userId),
    );
  }
}
