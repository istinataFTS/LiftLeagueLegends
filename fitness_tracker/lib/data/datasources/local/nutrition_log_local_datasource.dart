import '../../models/nutrition_log_model.dart';

abstract class NutritionLogLocalDataSource {
  Future<List<NutritionLogModel>> getAllLogs();

  Future<NutritionLogModel?> getLogById(String id);

  Future<List<NutritionLogModel>> getLogsByDate(DateTime date);

  Future<List<NutritionLogModel>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<NutritionLogModel>> getLogsByMealId(String mealId);

  Future<List<NutritionLogModel>> getTodayLogs();

  Future<List<NutritionLogModel>> getWeeklyLogs();

  Future<List<NutritionLogModel>> getMealLogs();

  Future<List<NutritionLogModel>> getDirectMacroLogs();

  Future<List<NutritionLogModel>> getPendingSyncLogs();

  Future<void> insertLog(NutritionLogModel log);

  Future<void> updateLog(NutritionLogModel log);

  Future<void> upsertLog(NutritionLogModel log);

  Future<void> prepareForInitialCloudMigration({required String userId});

  Future<void> mergeRemoteLogs(List<NutritionLogModel> logs);

  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  });

  Future<void> markAsPendingUpload(String localId, {String? errorMessage});

  Future<void> markAsPendingUpdate(String localId, {String? errorMessage});

  Future<void> markAsPendingDelete(String localId, {String? errorMessage});

  Future<void> replaceAllLogs(List<NutritionLogModel> logs);

  Future<void> deleteLog(String id);

  Future<void> deleteLogsByDate(DateTime date);

  Future<void> deleteLogsByMealId(String mealId);

  Future<void> clearAllLogs();

  Future<void> clearLogsForOwner(String ownerId);

  Future<Map<String, double>> getDailyMacros(DateTime date);
}
