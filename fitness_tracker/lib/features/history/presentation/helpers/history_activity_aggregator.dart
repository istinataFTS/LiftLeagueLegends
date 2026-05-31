import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';
import '../models/day_activity.dart';

/// Aggregates per-day workout and nutrition activity for the history calendar.
///
/// The calendar renders one dot per activity *type* (yellow for exercise,
/// green for nutrition), so the aggregator returns counts split by type via
/// [DayActivity] rather than a single combined integer.
///
/// **Orphaned sets** (those whose [WorkoutSet.exerciseId] no longer resolves
/// to a library row) count toward the dot. The day-detail bottom sheet
/// renders them with an "Unknown exercise" label, so the user has a path to
/// inspect and act on orphans. A dot therefore promises real data the user
/// can open — just labelled in a degraded form.
class HistoryActivityAggregator {
  const HistoryActivityAggregator._();

  static DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DayActivity getActivityForDate({
    required Map<DateTime, List<WorkoutSet>> monthSets,
    required Map<DateTime, List<NutritionLog>> monthNutritionLogs,
    required DateTime date,
  }) {
    final DateTime normalizedDate = normalizeDate(date);

    final int exerciseSets = _countSets(monthSets[normalizedDate]);
    final int nutritionLogs = monthNutritionLogs[normalizedDate]?.length ?? 0;

    return DayActivity(
      exerciseSets: exerciseSets,
      nutritionLogs: nutritionLogs,
    );
  }

  static Map<DateTime, DayActivity> buildActivityCounts({
    required Map<DateTime, List<WorkoutSet>> monthSets,
    required Map<DateTime, List<NutritionLog>> monthNutritionLogs,
  }) {
    final Map<DateTime, int> exerciseByDate = <DateTime, int>{};
    final Map<DateTime, int> nutritionByDate = <DateTime, int>{};

    for (final MapEntry<DateTime, List<WorkoutSet>> entry
        in monthSets.entries) {
      final int count = _countSets(entry.value);
      if (count == 0) continue;
      final DateTime normalizedDate = normalizeDate(entry.key);
      exerciseByDate.update(
        normalizedDate,
        (int current) => current + count,
        ifAbsent: () => count,
      );
    }

    for (final MapEntry<DateTime, List<NutritionLog>> entry
        in monthNutritionLogs.entries) {
      if (entry.value.isEmpty) continue;
      final DateTime normalizedDate = normalizeDate(entry.key);
      nutritionByDate.update(
        normalizedDate,
        (int current) => current + entry.value.length,
        ifAbsent: () => entry.value.length,
      );
    }

    final Set<DateTime> allDates = <DateTime>{
      ...exerciseByDate.keys,
      ...nutritionByDate.keys,
    };

    return <DateTime, DayActivity>{
      for (final DateTime date in allDates)
        date: DayActivity(
          exerciseSets: exerciseByDate[date] ?? 0,
          nutritionLogs: nutritionByDate[date] ?? 0,
        ),
    };
  }

  static int _countSets(List<WorkoutSet>? sets) => sets?.length ?? 0;
}
