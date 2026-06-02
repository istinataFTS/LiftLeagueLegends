import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_exercise_dto.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_meal_dto.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_nutrition_log_dto.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fixture dates
// ---------------------------------------------------------------------------

final _createdAt = DateTime(2026, 4, 7, 10, 0, 0);
final _updatedAt = DateTime(2026, 4, 7, 11, 0, 0);

void main() {
  // =========================================================================
  // SupabaseExerciseDto
  // =========================================================================

  group('SupabaseExerciseDto', () {
    final _dtoMap = {
      'id': 'srv-1',
      'user_id': 'user-1',
      'name': 'Bench Press',
      'muscle_groups': ['chest', 'triceps'],
      'created_at': _createdAt.toIso8601String(),
      'updated_at': _updatedAt.toIso8601String(),
    };

    final _syncedMeta = EntitySyncMetadata(
      serverId: 'srv-1',
      status: SyncStatus.synced,
      lastSyncedAt: _updatedAt,
    );

    final _exerciseWithOwner = Exercise(
      id: 'local-1',
      ownerUserId: 'user-1',
      name: 'Bench Press',
      muscleGroups: const ['chest', 'triceps'],
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      syncMetadata: EntitySyncMetadata(
        serverId: 'srv-1',
        status: SyncStatus.pendingUpload,
      ),
    );

    group('fromMap', () {
      test('parses all fields from map', () {
        final dto = SupabaseExerciseDto.fromMap(_dtoMap);

        expect(dto.id, 'srv-1');
        expect(dto.userId, 'user-1');
        expect(dto.name, 'Bench Press');
        expect(dto.muscleGroups, ['chest', 'triceps']);
        expect(dto.createdAt, _createdAt);
        expect(dto.updatedAt, _updatedAt);
      });
    });

    group('fromEntity', () {
      test('maps entity fields to DTO (uses serverId if present)', () {
        final dto = SupabaseExerciseDto.fromEntity(_exerciseWithOwner);

        expect(dto.id, 'srv-1'); // uses syncMetadata.serverId
        expect(dto.userId, 'user-1');
        expect(dto.name, 'Bench Press');
        expect(dto.muscleGroups, ['chest', 'triceps']);
      });

      test('uses local id when no serverId is set', () {
        final exercise = Exercise(
          id: 'local-only',
          ownerUserId: 'user-1',
          name: 'Squat',
          muscleGroups: const ['quads'],
          createdAt: _createdAt,
        );
        final dto = SupabaseExerciseDto.fromEntity(exercise);
        expect(dto.id, 'local-only');
      });

      test('throws ArgumentError when ownerUserId is null', () {
        final exercise = Exercise(
          id: 'ex-1',
          name: 'Deadlift',
          muscleGroups: const ['back'],
          createdAt: _createdAt,
        );
        expect(
          () => SupabaseExerciseDto.fromEntity(exercise),
          throwsArgumentError,
        );
      });
    });

    group('toEntity', () {
      test('maps all DTO fields to entity', () {
        final dto = SupabaseExerciseDto.fromMap(_dtoMap);
        final entity = dto.toEntity(
          localId: 'local-1',
          syncMetadata: _syncedMeta,
        );

        expect(entity.id, 'local-1');
        expect(entity.ownerUserId, 'user-1');
        expect(entity.name, 'Bench Press');
        expect(entity.muscleGroups, ['chest', 'triceps']);
        expect(entity.syncMetadata, _syncedMeta);
      });
    });

    group('toSyncedMetadata', () {
      test('returns synced metadata with dto id and updatedAt', () {
        final dto = SupabaseExerciseDto.fromMap(_dtoMap);
        final meta = dto.toSyncedMetadata();

        expect(meta.serverId, 'srv-1');
        expect(meta.status, SyncStatus.synced);
        expect(meta.lastSyncedAt, _updatedAt);
      });
    });

    group('toMap', () {
      test('serialises non-timestamp fields correctly', () {
        final dto = SupabaseExerciseDto.fromMap(_dtoMap);
        final map = dto.toMap();

        expect(map['id'], 'srv-1');
        expect(map['user_id'], 'user-1');
        expect(map['name'], 'Bench Press');
        expect(map['muscle_groups'], ['chest', 'triceps']);
      });

      test('created_at and updated_at are Z-suffixed', () {
        final dto = SupabaseExerciseDto.fromMap(_dtoMap);
        final map = dto.toMap();
        expect((map['created_at'] as String).endsWith('Z'), isTrue);
        expect((map['updated_at'] as String).endsWith('Z'), isTrue);
      });
    });
  });

  // =========================================================================
  // SupabaseMealDto
  // =========================================================================

  group('SupabaseMealDto', () {
    final _dtoMap = {
      'id': 'srv-meal-1',
      'user_id': 'user-1',
      'name': 'Oats',
      'serving_size_grams': 100.0,
      'carbs_per_100g': 60.0,
      'protein_per_100g': 13.0,
      'fat_per_100g': 7.0,
      'calories_per_100g': 355.0,
      'created_at': _createdAt.toIso8601String(),
      'updated_at': _updatedAt.toIso8601String(),
    };

    final _syncedMeta = EntitySyncMetadata(
      serverId: 'srv-meal-1',
      status: SyncStatus.synced,
      lastSyncedAt: _updatedAt,
    );

    final _mealWithOwner = Meal(
      id: 'local-meal-1',
      ownerUserId: 'user-1',
      name: 'Oats',
      servingSizeGrams: 100,
      carbsPer100g: 60,
      proteinPer100g: 13,
      fatPer100g: 7,
      caloriesPer100g: 355,
      createdAt: _createdAt,
      updatedAt: _updatedAt,
      syncMetadata: EntitySyncMetadata(
        serverId: 'srv-meal-1',
        status: SyncStatus.pendingUpload,
      ),
    );

    group('fromMap', () {
      test('parses all fields from map', () {
        final dto = SupabaseMealDto.fromMap(_dtoMap);

        expect(dto.id, 'srv-meal-1');
        expect(dto.userId, 'user-1');
        expect(dto.name, 'Oats');
        expect(dto.servingSizeGrams, 100.0);
        expect(dto.carbsPer100g, 60.0);
        expect(dto.proteinPer100g, 13.0);
        expect(dto.fatPer100g, 7.0);
        expect(dto.caloriesPer100g, 355.0);
        expect(dto.createdAt, _createdAt);
        expect(dto.updatedAt, _updatedAt);
      });
    });

    group('fromEntity', () {
      test('maps entity to DTO correctly', () {
        final dto = SupabaseMealDto.fromEntity(_mealWithOwner);

        expect(dto.id, 'srv-meal-1');
        expect(dto.userId, 'user-1');
        expect(dto.name, 'Oats');
        expect(dto.servingSizeGrams, 100.0);
        expect(dto.caloriesPer100g, 355.0);
      });

      test('throws ArgumentError when ownerUserId is null', () {
        final meal = Meal(
          id: 'meal-no-owner',
          name: 'Orphan Meal',
          servingSizeGrams: 100,
          carbsPer100g: 50,
          proteinPer100g: 10,
          fatPer100g: 5,
          caloriesPer100g: 285,
          createdAt: _createdAt,
        );
        expect(() => SupabaseMealDto.fromEntity(meal), throwsArgumentError);
      });
    });

    group('toEntity', () {
      test('maps all DTO fields to entity', () {
        final dto = SupabaseMealDto.fromMap(_dtoMap);
        final entity = dto.toEntity(
          localId: 'local-meal-1',
          syncMetadata: _syncedMeta,
        );

        expect(entity.id, 'local-meal-1');
        expect(entity.ownerUserId, 'user-1');
        expect(entity.name, 'Oats');
        expect(entity.caloriesPer100g, 355.0);
        expect(entity.syncMetadata, _syncedMeta);
      });
    });

    group('toSyncedMetadata', () {
      test('returns synced metadata with dto id and updatedAt', () {
        final dto = SupabaseMealDto.fromMap(_dtoMap);
        final meta = dto.toSyncedMetadata();

        expect(meta.serverId, 'srv-meal-1');
        expect(meta.status, SyncStatus.synced);
        expect(meta.lastSyncedAt, _updatedAt);
      });
    });

    group('toMap', () {
      test('serialises all fields correctly', () {
        final dto = SupabaseMealDto.fromMap(_dtoMap);
        final map = dto.toMap();

        expect(map['id'], 'srv-meal-1');
        expect(map['user_id'], 'user-1');
        expect(map['name'], 'Oats');
        expect(map['serving_size_grams'], 100.0);
        expect(map['carbs_per_100g'], 60.0);
        expect(map['calories_per_100g'], 355.0);
      });
    });
  });

  // =========================================================================
  // SupabaseNutritionLogDto
  // =========================================================================

  group('SupabaseNutritionLogDto', () {
    final _dtoMap = {
      'id': 'srv-log-1',
      'user_id': 'user-1',
      'meal_id': 'meal-1',
      'meal_name': 'Oats',
      'grams_consumed': 100.0,
      'protein_grams': 13.0,
      'carbs_grams': 60.0,
      'fat_grams': 7.0,
      'calories': 355.0,
      'logged_at': _createdAt.toIso8601String(),
      'created_at': _createdAt.toIso8601String(),
      'updated_at': _updatedAt.toIso8601String(),
    };

    final _syncedMeta = EntitySyncMetadata(
      serverId: 'srv-log-1',
      status: SyncStatus.synced,
      lastSyncedAt: _updatedAt,
    );

    final _logWithOwner = NutritionLog(
      id: 'local-log-1',
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
      syncMetadata: EntitySyncMetadata(
        serverId: 'srv-log-1',
        status: SyncStatus.pendingUpload,
      ),
    );

    group('fromMap', () {
      test('parses all fields from map', () {
        final dto = SupabaseNutritionLogDto.fromMap(_dtoMap);

        expect(dto.id, 'srv-log-1');
        expect(dto.userId, 'user-1');
        expect(dto.mealId, 'meal-1');
        expect(dto.mealName, 'Oats');
        expect(dto.gramsConsumed, 100.0);
        expect(dto.proteinGrams, 13.0);
        expect(dto.carbsGrams, 60.0);
        expect(dto.fatGrams, 7.0);
        expect(dto.calories, 355.0);
        expect(dto.loggedAt, _createdAt);
        expect(dto.createdAt, _createdAt);
        expect(dto.updatedAt, _updatedAt);
      });

      test('parses null mealId and gramsConsumed for direct macro logs', () {
        final directMap = Map<String, dynamic>.from(_dtoMap)
          ..['meal_id'] = null
          ..['grams_consumed'] = null;

        final dto = SupabaseNutritionLogDto.fromMap(directMap);

        expect(dto.mealId, isNull);
        expect(dto.gramsConsumed, isNull);
      });
    });

    group('fromEntity', () {
      test('maps entity to DTO correctly', () {
        final dto = SupabaseNutritionLogDto.fromEntity(_logWithOwner);

        expect(dto.id, 'srv-log-1');
        expect(dto.userId, 'user-1');
        expect(dto.mealId, 'meal-1');
        expect(dto.mealName, 'Oats');
        expect(dto.calories, 355.0);
      });

      test('throws ArgumentError when ownerUserId is null', () {
        final log = NutritionLog(
          id: 'log-no-owner',
          mealName: 'Orphan log',
          proteinGrams: 10,
          carbsGrams: 20,
          fatGrams: 5,
          calories: 165,
          loggedAt: _createdAt,
          createdAt: _createdAt,
        );
        expect(
          () => SupabaseNutritionLogDto.fromEntity(log),
          throwsArgumentError,
        );
      });
    });

    group('toEntity', () {
      test('maps all DTO fields to entity', () {
        final dto = SupabaseNutritionLogDto.fromMap(_dtoMap);
        final entity = dto.toEntity(
          localId: 'local-log-1',
          syncMetadata: _syncedMeta,
        );

        expect(entity.id, 'local-log-1');
        expect(entity.ownerUserId, 'user-1');
        expect(entity.mealId, 'meal-1');
        expect(entity.mealName, 'Oats');
        expect(entity.calories, 355.0);
        expect(entity.syncMetadata, _syncedMeta);
      });
    });

    group('toSyncedMetadata', () {
      test('returns synced metadata with dto id and updatedAt', () {
        final dto = SupabaseNutritionLogDto.fromMap(_dtoMap);
        final meta = dto.toSyncedMetadata();

        expect(meta.serverId, 'srv-log-1');
        expect(meta.status, SyncStatus.synced);
        expect(meta.lastSyncedAt, _updatedAt);
      });
    });

    group('toMap', () {
      test('serialises non-timestamp fields correctly', () {
        final dto = SupabaseNutritionLogDto.fromMap(_dtoMap);
        final map = dto.toMap();

        expect(map['id'], 'srv-log-1');
        expect(map['user_id'], 'user-1');
        expect(map['meal_id'], 'meal-1');
        expect(map['meal_name'], 'Oats');
        expect(map['grams_consumed'], 100.0);
        expect(map['protein_grams'], 13.0);
        expect(map['calories'], 355.0);
      });

      test('logged_at, created_at, updated_at are Z-suffixed', () {
        final dto = SupabaseNutritionLogDto.fromMap(_dtoMap);
        final map = dto.toMap();
        expect((map['logged_at'] as String).endsWith('Z'), isTrue);
        expect((map['created_at'] as String).endsWith('Z'), isTrue);
        expect((map['updated_at'] as String).endsWith('Z'), isTrue);
      });
    });
  });
}
