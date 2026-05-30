import 'package:sqflite/sqflite.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/enums/sync_status.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/sync/local_remote_merge.dart';
import '../../models/meal_model.dart';
import 'meal_local_datasource.dart';
import 'user_scoped_local_datasource.dart';

class MealLocalDataSourceImpl extends UserScopedLocalDatasource
    implements MealLocalDataSource {
  static final LocalRemoteMerge<MealModel> _merge = LocalRemoteMerge<MealModel>(
    getId: (meal) => meal.id,
    getUpdatedAt: (meal) => meal.updatedAt,
    getSyncMetadata: (meal) => meal.syncMetadata,
  );

  MealLocalDataSourceImpl({
    required super.databaseHelper,
    required super.currentUserIdResolver,
  });

  @override
  Future<List<MealModel>> getAllMeals() async {
    try {
      return await _getVisibleMeals();
    } catch (e) {
      throw CacheDatabaseException('Failed to get all meals: $e');
    }
  }

  @override
  Future<MealModel?> getMealById(String id) async {
    try {
      return await _getVisibleMealById(id);
    } catch (e) {
      throw CacheDatabaseException('Failed to get meal by ID: $e');
    }
  }

  @override
  Future<MealModel?> getMealByName(String name) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            'LOWER(${DatabaseTables.mealName}) = LOWER(?) AND '
            '(${DatabaseTables.mealSyncStatus} IS NULL OR ${DatabaseTables.mealSyncStatus} != ?)',
        extraArgs: [name, SyncStatus.pendingDelete.name],
      );
      final maps = await db.query(
        DatabaseTables.meals,
        where: f.where,
        whereArgs: f.whereArgs,
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      return MealModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException('Failed to get meal by name: $e');
    }
  }

  @override
  Future<List<MealModel>> searchMealsByName(String searchTerm) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            'LOWER(${DatabaseTables.mealName}) LIKE LOWER(?) AND '
            '(${DatabaseTables.mealSyncStatus} IS NULL OR ${DatabaseTables.mealSyncStatus} != ?)',
        extraArgs: ['%$searchTerm%', SyncStatus.pendingDelete.name],
      );
      final maps = await db.query(
        DatabaseTables.meals,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: DatabaseTables.mealName,
      );
      return maps.map(MealModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to search meals: $e');
    }
  }

  @override
  Future<List<MealModel>> getRecentMeals({int limit = 10}) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '(${DatabaseTables.mealSyncStatus} IS NULL OR ${DatabaseTables.mealSyncStatus} != ?)',
        extraArgs: [SyncStatus.pendingDelete.name],
      );
      final maps = await db.query(
        DatabaseTables.meals,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.mealCreatedAt} DESC',
        limit: limit,
      );
      return maps.map(MealModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get recent meals: $e');
    }
  }

  @override
  Future<List<MealModel>> getFrequentMeals({int limit = 10}) async {
    return getRecentMeals(limit: limit);
  }

  @override
  Future<List<MealModel>> getPendingSyncMeals() async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '(${DatabaseTables.mealSyncStatus} = ? OR ${DatabaseTables.mealSyncStatus} = ?)',
        extraArgs: [
          SyncStatus.pendingUpload.name,
          SyncStatus.pendingUpdate.name,
        ],
      );
      final maps = await db.query(
        DatabaseTables.meals,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.mealUpdatedAt} ASC',
      );
      return maps.map(MealModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get pending sync meals: $e');
    }
  }

  @override
  Future<void> insertMeal(MealModel meal) async {
    try {
      final db = await databaseHelper.database;
      await db.insert(
        DatabaseTables.meals,
        meal.toMap(),
        // abort — never silently replace an existing row. The schema enforces
        // UNIQUE(name, COALESCE(owner_user_id, '')) so legitimate same-name
        // pairs from different owners are fine; same-owner duplicates are a
        // caller bug. Using replace here could cascade-delete nutrition_logs
        // via the ON DELETE CASCADE FK on nutrition_logs.meal_id.
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to insert meal "${meal.name}" '
        '(owner: ${meal.ownerUserId ?? 'system'}): $e',
      );
    }
  }

  @override
  Future<void> updateMeal(MealModel meal) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.meals,
        meal.toMap(),
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [meal.id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to update meal: $e');
    }
  }

  @override
  Future<MealModel?> findStoredMealByNameAndOwner({
    required String name,
    required String? ownerUserId,
  }) async {
    try {
      final db = await databaseHelper.database;
      final ownerKey = ownerUserId ?? '';
      final maps = await db.query(
        DatabaseTables.meals,
        where:
            '${DatabaseTables.mealName} = ? '
            "AND COALESCE(${DatabaseTables.ownerUserId}, '') = ?",
        whereArgs: <Object?>[name, ownerKey],
        limit: 1,
      );
      if (maps.isEmpty) {
        return null;
      }
      return MealModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to look up meal by (name, owner): $e',
      );
    }
  }

  @override
  Future<void> upsertMeal(MealModel meal) async {
    final existing = await _getStoredMealById(meal.id);
    if (existing == null) {
      await insertMeal(meal);
      return;
    }

    if (existing.syncMetadata.isPendingDelete &&
        !meal.syncMetadata.isPendingDelete) {
      return;
    }

    await updateMeal(meal);
  }

  @override
  Future<void> prepareForInitialCloudMigration({required String userId}) async {
    await ownerId();
    try {
      final storedMeals = await _getStoredMeals();
      final preparedMeals = storedMeals
          .map((meal) => _prepareMealForInitialCloudMigration(meal, userId))
          .toList();

      await _replaceStoredMeals(preparedMeals);
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to prepare meals for initial cloud migration: $e',
      );
    }
  }

  @override
  Future<void> mergeRemoteMeals(List<MealModel> meals) async {
    try {
      final storedLocalMeals = await _getStoredMeals();
      final mergedVisibleMeals = _merge.mergeLists(
        localItems: storedLocalMeals,
        remoteItems: meals,
      );

      final Map<String, MealModel> mergedById = <String, MealModel>{
        for (final meal in mergedVisibleMeals) meal.id: meal,
      };

      for (final localMeal in storedLocalMeals) {
        if (localMeal.syncMetadata.isPendingDelete) {
          mergedById.putIfAbsent(localMeal.id, () => localMeal);
        }
      }

      await _replaceStoredMeals(mergedById.values.toList());
    } catch (e) {
      throw CacheDatabaseException('Failed to merge remote meals: $e');
    }
  }

  @override
  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  }) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.meals,
        <String, Object?>{
          DatabaseTables.mealServerId: serverId,
          DatabaseTables.mealSyncStatus: SyncStatus.synced.name,
          DatabaseTables.mealLastSyncedAt: syncedAt.toIso8601String(),
          DatabaseTables.mealLastSyncError: null,
        },
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark meal as synced: $e');
    }
  }

  @override
  Future<void> markAsPendingUpload(
    String localId, {
    String? errorMessage,
  }) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.meals,
        <String, Object?>{
          DatabaseTables.mealSyncStatus: SyncStatus.pendingUpload.name,
          DatabaseTables.mealLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark meal as pending upload: $e');
    }
  }

  @override
  Future<void> markAsPendingUpdate(
    String localId, {
    String? errorMessage,
  }) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.meals,
        <String, Object?>{
          DatabaseTables.mealSyncStatus: SyncStatus.pendingUpdate.name,
          DatabaseTables.mealLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark meal as pending update: $e');
    }
  }

  @override
  Future<void> markAsPendingDelete(
    String localId, {
    String? errorMessage,
  }) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.meals,
        <String, Object?>{
          DatabaseTables.mealSyncStatus: SyncStatus.pendingDelete.name,
          DatabaseTables.mealLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark meal as pending delete: $e');
    }
  }

  @override
  Future<void> replaceAllMeals(List<MealModel> meals) async {
    try {
      await _replaceStoredMeals(meals);
    } catch (e) {
      throw CacheDatabaseException('Failed to replace all meals: $e');
    }
  }

  @override
  Future<void> deleteMeal(String id) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.meals,
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete meal: $e');
    }
  }

  @override
  Future<void> clearAllMeals() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.meals);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear all meals: $e');
    }
  }

  @override
  Future<void> clearMealsForOwner(String ownerId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.meals,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: <Object?>[ownerId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to clear meals for owner: $e');
    }
  }

  @override
  Future<int> getMealsCount() async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final result = await db.rawQuery(
        '''
        SELECT COUNT(*)
        FROM ${DatabaseTables.meals}
        WHERE (${DatabaseTables.mealSyncStatus} IS NULL
           OR ${DatabaseTables.mealSyncStatus} != ?)
        AND ${DatabaseTables.ownerUserId} = ?
        ''',
        [SyncStatus.pendingDelete.name, ownerId],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      throw CacheDatabaseException('Failed to get meals count: $e');
    }
  }

  Future<List<MealModel>> _getVisibleMeals() async {
    final ownerId = await this.ownerId();
    final db = await databaseHelper.database;
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '(${DatabaseTables.mealSyncStatus} IS NULL OR ${DatabaseTables.mealSyncStatus} != ?)',
      extraArgs: <Object?>[SyncStatus.pendingDelete.name],
    );
    final maps = await db.query(
      DatabaseTables.meals,
      where: f.where,
      whereArgs: f.whereArgs,
      orderBy: '${DatabaseTables.mealName} ASC',
    );

    return maps.map(MealModel.fromMap).toList();
  }

  Future<MealModel?> _getVisibleMealById(String id) async {
    final ownerId = await this.ownerId();
    final db = await databaseHelper.database;
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '${DatabaseTables.mealId} = ? AND '
          '(${DatabaseTables.mealSyncStatus} IS NULL OR ${DatabaseTables.mealSyncStatus} != ?)',
      extraArgs: <Object?>[id, SyncStatus.pendingDelete.name],
    );
    final maps = await db.query(
      DatabaseTables.meals,
      where: f.where,
      whereArgs: f.whereArgs,
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return MealModel.fromMap(maps.first);
  }

  Future<List<MealModel>> _getStoredMeals() async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.meals,
      orderBy: '${DatabaseTables.mealName} ASC',
    );

    return maps.map(MealModel.fromMap).toList();
  }

  Future<MealModel?> _getStoredMealById(String id) async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.meals,
      where: '${DatabaseTables.mealId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return MealModel.fromMap(maps.first);
  }

  /// Reconciles the local `meals` table with [meals] without nuking unchanged
  /// rows.
  ///
  /// The previous implementation did `DELETE FROM meals` + batch INSERT, which
  /// cascade-deleted every `nutrition_logs` row via the `ON DELETE CASCADE` FK
  /// on `nutrition_logs.meal_id` — silently wiping the user's food diary on
  /// every remote sync.
  ///
  /// New behaviour (mirrors [ExerciseLocalDataSourceImpl._replaceStoredExercises]):
  /// 1. Dedup the incoming list by (name, owner) — keeps most-recently-updated.
  /// 2. UPDATE existing rows in place, INSERT genuinely new rows, DELETE only
  ///    rows absent from [meals].
  ///
  /// Real deletions still cascade to nutrition_logs correctly; unchanged meal
  /// rows keep their log children intact.
  Future<void> _replaceStoredMeals(List<MealModel> meals) async {
    // Defensive dedup: if the incoming list contains (name, owner) duplicates
    // keep only the most-recently-updated to avoid tripping UNIQUE(name, owner).
    final deduped = _deduplicateByNameAndOwner(meals);
    if (deduped.length < meals.length) {
      AppLogger.warning(
        '_replaceStoredMeals: dropped '
        '${meals.length - deduped.length} duplicate (name, owner) '
        'row(s) from incoming list',
        category: 'datasource',
      );
    }

    final db = await databaseHelper.database;

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        DatabaseTables.meals,
        columns: <String>[DatabaseTables.mealId],
      );
      final existingIds = existingRows
          .map((row) => row[DatabaseTables.mealId] as String)
          .toSet();

      final incomingIds = <String>{};
      final batch = txn.batch();

      for (final meal in deduped) {
        incomingIds.add(meal.id);
        if (existingIds.contains(meal.id)) {
          batch.update(
            DatabaseTables.meals,
            meal.toMap(),
            where: '${DatabaseTables.mealId} = ?',
            whereArgs: <Object?>[meal.id],
          );
        } else {
          batch.insert(
            DatabaseTables.meals,
            meal.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      for (final staleId in existingIds.difference(incomingIds)) {
        batch.delete(
          DatabaseTables.meals,
          where: '${DatabaseTables.mealId} = ?',
          whereArgs: <Object?>[staleId],
        );
      }

      await batch.commit(noResult: true);
    });
  }

  /// Removes duplicate `(name, ownerUserId)` entries from [meals], keeping
  /// the entry with the latest [MealModel.updatedAt].
  ///
  /// Belt-and-suspenders guard: the DB schema enforces
  /// `UNIQUE(name, COALESCE(owner_user_id, ''))`, so two rows with the same
  /// (name, owner) in one batch would trip the constraint. Deduping here keeps
  /// the batch clean and surfaces nothing to the user.
  List<MealModel> _deduplicateByNameAndOwner(List<MealModel> meals) {
    final seen = <String, MealModel>{};
    for (final meal in meals) {
      final key = '${meal.name.toLowerCase()}|${meal.ownerUserId ?? ''}';
      final existing = seen[key];
      if (existing == null || meal.updatedAt.isAfter(existing.updatedAt)) {
        seen[key] = meal;
      }
    }
    return seen.values.toList();
  }

  MealModel _prepareMealForInitialCloudMigration(
    MealModel meal,
    String userId,
  ) {
    final ownerUserId = meal.ownerUserId;
    if (ownerUserId != userId) {
      return meal;
    }

    final currentMetadata = meal.syncMetadata;
    final updatedMetadata = switch (currentMetadata.status) {
      SyncStatus.localOnly => currentMetadata.copyWith(
        status: SyncStatus.pendingUpload,
        clearLastSyncError: true,
      ),
      SyncStatus.syncError => currentMetadata.copyWith(
        status: SyncStatus.pendingUpload,
        clearLastSyncError: true,
      ),
      SyncStatus.pendingUpload => currentMetadata.copyWith(
        clearLastSyncError: true,
      ),
      SyncStatus.pendingUpdate ||
      SyncStatus.synced ||
      SyncStatus.pendingDelete => currentMetadata,
    };

    return MealModel.fromEntity(meal.copyWith(syncMetadata: updatedMetadata));
  }
}
