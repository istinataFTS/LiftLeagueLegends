import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetAllExercises {
  final ExerciseRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetAllExercises(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, List<Exercise>>> call() async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getAllExercises(sourcePreference: sourcePreference);
  }
}
