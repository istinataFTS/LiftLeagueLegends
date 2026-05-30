import 'package:sqflite/sqflite.dart';
import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/muscle_stimulus_model.dart';
import 'user_scoped_local_datasource.dart';

/// Local data source interface for MuscleStimulus operations.
///
/// User scoping is resolved internally via [UserScopedLocalDatasource] —
/// callers no longer pass a [userId] parameter. The exception is
/// [clearStimulusForUser], which is invoked during sign-out with the
/// signing-out user's ID (not the current session).
abstract class MuscleStimulusLocalDataSource {
  /// Get stimulus for a specific muscle on a specific date.
  Future<MuscleStimulusModel?> getStimulusByMuscleAndDate({
    required String muscleGroup,
    required DateTime date,
  });

  /// Get all stimulus records for a muscle within a date range.
  Future<List<MuscleStimulusModel>> getStimulusByDateRange({
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Get today's stimulus for a specific muscle.
  Future<MuscleStimulusModel?> getTodayStimulus(String muscleGroup);

  /// Get all stimulus records for all muscles on a specific date.
  Future<List<MuscleStimulusModel>> getAllStimulusForDate(DateTime date);

  /// Insert or update a stimulus record.
  /// The [userId] is embedded on the model's [ownerUserId] field.
  Future<void> upsertStimulus(MuscleStimulusModel stimulus);

  /// Update daily stimulus and rolling weekly load for an existing record.
  Future<void> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  });

  /// Apply daily decay to all muscle records owned by the current user.
  Future<void> applyDailyDecayToAll();

  /// Get maximum daily stimulus ever recorded for a muscle owned by the current user.
  Future<double> getMaxStimulusForMuscle(String muscleGroup);

  /// Delete stimulus records older than [date] for the current user.
  Future<void> deleteOlderThan(DateTime date);

  /// Clear all stimulus records across every user.
  /// Use this only when performing a full per-user rebuild via
  /// [clearStimulusForUser] first, or in tests.
  Future<void> clearAllStimulus();

  /// Remove all stimulus records belonging to [userId].
  /// Called on sign-out to prevent data leaking to the next session.
  /// Accepts an explicit [userId] because this runs after the session has
  /// already been cleared — the resolver would throw without an active session.
  Future<void> clearStimulusForUser(String userId);
}

/// SQLite implementation of [MuscleStimulusLocalDataSource].
class MuscleStimulusLocalDataSourceImpl extends UserScopedLocalDatasource
    implements MuscleStimulusLocalDataSource {
  MuscleStimulusLocalDataSourceImpl({
    required super.databaseHelper,
    required super.currentUserIdResolver,
  });

  @override
  Future<MuscleStimulusModel?> getStimulusByMuscleAndDate({
    required String muscleGroup,
    required DateTime date,
  }) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final dateString = MuscleStimulusModel.formatDateForDb(date);
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '${DatabaseTables.stimulusMuscleGroup} = ? '
            'AND ${DatabaseTables.stimulusDate} = ?',
        extraArgs: [muscleGroup, dateString],
      );

      final maps = await db.query(
        DatabaseTables.muscleStimulus,
        where: f.where,
        whereArgs: f.whereArgs,
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return MuscleStimulusModel.fromMap(maps.first);
    } catch (e) {
      throw CacheDatabaseException('Failed to get stimulus: $e');
    }
  }

  @override
  Future<List<MuscleStimulusModel>> getStimulusByDateRange({
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final startDateString = MuscleStimulusModel.formatDateForDb(startDate);
      final endDateString = MuscleStimulusModel.formatDateForDb(endDate);
      final f = whereOwned(
        ownerId: ownerId,
        extra:
            '${DatabaseTables.stimulusMuscleGroup} = ? '
            'AND ${DatabaseTables.stimulusDate} >= ? '
            'AND ${DatabaseTables.stimulusDate} <= ?',
        extraArgs: [muscleGroup, startDateString, endDateString],
      );

      final maps = await db.query(
        DatabaseTables.muscleStimulus,
        where: f.where,
        whereArgs: f.whereArgs,
        orderBy: '${DatabaseTables.stimulusDate} DESC',
      );

      return maps.map((map) => MuscleStimulusModel.fromMap(map)).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get stimulus by date range: $e');
    }
  }

  @override
  Future<MuscleStimulusModel?> getTodayStimulus(String muscleGroup) {
    return getStimulusByMuscleAndDate(
      muscleGroup: muscleGroup,
      date: DateTime.now(),
    );
  }

  @override
  Future<List<MuscleStimulusModel>> getAllStimulusForDate(DateTime date) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final dateString = MuscleStimulusModel.formatDateForDb(date);
      final f = whereOwned(
        ownerId: ownerId,
        extra: '${DatabaseTables.stimulusDate} = ?',
        extraArgs: [dateString],
      );

      final maps = await db.query(
        DatabaseTables.muscleStimulus,
        where: f.where,
        whereArgs: f.whereArgs,
      );

      return maps.map((map) => MuscleStimulusModel.fromMap(map)).toList();
    } catch (e) {
      throw CacheDatabaseException('Failed to get all stimulus for date: $e');
    }
  }

  @override
  Future<void> upsertStimulus(MuscleStimulusModel stimulus) async {
    try {
      final db = await databaseHelper.database;
      await db.insert(
        DatabaseTables.muscleStimulus,
        stimulus.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to upsert stimulus: $e');
    }
  }

  @override
  Future<void> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  }) async {
    try {
      final db = await databaseHelper.database;

      final updateMap = <String, Object?>{
        DatabaseTables.stimulusDailyStimulus: dailyStimulus,
        DatabaseTables.stimulusRollingWeeklyLoad: rollingWeeklyLoad,
        DatabaseTables.stimulusUpdatedAt: DateTime.now().toIso8601String(),
      };

      if (lastSetTimestamp != null) {
        updateMap[DatabaseTables.stimulusLastSetTimestamp] = lastSetTimestamp;
      }
      if (lastSetStimulus != null) {
        updateMap[DatabaseTables.stimulusLastSetStimulus] = lastSetStimulus;
      }

      await db.update(
        DatabaseTables.muscleStimulus,
        updateMap,
        where: '${DatabaseTables.stimulusId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to update stimulus values: $e');
    }
  }

  @override
  Future<void> applyDailyDecayToAll() async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final f = whereOwned(ownerId: ownerId);

      final maps = await db.query(
        DatabaseTables.muscleStimulus,
        where: f.where,
        whereArgs: f.whereArgs,
      );
      final stimulusRecords = maps
          .map((map) => MuscleStimulusModel.fromMap(map))
          .toList();

      final batch = db.batch();
      for (final stimulus in stimulusRecords) {
        final decayedLoad = stimulus.rollingWeeklyLoad * 0.6;
        batch.update(
          DatabaseTables.muscleStimulus,
          {
            DatabaseTables.stimulusRollingWeeklyLoad: decayedLoad,
            DatabaseTables.stimulusUpdatedAt: DateTime.now().toIso8601String(),
          },
          where: '${DatabaseTables.stimulusId} = ?',
          whereArgs: [stimulus.id],
        );
      }

      await batch.commit(noResult: true);
    } catch (e) {
      throw CacheDatabaseException('Failed to apply daily decay: $e');
    }
  }

  @override
  Future<double> getMaxStimulusForMuscle(String muscleGroup) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;

      final result = await db.rawQuery(
        'SELECT MAX(${DatabaseTables.stimulusDailyStimulus}) as max_stimulus '
        'FROM ${DatabaseTables.muscleStimulus} '
        'WHERE ${DatabaseTables.ownerUserId} = ? '
        'AND ${DatabaseTables.stimulusMuscleGroup} = ?',
        [ownerId, muscleGroup],
      );

      if (result.isEmpty || result.first['max_stimulus'] == null) {
        return 0.0;
      }

      return (result.first['max_stimulus'] as num).toDouble();
    } catch (e) {
      throw CacheDatabaseException('Failed to get max stimulus: $e');
    }
  }

  @override
  Future<void> deleteOlderThan(DateTime date) async {
    try {
      final ownerId = await this.ownerId();
      final db = await databaseHelper.database;
      final dateString = MuscleStimulusModel.formatDateForDb(date);
      final f = whereOwned(
        ownerId: ownerId,
        extra: '${DatabaseTables.stimulusDate} < ?',
        extraArgs: [dateString],
      );

      await db.delete(
        DatabaseTables.muscleStimulus,
        where: f.where,
        whereArgs: f.whereArgs,
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete old stimulus records: $e');
    }
  }

  @override
  Future<void> clearAllStimulus() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.muscleStimulus);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear stimulus records: $e');
    }
  }

  @override
  Future<void> clearStimulusForUser(String userId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.muscleStimulus,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: [userId],
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to clear stimulus records for user: $e',
      );
    }
  }
}
