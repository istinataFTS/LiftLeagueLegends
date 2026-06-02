import '../../../domain/entities/nutrition_log.dart';
import 'nutrition_log_remote_datasource.dart';

class NoopNutritionLogRemoteDataSource implements NutritionLogRemoteDataSource {
  const NoopNutritionLogRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<List<NutritionLog>> getAllLogs() async {
    return const <NutritionLog>[];
  }

  @override
  Future<NutritionLog?> getLogById(String id) async {
    return null;
  }

  @override
  Future<List<NutritionLog>> getLogsByDate(DateTime date) async {
    return const <NutritionLog>[];
  }

  @override
  Future<List<NutritionLog>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return const <NutritionLog>[];
  }

  @override
  Future<List<NutritionLog>> getLogsByMealId(String mealId) async {
    return const <NutritionLog>[];
  }

  @override
  Future<NutritionLog> upsertLog(NutritionLog log) async {
    return log;
  }

  @override
  Future<void> deleteLog({required String localId, String? serverId}) async {}

  @override
  Future<List<NutritionLog>> fetchByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async => const <NutritionLog>[];

  @override
  Future<List<NutritionLog>> fetchSince({
    required String userId,
    DateTime? since,
  }) async => const <NutritionLog>[];
}
