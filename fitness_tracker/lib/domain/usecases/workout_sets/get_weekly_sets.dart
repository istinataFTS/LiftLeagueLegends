import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/workout_set.dart';
import '../../repositories/workout_set_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetWeeklySets {
  final WorkoutSetRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetWeeklySets(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, List<WorkoutSet>>> call() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final endDate = DateTime.now();
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getSetsByDateRange(
      startDate,
      endDate,
      sourcePreference: sourcePreference,
    );
  }
}
