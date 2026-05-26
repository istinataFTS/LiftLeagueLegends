import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/models/exercise_model.dart';
import 'package:fitness_tracker/data/models/meal_model.dart';
import 'package:fitness_tracker/data/models/muscle_stimulus_model.dart';
import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Shared fixture dates
// ---------------------------------------------------------------------------

final _createdAt = DateTime(2026, 4, 7, 10, 0, 0);
final _updatedAt = DateTime(2026, 4, 7, 11, 0, 0);
final _syncedAt = DateTime(2026, 4, 7, 12, 0, 0);

void main() {
  // =========================================================================
  // ExerciseModel
  // =========================================================================

  group('ExerciseModel', () {
    final _exerciseEntity = Exercise(
      id: 'ex-1',
      ownerUserId: 'user-1',
      name: 'Bench Press',
      muscleGroups: const ['chest', 'triceps'],
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      syncMetadata: EntitySyncMetadata(
        serverId: 'srv-1',
        status: SyncStatus.synced,
        lastSyncedAt: _syncedAt,
      ),
    );

    group('fromMap / toMap', () {
      test('round-trips all fields through map serialisation', () {
        final model = ExerciseModel.fromEntity(_exerciseEntity);
        final map = model.toMap();
        final restored = ExerciseModel.fromMap(map);

        expect(restored.id, 'ex-1');
        expect(restored.ownerUserId, 'user-1');
        expect(restored.name, 'Bench Press');
        expect(restored.muscleGroups, ['chest', 'triceps']);
        expect(restored.createdAt, _createdAt);
        expect(restored.updatedAt, _updatedAt);
        expect(restored.syncMetadata.serverId, 'srv-1');
        expect(restored.syncMetadata.status, SyncStatus.synced);
        expect(restored.syncMetadata.lastSyncedAt, _syncedAt);
      });

      test('fromMap defaults syncStatus to localOnly for unknown value', () {
        final model = ExerciseModel.fromEntity(_exerciseEntity);
        final map = model.toMap()..['sync_status'] = 'unknown_value';
        final restored = ExerciseModel.fromMap(map);

        expect(restored.syncMetadata.status, SyncStatus.localOnly);
      });

      test('fromMap uses createdAt for updatedAt when updatedAt is null', () {
        final model = ExerciseModel.fromEntity(_exerciseEntity);
        final map = model.toMap()..['updated_at'] = null;
        final restored = ExerciseModel.fromMap(map);

        expect(restored.updatedAt, _createdAt);
      });
    });

    group('fromEntity', () {
      test('copies all entity fields correctly', () {
        final model = ExerciseModel.fromEntity(_exerciseEntity);

        expect(model.id, _exerciseEntity.id);
        expect(model.ownerUserId, _exerciseEntity.ownerUserId);
        expect(model.name, _exerciseEntity.name);
        expect(model.muscleGroups, _exerciseEntity.muscleGroups);
        expect(model.createdAt, _exerciseEntity.createdAt);
        expect(model.syncMetadata, _exerciseEntity.syncMetadata);
      });
    });

    group('fromJson / toJson', () {
      test('round-trips all fields through JSON serialisation', () {
        final model = ExerciseModel.fromEntity(_exerciseEntity);
        final json = model.toJson();
        final restored = ExerciseModel.fromJson(json);

        expect(restored.id, 'ex-1');
        expect(restored.name, 'Bench Press');
        expect(restored.muscleGroups, ['chest', 'triceps']);
        expect(restored.syncMetadata.serverId, 'srv-1');
      });
    });
  });

  // =========================================================================
  // MealModel
  // =========================================================================

  group('MealModel', () {
    final _mealEntity = Meal(
      id: 'meal-1',
      ownerUserId: 'user-1',
      name: 'Oats',
      servingSizeGrams: 100,
      carbsPer100g: 60,
      proteinPer100g: 13,
      fatPer100g: 7,
      caloriesPer100g: 358, // 60*4 + 13*4 + 7*9 = 240+52+63 = 355 ≈ ok within 5
      createdAt: _createdAt,
      updatedAt: _updatedAt,
    );

    group('fromMap / toMap', () {
      test('round-trips all fields through map serialisation', () {
        final model = MealModel.fromEntity(_mealEntity);
        final map = model.toMap();
        final restored = MealModel.fromMap(map);

        expect(restored.id, 'meal-1');
        expect(restored.name, 'Oats');
        expect(restored.servingSizeGrams, 100);
        expect(restored.carbsPer100g, 60);
        expect(restored.proteinPer100g, 13);
        expect(restored.fatPer100g, 7);
        expect(restored.caloriesPer100g, 358);
        expect(restored.createdAt, _createdAt);
        expect(restored.updatedAt, _updatedAt);
      });
    });

    group('fromEntity', () {
      test('copies all entity fields correctly', () {
        final model = MealModel.fromEntity(_mealEntity);

        expect(model.id, _mealEntity.id);
        expect(model.name, _mealEntity.name);
        expect(model.servingSizeGrams, _mealEntity.servingSizeGrams);
        expect(model.caloriesPer100g, _mealEntity.caloriesPer100g);
      });
    });

    group('hasValidCalories', () {
      test(
        'returns true when stated calories match macros within tolerance',
        () {
          // 60*4 + 13*4 + 7*9 = 240 + 52 + 63 = 355, stated 358 → diff=3 ≤ 5
          final model = MealModel.fromEntity(_mealEntity);
          expect(model.hasValidCalories, isTrue);
        },
      );

      test('returns false when stated calories differ by more than 5 kcal', () {
        final meal = Meal(
          id: 'meal-bad',
          name: 'Bad Macro',
          servingSizeGrams: 100,
          carbsPer100g: 60,
          proteinPer100g: 13,
          fatPer100g: 7,
          caloriesPer100g: 400, // 400 - 355 = 45, well outside ±5
          createdAt: _createdAt,
        );
        final model = MealModel.fromEntity(meal);
        expect(model.hasValidCalories, isFalse);
      });
    });

    group('validateMacros', () {
      test('throws ArgumentError when name is blank', () {
        final model = MealModel(
          id: 'x',
          name: '   ',
          servingSizeGrams: 100,
          carbsPer100g: 50,
          proteinPer100g: 10,
          fatPer100g: 5,
          caloriesPer100g: 285,
          createdAt: _createdAt,
        );
        expect(() => model.validateMacros(), throwsArgumentError);
      });

      test('throws ArgumentError when servingSizeGrams is zero', () {
        final model = MealModel(
          id: 'x',
          name: 'Rice',
          servingSizeGrams: 0,
          carbsPer100g: 50,
          proteinPer100g: 10,
          fatPer100g: 5,
          caloriesPer100g: 285,
          createdAt: _createdAt,
        );
        expect(() => model.validateMacros(), throwsArgumentError);
      });

      test('throws ArgumentError when a macro is negative', () {
        final model = MealModel(
          id: 'x',
          name: 'Rice',
          servingSizeGrams: 100,
          carbsPer100g: -1,
          proteinPer100g: 10,
          fatPer100g: 5,
          caloriesPer100g: 0,
          createdAt: _createdAt,
        );
        expect(() => model.validateMacros(), throwsArgumentError);
      });
    });

    group('withCalculatedMacros', () {
      test(
        'calculates calories from macros when caloriesPer100g is not given',
        () {
          final model = MealModel.withCalculatedMacros(
            id: 'x',
            name: 'Rice',
            carbsPer100g: 40,
            proteinPer100g: 5,
            fatPer100g: 1,
            // 40*4 + 5*4 + 1*9 = 160 + 20 + 9 = 189
          );
          expect(model.caloriesPer100g, closeTo(189.0, 0.01));
        },
      );

      test(
        'calculates missing carbs when calories and other macros are given',
        () {
          final model = MealModel.withCalculatedMacros(
            id: 'x',
            name: 'Custom',
            caloriesPer100g: 200,
            proteinPer100g: 10,
            fatPer100g: 5,
            // carbs = (200 - 10*4 - 5*9) / 4 = (200 - 40 - 45) / 4 = 115/4 = 28.75
          );
          expect(model.carbsPer100g, closeTo(28.75, 0.01));
        },
      );
    });
  });

  // =========================================================================
  // NutritionLogModel
  // =========================================================================

  group('NutritionLogModel', () {
    final _logEntity = NutritionLog(
      id: 'log-1',
      ownerUserId: 'user-1',
      mealId: 'meal-1',
      mealName: 'Oats',
      gramsConsumed: 100,
      proteinGrams: 13,
      carbsGrams: 60,
      fatGrams: 7,
      calories: 355,
      loggedAt: _createdAt,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
    );

    group('fromMap / toMap', () {
      test('round-trips all fields through map serialisation', () {
        final model = NutritionLogModel.fromEntity(_logEntity);
        final map = model.toMap();
        final restored = NutritionLogModel.fromMap(map);

        expect(restored.id, 'log-1');
        expect(restored.mealName, 'Oats');
        expect(restored.gramsConsumed, 100);
        expect(restored.proteinGrams, 13);
        expect(restored.carbsGrams, 60);
        expect(restored.fatGrams, 7);
        expect(restored.calories, 355);
        expect(restored.loggedAt, _createdAt);
      });

      test('preserves null mealId and gramsConsumed', () {
        final directLog = NutritionLog(
          id: 'log-2',
          mealName: 'Custom protein shake',
          proteinGrams: 30,
          carbsGrams: 5,
          fatGrams: 2,
          calories: 158,
          loggedAt: _createdAt,
          createdAt: _createdAt,
        );
        final model = NutritionLogModel.fromEntity(directLog);
        final restored = NutritionLogModel.fromMap(model.toMap());

        expect(restored.mealId, isNull);
        expect(restored.gramsConsumed, isNull);
      });
    });

    group('fromEntity', () {
      test('copies all entity fields correctly', () {
        final model = NutritionLogModel.fromEntity(_logEntity);

        expect(model.id, _logEntity.id);
        expect(model.mealId, _logEntity.mealId);
        expect(model.mealName, _logEntity.mealName);
        expect(model.calories, _logEntity.calories);
        expect(model.loggedAt, _logEntity.loggedAt);
      });
    });
  });

  // =========================================================================
  // MuscleStimulusModel
  // =========================================================================

  group('MuscleStimulusModel', () {
    final _stimulusEntity = MuscleStimulus(
      id: 'stim-1',
      ownerUserId: 'user-1',
      muscleGroup: 'chest',
      date: _createdAt,
      dailyStimulus: 5.0,
      rollingWeeklyLoad: 10.0,
      lastSetTimestamp: 1000,
      lastSetStimulus: 2.0,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
    );

    group('fromMap / toMap', () {
      test('round-trips all fields through map serialisation', () {
        final model = MuscleStimulusModel.fromEntity(_stimulusEntity);
        final map = model.toMap();
        final restored = MuscleStimulusModel.fromMap(map);

        expect(restored.id, 'stim-1');
        expect(restored.muscleGroup, 'chest');
        expect(restored.dailyStimulus, 5.0);
        expect(restored.rollingWeeklyLoad, 10.0);
        expect(restored.lastSetTimestamp, 1000);
        expect(restored.lastSetStimulus, 2.0);
        expect(restored.createdAt, _createdAt);
        expect(restored.updatedAt, _updatedAt);
      });

      test('preserves null optional fields', () {
        final stimulusNoOptionals = MuscleStimulus(
          id: 'stim-2',
          ownerUserId: '',
          muscleGroup: 'back',
          date: _createdAt,
          dailyStimulus: 3.0,
          rollingWeeklyLoad: 6.0,
          createdAt: _createdAt,
          updatedAt: _updatedAt,
        );
        final model = MuscleStimulusModel.fromEntity(stimulusNoOptionals);
        final restored = MuscleStimulusModel.fromMap(model.toMap());

        expect(restored.lastSetTimestamp, isNull);
        expect(restored.lastSetStimulus, isNull);
      });
    });

    group('formatDateForDb', () {
      test('formats date as YYYY-MM-DD with zero-padded month and day', () {
        expect(
          MuscleStimulusModel.formatDateForDb(DateTime(2026, 4, 7)),
          '2026-04-07',
        );
      });

      test('pads single-digit month and day', () {
        expect(
          MuscleStimulusModel.formatDateForDb(DateTime(2026, 1, 5)),
          '2026-01-05',
        );
      });
    });

    group('parseDateFromDb', () {
      test('parses YYYY-MM-DD string back to DateTime', () {
        final date = MuscleStimulusModel.parseDateFromDb('2026-04-07');
        expect(date, DateTime(2026, 4, 7));
      });
    });
  });
}
