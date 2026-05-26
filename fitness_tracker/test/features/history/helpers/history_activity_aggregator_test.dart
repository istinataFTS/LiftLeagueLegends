import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/features/history/presentation/helpers/history_activity_aggregator.dart';
import 'package:fitness_tracker/features/history/presentation/models/day_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 3, 18, 14, 30);

  WorkoutSet buildWorkoutSet({
    required String id,
    required DateTime date,
    String? exerciseId,
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: exerciseId ?? 'exercise-$id',
      reps: 10,
      weight: 80,
      date: date,
      createdAt: date,
    );
  }

  NutritionLog buildNutritionLog({required String id, required DateTime date}) {
    return NutritionLog(
      id: id,
      mealName: 'Meal $id',
      proteinGrams: 25,
      carbsGrams: 30,
      fatGrams: 10,
      calories: 310,
      loggedAt: date,
      createdAt: date,
    );
  }

  group('HistoryActivityAggregator', () {
    test('normalizeDate strips the time component', () {
      final DateTime result = HistoryActivityAggregator.normalizeDate(baseDate);

      expect(result, DateTime(2026, 3, 18));
      expect(result.hour, 0);
      expect(result.minute, 0);
      expect(result.second, 0);
      expect(result.millisecond, 0);
      expect(result.microsecond, 0);
    });

    test('getActivityForDate splits exercise and nutrition counts', () {
      final DateTime selectedDate = DateTime(2026, 3, 18, 22, 10);

      final Map<DateTime, List<WorkoutSet>> monthSets =
          <DateTime, List<WorkoutSet>>{
            DateTime(2026, 3, 18): <WorkoutSet>[
              buildWorkoutSet(id: 'w1', date: DateTime(2026, 3, 18, 8, 0)),
              buildWorkoutSet(id: 'w2', date: DateTime(2026, 3, 18, 18, 0)),
            ],
          };

      final Map<DateTime, List<NutritionLog>> monthNutritionLogs =
          <DateTime, List<NutritionLog>>{
            DateTime(2026, 3, 18): <NutritionLog>[
              buildNutritionLog(id: 'n1', date: DateTime(2026, 3, 18, 12, 0)),
            ],
          };

      final DayActivity result = HistoryActivityAggregator.getActivityForDate(
        monthSets: monthSets,
        monthNutritionLogs: monthNutritionLogs,
        date: selectedDate,
      );

      expect(result.exerciseSets, 2);
      expect(result.nutritionLogs, 1);
      expect(result.total, 3);
      expect(result.hasExercise, isTrue);
      expect(result.hasNutrition, isTrue);
    });

    test('getActivityForDate returns DayActivity.none when nothing logged', () {
      final DayActivity result = HistoryActivityAggregator.getActivityForDate(
        monthSets: const <DateTime, List<WorkoutSet>>{},
        monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
        date: DateTime(2026, 3, 19, 9, 0),
      );

      expect(result, DayActivity.none);
      expect(result.hasAny, isFalse);
    });

    test('buildActivityCounts returns separate counts per type per date', () {
      final Map<DateTime, List<WorkoutSet>> monthSets =
          <DateTime, List<WorkoutSet>>{
            DateTime(2026, 3, 18, 6, 30): <WorkoutSet>[
              buildWorkoutSet(id: 'w1', date: DateTime(2026, 3, 18, 6, 30)),
              buildWorkoutSet(id: 'w2', date: DateTime(2026, 3, 18, 19, 0)),
            ],
            DateTime(2026, 3, 19, 7, 0): <WorkoutSet>[
              buildWorkoutSet(id: 'w3', date: DateTime(2026, 3, 19, 7, 0)),
            ],
          };

      final Map<DateTime, List<NutritionLog>> monthNutritionLogs =
          <DateTime, List<NutritionLog>>{
            DateTime(2026, 3, 18, 12, 0): <NutritionLog>[
              buildNutritionLog(id: 'n1', date: DateTime(2026, 3, 18, 12, 0)),
              buildNutritionLog(id: 'n2', date: DateTime(2026, 3, 18, 20, 0)),
            ],
            DateTime(2026, 3, 20, 9, 15): <NutritionLog>[
              buildNutritionLog(id: 'n3', date: DateTime(2026, 3, 20, 9, 15)),
            ],
          };

      final Map<DateTime, DayActivity> result =
          HistoryActivityAggregator.buildActivityCounts(
            monthSets: monthSets,
            monthNutritionLogs: monthNutritionLogs,
          );

      expect(result, <DateTime, DayActivity>{
        DateTime(2026, 3, 18): const DayActivity(
          exerciseSets: 2,
          nutritionLogs: 2,
        ),
        DateTime(2026, 3, 19): const DayActivity(
          exerciseSets: 1,
          nutritionLogs: 0,
        ),
        DateTime(2026, 3, 20): const DayActivity(
          exerciseSets: 0,
          nutritionLogs: 1,
        ),
      });
    });

    test(
      'buildActivityCounts excludes orphan workout sets when ids provided',
      () {
        final Map<DateTime, List<WorkoutSet>> monthSets =
            <DateTime, List<WorkoutSet>>{
              DateTime(2026, 3, 18): <WorkoutSet>[
                buildWorkoutSet(
                  id: 'w1',
                  date: DateTime(2026, 3, 18, 8, 0),
                  exerciseId: 'known',
                ),
                buildWorkoutSet(
                  id: 'w2',
                  date: DateTime(2026, 3, 18, 18, 0),
                  exerciseId: 'deleted',
                ),
              ],
              DateTime(2026, 3, 19): <WorkoutSet>[
                buildWorkoutSet(
                  id: 'w3',
                  date: DateTime(2026, 3, 19, 8, 0),
                  exerciseId: 'deleted',
                ),
              ],
            };

        final Map<DateTime, DayActivity> result =
            HistoryActivityAggregator.buildActivityCounts(
              monthSets: monthSets,
              monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
              resolvableExerciseIds: const <String>{'known'},
            );

        expect(result, <DateTime, DayActivity>{
          DateTime(2026, 3, 18): const DayActivity(
            exerciseSets: 1,
            nutritionLogs: 0,
          ),
        });
        expect(result.containsKey(DateTime(2026, 3, 19)), isFalse);
      },
    );

    test('buildActivityCounts counts every set when no id-set is supplied', () {
      final Map<DateTime, List<WorkoutSet>> monthSets =
          <DateTime, List<WorkoutSet>>{
            DateTime(2026, 3, 18): <WorkoutSet>[
              buildWorkoutSet(
                id: 'w1',
                date: DateTime(2026, 3, 18, 8, 0),
                exerciseId: 'anything',
              ),
            ],
          };

      final Map<DateTime, DayActivity> result =
          HistoryActivityAggregator.buildActivityCounts(
            monthSets: monthSets,
            monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
          );

      expect(
        result[DateTime(2026, 3, 18)],
        const DayActivity(exerciseSets: 1, nutritionLogs: 0),
      );
    });

    test('buildActivityCounts returns empty map when nothing logged', () {
      final Map<DateTime, DayActivity> result =
          HistoryActivityAggregator.buildActivityCounts(
            monthSets: const <DateTime, List<WorkoutSet>>{},
            monthNutritionLogs: const <DateTime, List<NutritionLog>>{},
          );

      expect(result, isEmpty);
    });
  });
}
