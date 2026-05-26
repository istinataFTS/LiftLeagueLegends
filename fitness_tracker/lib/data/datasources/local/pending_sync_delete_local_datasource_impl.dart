import 'package:sqflite/sqflite.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/enums/sync_entity_type.dart';
import '../../../domain/entities/pending_sync_delete.dart';
import '../../models/pending_sync_delete_model.dart';
import 'database_helper.dart';
import 'pending_sync_delete_local_datasource.dart';

class PendingSyncDeleteLocalDataSourceImpl
    implements PendingSyncDeleteLocalDataSource {
  final DatabaseHelper databaseHelper;

  const PendingSyncDeleteLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<void> enqueue(PendingSyncDelete operation) async {
    try {
      final db = await databaseHelper.database;
      final model = PendingSyncDeleteModel.fromEntity(operation);

      await db.insert(
        DatabaseTables.pendingSyncDeletes,
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to enqueue pending sync delete: $e');
    }
  }

  @override
  Future<List<PendingSyncDelete>> getPendingByEntityType(
    SyncEntityType entityType,
  ) async {
    try {
      final db = await databaseHelper.database;
      final maps = await db.query(
        DatabaseTables.pendingSyncDeletes,
        where: '${DatabaseTables.pendingDeleteEntityType} = ?',
        whereArgs: [entityType.name],
        orderBy:
            '${DatabaseTables.pendingDeleteCreatedAt} ASC, ${DatabaseTables.pendingDeleteId} ASC',
      );

      return maps.map(PendingSyncDeleteModel.fromMap).toList();
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to get pending sync deletes by entity type: $e',
      );
    }
  }

  @override
  Future<void> markAttempted(
    String operationId, {
    required DateTime attemptedAt,
    String? errorMessage,
  }) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.pendingSyncDeletes,
        <String, Object?>{
          DatabaseTables.pendingDeleteLastAttemptAt: attemptedAt
              .toIso8601String(),
          DatabaseTables.pendingDeleteErrorMessage: errorMessage,
        },
        where: '${DatabaseTables.pendingDeleteId} = ?',
        whereArgs: [operationId],
      );
    } catch (e) {
      throw CacheDatabaseException(
        'Failed to mark pending sync delete as attempted: $e',
      );
    }
  }

  @override
  Future<void> remove(String operationId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.pendingSyncDeletes,
        where: '${DatabaseTables.pendingDeleteId} = ?',
        whereArgs: [operationId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to remove pending sync delete: $e');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.pendingSyncDeletes);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear pending sync deletes: $e');
    }
  }
}
