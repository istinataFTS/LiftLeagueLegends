import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/workout_set.dart';
import '../../repositories/workout_set_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetAllWorkoutSets {
  final WorkoutSetRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetAllWorkoutSets(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, List<WorkoutSet>>> call() async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getAllSets(sourcePreference: sourcePreference);
  }
}
