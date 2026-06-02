import 'package:sqflite/sqflite.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/enums/sync_status.dart';
import '../../../core/utils/date_serialization.dart';
import '../../../core/sync/local_remote_merge.dart';
import '../../../domain/entities/workout_set.dart';
import '../../models/workout_set_model.dart';
import 'user_scoped_local_datasource.dart';
import 'workout_set_local_datasource.dart';

class WorkoutSetLocalDataSourceImpl extends UserScopedLocalDatasource
    implements WorkoutSetLocalDataSource {
  static final LocalRemoteMerge<WorkoutSet> _merge =
      LocalRemoteMerge<WorkoutSet>(
        getId: (set) => set.id,
        getUpdatedAt: (set) => set.updatedAt,
        getSyncMetadata: (set) => set.syncMetadata,
      );

  WorkoutSetLocalDataSourceImpl({
    required super.databaseHelper,
    required super.currentUserIdResolver,
  });

  @override
  Future<List<WorkoutSet>> getAllSets() async {
    try {
      return await _getVisibleSets();
    } catch (e) {
      throw CacheDatabaseException('Failed to get all sets: $e');
    }
  }

  @override
  Future<WorkoutSet?> getSetById(String id) async {
    try {
      return await _getVisibleSetById(id);
    } catch (e) {
      throw CacheDatabaseException('Failed to get set by ID: $e');
    }
  }

  @override
  Future<List<WorkoutSet>> getSetsByExerciseId(String exerciseId) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '${DatabaseTables.setExerciseId} = ? AND '
            '(${DatabaseTables.setSyncStatus} IS NULL OR ${DatabaseTables.setSyncStatus} != ?)',
        extraArgs: [exerciseId, SyncStatus.pendingDelete.name],
      );
      final maps = await db.query(
        DatabaseTables.workoutSets,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy:
            '${DatabaseTables.setDate} DESC, ${DatabaseTables.setCreatedAt} DESC',
      );

      return maps.map(WorkoutSetModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get sets by exercise ID: $e');
    }
  }

  @override
  Future<List<WorkoutSet>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '${DatabaseTables.setDate} >= ? AND '
            '${DatabaseTables.setDate} <= ? AND '
            '(${DatabaseTables.setSyncStatus} IS NULL OR ${DatabaseTables.setSyncStatus} != ?)',
        extraArgs: [
          startDate.toStorageIso(),
          endDate.toStorageIso(),
          SyncStatus.pendingDelete.name,
        ],
      );
      final maps = await db.query(
        DatabaseTables.workoutSets,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy:
            '${DatabaseTables.setDate} DESC, ${DatabaseTables.setCreatedAt} DESC',
      );

      return maps.map(WorkoutSetModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get sets by date range: $e');
    }
  }

  @override
  Future<List<WorkoutSet>> getPendingSyncSets() async {
    try {
      final ownerId = await this.ownerId();
      if (ownerId.isEmpty) return <WorkoutSet>[];
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '(${DatabaseTables.setSyncStatus} = ? OR ${DatabaseTables.setSyncStatus} = ?)',
        extraArgs: [
          SyncStatus.pendingUpload.name,
          SyncStatus.pendingUpdate.name,
        ],
      );
      final maps = await db.query(
        DatabaseTables.workoutSets,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.setUpdatedAt} ASC',
      );

      return maps.map(WorkoutSetModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get pending sync sets: $e');
    }
  }

  @override
  Future<void> addSet(WorkoutSet set) async {
    try {
      final db = await databaseHelper.database;
      final model = WorkoutSetModel.fromEntity(set);

      await db.insert(
        DatabaseTables.workoutSets,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to add set: $e');
    }
  }

  @override
  Future<void> updateSet(WorkoutSet set) async {
    try {
      final db = await databaseHelper.database;
      final model = WorkoutSetModel.fromEntity(set);

      await db.update(
        DatabaseTables.workoutSets,
        model.toMap(),
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [model.id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to update set: $e');
    }
  }

  @override
  Future<void> upsertSet(WorkoutSet set) async {
    final existing = await _getStoredSetById(set.id);
    if (existing == null) {
      await addSet(set);
      return;
    }

    if (existing.syncMetadata.isPendingDelete &&
        !set.syncMetadata.isPendingDelete) {
      return;
    }

    await updateSet(set);
  }

  @override
  Future<void> prepareForInitialCloudMigration({required String userId}) async {
    await ownerId();
    try {
      final storedSets = await _getStoredSets();
      final preparedSets = storedSets
          .map((set) => _prepareSetForInitialCloudMigration(set, userId))
          .toList();

      await _replaceStoredSets(preparedSets);
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to prepare workout sets for initial cloud migration: $e',
      );
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
        DatabaseTables.workoutSets,
        <String, Object?>{
          DatabaseTables.setServerId: serverId,
          DatabaseTables.setSyncStatus: SyncStatus.synced.name,
          DatabaseTables.setLastSyncedAt: syncedAt.toStorageIso(),
          DatabaseTables.setLastSyncError: null,
        },
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark set as synced: $e');
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
        DatabaseTables.workoutSets,
        <String, Object?>{
          DatabaseTables.setSyncStatus: SyncStatus.pendingUpload.name,
          DatabaseTables.setLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark set as pending upload: $e');
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
        DatabaseTables.workoutSets,
        <String, Object?>{
          DatabaseTables.setSyncStatus: SyncStatus.pendingUpdate.name,
          DatabaseTables.setLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark set as pending update: $e');
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
        DatabaseTables.workoutSets,
        <String, Object?>{
          DatabaseTables.setSyncStatus: SyncStatus.pendingDelete.name,
          DatabaseTables.setLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark set as pending delete: $e');
    }
  }

  @override
  Future<void> mergeRemoteSets(List<WorkoutSet> remoteSets) async {
    try {
      final storedLocalSets = await _getStoredSets();
      final mergedVisibleSets = _merge.mergeLists(
        localItems: storedLocalSets,
        remoteItems: remoteSets,
      );

      final Map<String, WorkoutSet> mergedById = <String, WorkoutSet>{
        for (final set in mergedVisibleSets) set.id: set,
      };

      for (final localSet in storedLocalSets) {
        if (localSet.syncMetadata.isPendingDelete) {
          mergedById.putIfAbsent(localSet.id, () => localSet);
        }
      }

      await _replaceStoredSets(mergedById.values.toList());
    } catch (e) {
      throw CacheDatabaseException('Failed to merge workout sets: $e');
    }
  }

  @override
  Future<void> replaceAll(List<WorkoutSet> sets) async {
    try {
      await _replaceStoredSets(sets);
    } catch (e) {
      throw CacheDatabaseException('Failed to replace workout sets: $e');
    }
  }

  @override
  Future<void> deleteSet(String id) async {
    try {
      final db = await databaseHelper.database;

      await db.delete(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.setId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete set: $e');
    }
  }

  @override
  Future<void> clearAllSets() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.workoutSets);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear all sets: $e');
    }
  }

  @override
  Future<void> clearSetsForOwner(String ownerId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: <Object?>[ownerId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to clear sets for owner: $e');
    }
  }

  Future<List<WorkoutSet>> _getVisibleSets() async {
    final ownerId = await this.ownerId();
    final db = await databaseHelper.database;
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '(${DatabaseTables.setSyncStatus} IS NULL OR ${DatabaseTables.setSyncStatus} != ?)',
      extraArgs: <Object?>[SyncStatus.pendingDelete.name],
    );
    final maps = await db.query(
      DatabaseTables.workoutSets,
      where: f.where,
      whereArgs: f.whereArgs,
      orderBy:
          '${DatabaseTables.setDate} DESC, ${DatabaseTables.setCreatedAt} DESC',
    );

    return maps.map(WorkoutSetModel.fromMap).toList();
  }

  Future<WorkoutSet?> _getVisibleSetById(String id) async {
    final ownerId = await this.ownerId();
    final db = await databaseHelper.database;
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '${DatabaseTables.setId} = ? AND '
          '(${DatabaseTables.setSyncStatus} IS NULL OR ${DatabaseTables.setSyncStatus} != ?)',
      extraArgs: <Object?>[id, SyncStatus.pendingDelete.name],
    );
    final maps = await db.query(
      DatabaseTables.workoutSets,
      where: f.where,
      whereArgs: f.whereArgs,
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkoutSetModel.fromMap(maps.first);
  }

  Future<List<WorkoutSet>> _getStoredSets() async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.workoutSets,
      orderBy:
          '${DatabaseTables.setDate} DESC, ${DatabaseTables.setCreatedAt} DESC',
    );

    return maps.map(WorkoutSetModel.fromMap).toList();
  }

  Future<WorkoutSet?> _getStoredSetById(String id) async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.workoutSets,
      where: '${DatabaseTables.setId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return WorkoutSetModel.fromMap(maps.first);
  }

  Future<void> _replaceStoredSets(List<WorkoutSet> sets) async {
    final db = await databaseHelper.database;

    await db.transaction((txn) async {
      await txn.delete(DatabaseTables.workoutSets);

      final batch = txn.batch();
      for (final set in sets) {
        final model = WorkoutSetModel.fromEntity(set);
        batch.insert(
          DatabaseTables.workoutSets,
          model.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  WorkoutSet _prepareSetForInitialCloudMigration(
    WorkoutSet set,
    String userId,
  ) {
    final ownerUserId = set.ownerUserId;
    if (ownerUserId != userId) {
      return set;
    }

    final currentMetadata = set.syncMetadata;
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

    return set.copyWith(syncMetadata: updatedMetadata);
  }
}
