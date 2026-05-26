import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/nutrition_log.dart';
import '../../repositories/nutrition_log_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

class GetLogsByDateRange {
  final NutritionLogRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetLogsByDateRange(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  Future<Either<Failure, List<NutritionLog>>> call({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    return repository.getLogsByDateRange(
      startDate,
      endDate,
      sourcePreference: sourcePreference,
    );
  }
}
