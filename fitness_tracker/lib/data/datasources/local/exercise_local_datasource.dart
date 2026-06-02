import 'package:sqflite/sqflite.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/enums/sync_status.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/sync/local_remote_merge.dart';
import '../../../core/utils/date_serialization.dart';
import '../../models/exercise_model.dart';
import 'user_scoped_local_datasource.dart';

abstract class ExerciseLocalDataSource {
  Future<List<ExerciseModel>> getAllExercises();
  Future<ExerciseModel?> getExerciseById(String id);
  Future<ExerciseModel?> getExerciseByName(String name);

  /// Looks up the unique row that owns the `(name, ownerUserId)` slot
  /// enforced by the schema's `UNIQUE(name, COALESCE(owner_user_id, ''))`
  /// constraint.
  ///
  /// Use this from sync code paths that need to reconcile a remote payload
  /// against an existing local row carrying the same name + owner under a
  /// different `id` (e.g. a row created offline with a locally-generated
  /// UUID before the device first synced). Without the lookup the pull
  /// would trip the UNIQUE constraint and abort the whole feature sync.
  ///
  /// Pass `ownerUserId == null` to find seeded/system rows.
  Future<ExerciseModel?> getByNameAndOwner({
    required String name,
    required String? ownerUserId,
  });

  Future<List<ExerciseModel>> getExercisesForMuscle(String muscleGroup);
  Future<List<ExerciseModel>> getPendingSyncExercises();
  Future<void> insertExercise(ExerciseModel exercise);
  Future<void> updateExercise(ExerciseModel exercise);
  Future<void> upsertExercise(ExerciseModel exercise);

  /// Returns the raw stored exercise row matching [name] + owner key
  /// `COALESCE(owner_user_id, '')`, bypassing the visibility filter.
  /// Used by sync to detect (name, owner) collisions before insert/update.
  Future<ExerciseModel?> findStoredExerciseByNameAndOwner({
    required String name,
    required String? ownerUserId,
  });
  Future<void> prepareForInitialCloudMigration({required String userId});
  Future<void> mergeRemoteExercises(List<ExerciseModel> exercises);
  Future<void> markAsSynced({
    required String localId,
    required String serverId,
    required DateTime syncedAt,
  });
  Future<void> markAsPendingUpload(String localId, {String? errorMessage});
  Future<void> markAsPendingUpdate(String localId, {String? errorMessage});
  Future<void> markAsPendingDelete(String localId, {String? errorMessage});
  Future<void> replaceAllExercises(List<ExerciseModel> exercises);
  Future<void> deleteExercise(String id);
  Future<void> clearAllExercises();

  /// Deletes only exercises owned by [userId] — invoked on sign-out so the
  /// next account can never see the signed-out user's catalog.
  ///
  /// Per-user catalog model (db v20+): every row is owned, so this only
  /// removes `owner_user_id = userId` rows. Other accounts' rows are
  /// untouched. There is no guest catalog (removed in the v22 migration).
  Future<void> clearUserOwnedExercises(String userId);
}

class ExerciseLocalDataSourceImpl extends UserScopedLocalDatasource
    implements ExerciseLocalDataSource {
  static final LocalRemoteMerge<ExerciseModel> _merge =
      LocalRemoteMerge<ExerciseModel>(
        getId: (exercise) => exercise.id,
        getUpdatedAt: (exercise) => exercise.updatedAt,
        getSyncMetadata: (exercise) => exercise.syncMetadata,
      );

  ExerciseLocalDataSourceImpl({
    required super.databaseHelper,
    required super.currentUserIdResolver,
  });

  // ---------------------------------------------------------------------------
  // Public reads
  // ---------------------------------------------------------------------------

  @override
  Future<List<ExerciseModel>> getAllExercises() async {
    try {
      return await _getVisibleExercises();
    } catch (e) {
      throw CacheDatabaseException('Failed to get exercises: $e');
    }
  }

  @override
  Future<ExerciseModel?> getExerciseById(String id) async {
    try {
      return await _getVisibleExerciseById(id);
    } catch (e) {
      throw CacheDatabaseException('Failed to get exercise: $e');
    }
  }

  @override
  Future<ExerciseModel?> getExerciseByName(String name) async {
    try {
      final ownerId = await this.ownerId();
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            'LOWER(${DatabaseTables.exerciseName}) = LOWER(?) AND '
            '(${DatabaseTables.exerciseSyncStatus} IS NULL OR ${DatabaseTables.exerciseSyncStatus} != ?)',
        extraArgs: [name, SyncStatus.pendingDelete.name],
      );
      final db = await databaseHelper.database;
      final maps = await db.query(
        DatabaseTables.exercises,
        where: f.where,
        whereArgs: f.whereArgs,
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }

      return ExerciseModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException('Failed to get exercise by name: $e');
    }
  }

  @override
  Future<ExerciseModel?> getByNameAndOwner({
    required String name,
    required String? ownerUserId,
  }) async {
    try {
      final db = await databaseHelper.database;
      // Mirror the UNIQUE constraint: COALESCE the owner so a NULL system
      // owner matches the empty-string sentinel used in the index.
      final maps = await db.query(
        DatabaseTables.exercises,
        where:
            'LOWER(${DatabaseTables.exerciseName}) = LOWER(?) '
            "AND COALESCE(${DatabaseTables.ownerUserId}, '') = ?",
        whereArgs: <Object?>[name, ownerUserId ?? ''],
        limit: 1,
      );

      if (maps.isEmpty) {
        return null;
      }
      return ExerciseModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException('Failed to get exercise by name+owner: $e');
    }
  }

  @override
  Future<List<ExerciseModel>> getExercisesForMuscle(String muscleGroup) async {
    try {
      final ownerId = await this.ownerId();
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '${DatabaseTables.exerciseMuscleGroups} LIKE ? AND '
            '(${DatabaseTables.exerciseSyncStatus} IS NULL OR ${DatabaseTables.exerciseSyncStatus} != ?)',
        extraArgs: ['%"$muscleGroup"%', SyncStatus.pendingDelete.name],
      );
      final db = await databaseHelper.database;
      final maps = await db.query(
        DatabaseTables.exercises,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.exerciseName} ASC',
      );
      return maps.map(ExerciseModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get exercises for muscle: $e');
    }
  }

  @override
  Future<List<ExerciseModel>> getPendingSyncExercises() async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '(${DatabaseTables.exerciseSyncStatus} = ? OR '
            '${DatabaseTables.exerciseSyncStatus} = ?)',
        extraArgs: [
          SyncStatus.pendingUpload.name,
          SyncStatus.pendingUpdate.name,
        ],
      );
      final maps = await db.query(
        DatabaseTables.exercises,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.exerciseUpdatedAt} ASC',
      );

      return maps.map(ExerciseModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get pending sync exercises: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Writes
  // ---------------------------------------------------------------------------

  @override
  Future<void> insertExercise(ExerciseModel exercise) async {
    try {
      final db = await databaseHelper.database;
      await db.insert(
        DatabaseTables.exercises,
        exercise.toMap(),
        // abort — never silently replace an existing row. The schema enforces
        // UNIQUE(name, COALESCE(owner_user_id, '')) so legitimate same-name
        // pairs from different owners are fine; same-owner duplicates are a
        // caller bug and must surface as an exception.
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to insert exercise "${exercise.name}" '
        '(owner: ${exercise.ownerUserId ?? 'system'}): $e',
      );
    }
  }

  @override
  Future<void> updateExercise(ExerciseModel exercise) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.exercises,
        exercise.toMap(),
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [exercise.id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to update exercise: $e');
    }
  }

  @override
  Future<ExerciseModel?> findStoredExerciseByNameAndOwner({
    required String name,
    required String? ownerUserId,
  }) async {
    try {
      final db = await databaseHelper.database;
      final ownerKey = ownerUserId ?? '';
      final maps = await db.query(
        DatabaseTables.exercises,
        where:
            '${DatabaseTables.exerciseName} = ? '
            "AND COALESCE(${DatabaseTables.ownerUserId}, '') = ?",
        whereArgs: <Object?>[name, ownerKey],
        limit: 1,
      );
      if (maps.isEmpty) {
        return null;
      }
      return ExerciseModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to look up exercise by (name, owner): $e',
      );
    }
  }

  @override
  Future<void> upsertExercise(ExerciseModel exercise) async {
    final existing = await _getStoredExerciseById(exercise.id);
    if (existing == null) {
      await insertExercise(exercise);
      return;
    }

    if (existing.syncMetadata.isPendingDelete &&
        !exercise.syncMetadata.isPendingDelete) {
      return;
    }

    await updateExercise(exercise);
  }

  @override
  Future<void> prepareForInitialCloudMigration({required String userId}) async {
    await ownerId();
    try {
      final storedExercises = await _getStoredExercises();
      final preparedExercises = storedExercises
          .map(
            (exercise) =>
                _prepareExerciseForInitialCloudMigration(exercise, userId),
          )
          .toList();

      await _replaceStoredExercises(preparedExercises);
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to prepare exercises for initial cloud migration: $e',
      );
    }
  }

  @override
  Future<void> mergeRemoteExercises(List<ExerciseModel> exercises) async {
    try {
      final storedLocalExercises = await _getStoredExercises();
      final mergedVisibleExercises = _merge.mergeLists(
        localItems: storedLocalExercises,
        remoteItems: exercises,
      );

      final Map<String, ExerciseModel> mergedById = <String, ExerciseModel>{
        for (final exercise in mergedVisibleExercises) exercise.id: exercise,
      };

      for (final localExercise in storedLocalExercises) {
        if (localExercise.syncMetadata.isPendingDelete) {
          mergedById.putIfAbsent(localExercise.id, () => localExercise);
        }
      }

      await _replaceStoredExercises(mergedById.values.toList());
    } catch (e) {
      throw CacheDatabaseException('Failed to merge remote exercises: $e');
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
        DatabaseTables.exercises,
        <String, Object?>{
          DatabaseTables.exerciseServerId: serverId,
          DatabaseTables.exerciseSyncStatus: SyncStatus.synced.name,
          DatabaseTables.exerciseLastSyncedAt: syncedAt.toStorageIso(),
          DatabaseTables.exerciseLastSyncError: null,
        },
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to mark exercise as synced: $e');
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
        DatabaseTables.exercises,
        <String, Object?>{
          DatabaseTables.exerciseSyncStatus: SyncStatus.pendingUpload.name,
          DatabaseTables.exerciseLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to mark exercise as pending upload: $e',
      );
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
        DatabaseTables.exercises,
        <String, Object?>{
          DatabaseTables.exerciseSyncStatus: SyncStatus.pendingUpdate.name,
          DatabaseTables.exerciseLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to mark exercise as pending update: $e',
      );
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
        DatabaseTables.exercises,
        <String, Object?>{
          DatabaseTables.exerciseSyncStatus: SyncStatus.pendingDelete.name,
          DatabaseTables.exerciseLastSyncError: errorMessage,
        },
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [localId],
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to mark exercise as pending delete: $e',
      );
    }
  }

  @override
  Future<void> replaceAllExercises(List<ExerciseModel> exercises) async {
    try {
      await _replaceStoredExercises(exercises);
    } catch (e) {
      throw CacheDatabaseException('Failed to replace all exercises: $e');
    }
  }

  @override
  Future<void> deleteExercise(String id) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete exercise: $e');
    }
  }

  @override
  Future<void> clearAllExercises() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.exercises);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear exercises: $e');
    }
  }

  @override
  Future<void> clearUserOwnedExercises(String userId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.exercises,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to clear user-owned exercises: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Exercises visible to the active authenticated account:
  /// - Only rows owned by the current user (scoped by `owner_user_id`).
  /// - Soft-deleted exercises (sync_status = pendingDelete) are excluded.
  Future<List<ExerciseModel>> _getVisibleExercises() async {
    final ownerId = await this.ownerId();
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '(${DatabaseTables.exerciseSyncStatus} IS NULL OR '
          '${DatabaseTables.exerciseSyncStatus} != ?)',
      extraArgs: <Object?>[SyncStatus.pendingDelete.name],
    );
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.exercises,
      where: f.where,
      whereArgs: f.whereArgs,
      orderBy: '${DatabaseTables.exerciseName} ASC',
    );
    return maps.map(ExerciseModel.fromMap).toList();
  }

  Future<ExerciseModel?> _getVisibleExerciseById(String id) async {
    final ownerId = await this.ownerId();
    final f = whereOwned(
      ownerId: ownerId,
      extra:
          '${DatabaseTables.exerciseId} = ? AND '
          '(${DatabaseTables.exerciseSyncStatus} IS NULL OR '
          '${DatabaseTables.exerciseSyncStatus} != ?)',
      extraArgs: <Object?>[id, SyncStatus.pendingDelete.name],
    );
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.exercises,
      where: f.where,
      whereArgs: f.whereArgs,
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return ExerciseModel.fromMap(maps.first);
  }

  Future<List<ExerciseModel>> _getStoredExercises() async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.exercises,
      orderBy: '${DatabaseTables.exerciseName} ASC',
    );
    return maps.map(ExerciseModel.fromMap).toList();
  }

  Future<ExerciseModel?> _getStoredExerciseById(String id) async {
    final db = await databaseHelper.database;
    final maps = await db.query(
      DatabaseTables.exercises,
      where: '${DatabaseTables.exerciseId} = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return ExerciseModel.fromMap(maps.first);
  }

  /// Reconciles the local `exercises` table with [exercises] without
  /// nuking unchanged rows.
  ///
  /// Why this matters: `exercise_muscle_factors` has `ON DELETE CASCADE` on
  /// `exerciseId`. The previous implementation did `DELETE FROM exercises`
  /// followed by `INSERT OR REPLACE` for every row, which cascaded — wiping
  /// every muscle factor on every sync. The heal hook would reinsert them
  /// afterwards, but any stimulus calculation that ran in the gap silently
  /// produced no muscle mapping (see "couldn't map it to any muscle group"
  /// banner).
  ///
  /// New behaviour:
  /// 1. Dedup the incoming list by (name, owner) — keeps most-recently-updated.
  /// 2. UPDATE existing rows in place, INSERT genuinely new rows, DELETE only
  ///    rows absent from [exercises].
  ///
  /// Real deletions still cascade correctly; unchanged rows keep their factor
  /// children intact.
  Future<void> _replaceStoredExercises(List<ExerciseModel> exercises) async {
    // Defensive dedup: if the incoming list contains (name, owner) duplicates
    // — possible if the remote returns the same exercise twice — keep only the
    // most-recently-updated to avoid tripping UNIQUE(name, owner).
    final deduped = _deduplicateByNameAndOwner(exercises);
    if (deduped.length < exercises.length) {
      AppLogger.warning(
        '_replaceStoredExercises: dropped '
        '${exercises.length - deduped.length} duplicate (name, owner) '
        'row(s) from incoming list',
        category: 'datasource',
      );
    }

    final db = await databaseHelper.database;

    await db.transaction((txn) async {
      final existingRows = await txn.query(
        DatabaseTables.exercises,
        columns: <String>[DatabaseTables.exerciseId],
      );
      final existingIds = existingRows
          .map((row) => row[DatabaseTables.exerciseId] as String)
          .toSet();

      final incomingIds = <String>{};
      final batch = txn.batch();

      for (final exercise in deduped) {
        incomingIds.add(exercise.id);
        if (existingIds.contains(exercise.id)) {
          batch.update(
            DatabaseTables.exercises,
            exercise.toMap(),
            where: '${DatabaseTables.exerciseId} = ?',
            whereArgs: <Object?>[exercise.id],
          );
        } else {
          batch.insert(
            DatabaseTables.exercises,
            exercise.toMap(),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      }

      for (final staleId in existingIds.difference(incomingIds)) {
        batch.delete(
          DatabaseTables.exercises,
          where: '${DatabaseTables.exerciseId} = ?',
          whereArgs: <Object?>[staleId],
        );
      }

      await batch.commit(noResult: true);
    });
  }

  /// Removes duplicate `(name, ownerUserId)` entries from [exercises],
  /// keeping the entry with the latest [ExerciseModel.updatedAt].
  ///
  /// This is a belt-and-suspenders guard for `_replaceStoredExercises`:
  /// the DB schema enforces `UNIQUE(name, COALESCE(owner_user_id, ''))`, so
  /// passing two rows with the same (name, owner) in one batch would trip the
  /// constraint. Deduping here means the batch always succeeds and the only
  /// data lost is a genuinely redundant row.
  List<ExerciseModel> _deduplicateByNameAndOwner(
    List<ExerciseModel> exercises,
  ) {
    final seen = <String, ExerciseModel>{};
    for (final exercise in exercises) {
      final key =
          '${exercise.name.toLowerCase()}|${exercise.ownerUserId ?? ''}';
      final existing = seen[key];
      if (existing == null || exercise.updatedAt.isAfter(existing.updatedAt)) {
        seen[key] = exercise;
      }
    }
    return seen.values.toList();
  }

  ExerciseModel _prepareExerciseForInitialCloudMigration(
    ExerciseModel exercise,
    String userId,
  ) {
    final ownerUserId = exercise.ownerUserId;
    if (ownerUserId != userId) {
      return exercise;
    }

    final currentMetadata = exercise.syncMetadata;
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

    return ExerciseModel.fromEntity(
      exercise.copyWith(syncMetadata: updatedMetadata),
    );
  }
}
