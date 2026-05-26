import '../../../domain/entities/nutrition_log.dart';

abstract class NutritionLogRemoteDataSource {
  bool get isConfigured;

  Future<List<NutritionLog>> getAllLogs();

  Future<NutritionLog?> getLogById(String id);

  Future<List<NutritionLog>> getLogsByDate(DateTime date);

  Future<List<NutritionLog>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<NutritionLog>> getLogsByMealId(String mealId);

  Future<NutritionLog> upsertLog(NutritionLog log);

  Future<void> deleteLog({required String localId, String? serverId});

  /// Returns all logs for [userId] whose `updated_at` is after [since].
  /// Pass [since] = null to fetch all logs (e.g. on initial re-login).
  Future<List<NutritionLog>> fetchSince({
    required String userId,
    DateTime? since,
  });
}
