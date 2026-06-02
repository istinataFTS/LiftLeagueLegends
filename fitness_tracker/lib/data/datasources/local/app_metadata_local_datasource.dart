import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../../core/utils/date_serialization.dart';
import 'database_helper.dart';

abstract class AppMetadataLocalDataSource {
  Future<String?> readString(String key);

  Future<bool?> readBool(String key);

  Future<DateTime?> readDateTime(String key);

  Future<Map<String, dynamic>?> readJsonObject(String key);

  Future<void> writeString(String key, String value);

  Future<void> writeBool(String key, bool value);

  Future<void> writeDateTime(String key, DateTime value);

  Future<void> writeJsonObject(String key, Map<String, dynamic> value);

  Future<void> delete(String key);
}

class AppMetadataLocalDataSourceImpl implements AppMetadataLocalDataSource {
  final DatabaseHelper databaseHelper;

  const AppMetadataLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<String?> readString(String key) async {
    try {
      final db = await databaseHelper.database;
      final rows = await db.query(
        DatabaseTables.appMetadata,
        where: '${DatabaseTables.metadataKey} = ?',
        whereArgs: [key],
        limit: 1,
      );

      if (rows.isEmpty) {
        return null;
      }

      return rows.first[DatabaseTables.metadataValue] as String?;
    } catch (e) {
      throw CacheDatabaseException('Failed to read metadata string: $e');
    }
  }

  @override
  Future<bool?> readBool(String key) async {
    final value = await readString(key);
    if (value == null) {
      return null;
    }

    return value.toLowerCase() == 'true';
  }

  @override
  Future<DateTime?> readDateTime(String key) async {
    final value = await readString(key);
    if (value == null || value.isEmpty) {
      return null;
    }

    return parseStorageDate(value);
  }

  @override
  Future<Map<String, dynamic>?> readJsonObject(String key) async {
    final value = await readString(key);
    if (value == null || value.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    return decoded;
  }

  @override
  Future<void> writeString(String key, String value) async {
    try {
      final db = await databaseHelper.database;
      await db.insert(DatabaseTables.appMetadata, <String, Object?>{
        DatabaseTables.metadataKey: key,
        DatabaseTables.metadataValue: value,
        DatabaseTables.metadataUpdatedAt: DateTime.now().toStorageIso(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      throw CacheDatabaseException('Failed to write metadata string: $e');
    }
  }

  @override
  Future<void> writeBool(String key, bool value) {
    return writeString(key, value.toString());
  }

  @override
  Future<void> writeDateTime(String key, DateTime value) {
    return writeString(key, value.toStorageIso());
  }

  @override
  Future<void> writeJsonObject(String key, Map<String, dynamic> value) {
    return writeString(key, jsonEncode(value));
  }

  @override
  Future<void> delete(String key) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.appMetadata,
        where: '${DatabaseTables.metadataKey} = ?',
        whereArgs: [key],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete metadata key: $e');
    }
  }
}
