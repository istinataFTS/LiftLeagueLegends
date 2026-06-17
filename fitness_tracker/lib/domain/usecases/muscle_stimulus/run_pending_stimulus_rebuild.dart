import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/stimulus_rebuild_flag_repository.dart';
import 'rebuild_muscle_stimulus_from_workout_history.dart';

/// Runs the one-time `muscle_stimulus` rebuild flagged by the v26 migration.
///
/// Why this exists: the post-sync [MuscleStimulusRebuildHook] only fires when a
/// remote sync actually runs. A returning user who opens the app **offline**
/// right after the upgrade would otherwise see an empty fatigue map (the
/// migration clears `muscle_stimulus`) until their next online sync. This use
/// case rebuilds the projection at launch, independent of network state,
/// exactly once — it clears the flag only after a successful rebuild, so a
/// transient failure (or no signed-in session yet) simply retries next launch.
class RunPendingStimulusRebuild {
  RunPendingStimulusRebuild({
    required this.flagRepository,
    required this.appSessionRepository,
    required this.rebuild,
  });

  final StimulusRebuildFlagRepository flagRepository;
  final AppSessionRepository appSessionRepository;
  final RebuildMuscleStimulusFromWorkoutHistory rebuild;

  Future<Either<Failure, void>> call() async {
    if (!await flagRepository.isPending()) {
      return const Right(null);
    }

    final sessionResult = await appSessionRepository.getCurrentSession();

    return sessionResult.fold((failure) async => Left(failure), (
      session,
    ) async {
      final rebuildResult = await rebuild(session.user.id);

      return rebuildResult.fold((failure) async => Left(failure), (_) async {
        await flagRepository.clear();
        return const Right(null);
      });
    });
  }
}
