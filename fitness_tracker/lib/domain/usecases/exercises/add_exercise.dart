import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../../core/session/current_user_id_resolver.dart';
import '../../entities/exercise.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../muscle_factors/sync_exercise_muscle_factors.dart';

class AddExercise {
  final ExerciseRepository repository;
  final AppSessionRepository appSessionRepository;
  final SyncExerciseMuscleFactors syncExerciseMuscleFactors;

  const AddExercise(
    this.repository, {
    required this.appSessionRepository,
    required this.syncExerciseMuscleFactors,
  });

  Future<Either<Failure, void>> call(
    Exercise exercise, {
    Map<String, double>? muscleFactors,
  }) async {
    // Muscle-group canonicalisation (lowercase + trim) is handled at the
    // model boundary in `ExerciseModel` and inside `SyncExerciseMuscleFactors`,
    // so we do not pre-normalise here.  Stamping the owner id is the only
    // decoration this use case owns.
    //
    // Every exercise is owned (per-user catalog model): the resolver returns
    // the authenticated user's id, or throws if no user is in context. This
    // is the same identifier readers use, so a row is always visible to the
    // account that created it.
    final ownerId = await CurrentUserIdResolver(
      appSessionRepository: appSessionRepository,
    ).resolve();

    final preparedExercise = exercise.copyWith(ownerUserId: ownerId);

    final addResult = await repository.addExercise(preparedExercise);

    return addResult.fold(
      (failure) async => Left(failure),
      (_) async => syncExerciseMuscleFactors(
        preparedExercise,
        muscleFactors: muscleFactors,
      ),
    );
  }
}
