import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../repositories/nutrition_log_repository.dart';
import '../../services/authenticated_data_source_preference_resolver.dart';

/// Use case for calculating total daily macros from all nutrition logs
/// Returns aggregated totals: protein, carbs, fats, calories
class GetDailyMacros {
  final NutritionLogRepository repository;
  final AuthenticatedDataSourcePreferenceResolver sourcePreferenceResolver;

  const GetDailyMacros(
    this.repository, {
    required this.sourcePreferenceResolver,
  });

  /// Calculate total macros for a specific date
  /// Returns map with keys: 'protein', 'carbs', 'fats', 'calories'
  Future<Either<Failure, Map<String, double>>> call(DateTime date) async {
    final sourcePreference = await sourcePreferenceResolver
        .resolveReadPreference();

    final result = await repository.getLogsForDate(
      date,
      sourcePreference: sourcePreference,
    );

    return result.fold((failure) => Left(failure), (logs) {
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFats = 0;
      double totalCalories = 0;

      for (final log in logs) {
        totalProtein += log.proteinGrams;
        totalCarbs += log.carbsGrams;
        totalFats += log.fatGrams;
        totalCalories += log.calories;
      }

      return Right({
        'protein': totalProtein,
        'carbs': totalCarbs,
        'fats': totalFats,
        'calories': totalCalories,
      });
    });
  }
}
