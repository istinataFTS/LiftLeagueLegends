import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetExerciseById {
  final ExerciseRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetExerciseById(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, Exercise?>> call(String id) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getExerciseById(id, sourcePreference: sourcePreference);
  }
}
