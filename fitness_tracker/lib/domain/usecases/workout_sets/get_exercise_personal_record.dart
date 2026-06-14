import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/workout_set.dart';
import '../../repositories/workout_set_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

/// Returns the user's personal-record set for the given exercise: the set with
/// the heaviest [WorkoutSet.weight] ever logged, tie-broken by higher [WorkoutSet.reps].
/// Returns `Right(null)` if no sets exist for the exercise.
class GetExercisePersonalRecord {
  final WorkoutSetRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetExercisePersonalRecord(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, WorkoutSet?>> call(String exerciseId) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();
    final result = await repository.getSetsByExerciseId(
      exerciseId,
      sourcePreference: sourcePreference,
    );
    return result.map((sets) {
      if (sets.isEmpty) return null;
      WorkoutSet best = sets.first;
      for (final set in sets.skip(1)) {
        if (set.weight > best.weight) {
          best = set;
        } else if (set.weight == best.weight && set.reps > best.reps) {
          best = set;
        }
      }
      return best;
    });
  }
}
