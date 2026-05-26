import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../entities/nutrition_log.dart';

abstract class NutritionLogRepository {
  Future<Either<Failure, List<NutritionLog>>> getAllLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, NutritionLog?>> getLogById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getLogsByDate(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getLogsForDate(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getLogsByMealId(
    String mealId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getTodayLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getWeeklyLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getMealLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<NutritionLog>>> getDirectMacroLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, void>> addLog(NutritionLog log);

  Future<Either<Failure, void>> updateLog(NutritionLog log);

  Future<Either<Failure, void>> deleteLog(String id);

  Future<Either<Failure, void>> deleteLogsByDate(DateTime date);

  Future<Either<Failure, void>> deleteLogsByMealId(String mealId);

  Future<Either<Failure, void>> clearAllLogs();

  Future<Either<Failure, int>> getLogsCount();

  Future<Either<Failure, DailyMacros>> getDailyMacros(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, void>> syncPendingLogs();
}

class DailyMacros {
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;
  final double totalCalories;
  final DateTime date;
  final int logsCount;

  const DailyMacros({
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCalories,
    required this.date,
    required this.logsCount,
  });

  bool get hasLogs => logsCount > 0;

  double get calculatedCalories {
    return (totalCarbs * 4.0) + (totalProtein * 4.0) + (totalFat * 9.0);
  }
}
