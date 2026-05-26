import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetExercisesForMuscle {
  final ExerciseRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetExercisesForMuscle(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, List<Exercise>>> call(String muscleGroup) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getExercisesForMuscle(
      muscleGroup,
      sourcePreference: sourcePreference,
    );
  }
}
