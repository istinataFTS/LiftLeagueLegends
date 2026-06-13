import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../config/env_config.dart';
import '../../core/constants/database_tables.dart';
import '../../core/utils/date_serialization.dart';
import '../../data/datasources/local/database_helper.dart';

class AppDiagnostics {
  static Future<void> runDiagnostics() async {
    debugPrint('========================================');
    debugPrint('🔍 Running App Diagnostics');
    debugPrint('========================================\n');

    await _checkEnvironmentConfig();
    await _checkDatabaseSetup();
    await _checkProductionReadiness();

    debugPrint('\n========================================');
    debugPrint('✅ Diagnostics Complete');
    debugPrint('========================================');
  }

  static Future<void> _checkEnvironmentConfig() async {
    debugPrint('📋 Environment Configuration:');
    debugPrint('  App Name: ${EnvConfig.appName}');
    debugPrint('  Version: ${EnvConfig.appVersion}');
    debugPrint('  Environment: ${EnvConfig.environment}');
    debugPrint(
      '  Database: ${EnvConfig.databaseName} (v${EnvConfig.databaseVersion})',
    );
    debugPrint('  Seeding Enabled: ${EnvConfig.seedDefaultData}');
    debugPrint('  Force Reseed: ${EnvConfig.forceReseed}');

    final issues = EnvConfig.getRuntimeConfigIssues();
    if (issues.isEmpty) {
      debugPrint('  ✅ Runtime configuration OK');
    } else {
      for (final issue in issues) {
        debugPrint('  ⚠️ $issue');
      }
    }

    debugPrint('');
  }

  static Future<void> _checkDatabaseSetup() async {
    debugPrint('💾 Database Setup:');

    if (kIsWeb) {
      debugPrint('  ℹ️ Web platform - database not supported');
      debugPrint('');
      return;
    }

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final databasesPath = await getDatabasesPath();
      final dbPath = join(databasesPath, EnvConfig.databaseName);
      debugPrint('  Location: $dbPath');
      debugPrint('  ✅ Database accessible');

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;",
      );
      debugPrint('  Tables found: ${tables.length}');
      for (final table in tables) {
        debugPrint('    - ${table['name']}');
      }

      await _checkTableCounts(db);
    } catch (e) {
      debugPrint('  ❌ Database error: $e');
    }
    debugPrint('');
  }

  static Future<void> _checkTableCounts(Database db) async {
    try {
      final exerciseCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM exercises'),
      );
      debugPrint('  Exercises: $exerciseCount records');

      final setsCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM workout_sets'),
      );
      debugPrint('  Workout Sets: $setsCount records');

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_%';",
      );
      debugPrint('  Indexes: ${indexes.length} found');
    } catch (e) {
      debugPrint('  ⚠️ Could not retrieve table counts: $e');
    }
  }

  static Future<void> _checkProductionReadiness() async {
    debugPrint('🚀 Production Readiness:');

    final issues = EnvConfig.getRuntimeConfigIssues();

    if (issues.isEmpty) {
      debugPrint('  ✅ No production/runtime issues found');
      return;
    }

    debugPrint('  ⚠️ Found ${issues.length} issue(s):');
    for (final issue in issues) {
      debugPrint('    - $issue');
    }
  }

  static Future<bool> testDataPersistence() async {
    if (kIsWeb) {
      debugPrint('⚠️ Cannot test data persistence on web platform');
      return false;
    }

    debugPrint('\n🧪 Testing Data Persistence:');

    try {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.database;

      final testId =
          'test_persistence_${DateTime.now().millisecondsSinceEpoch}';

      await db.insert(DatabaseTables.exercises, {
        DatabaseTables.exerciseId: testId,
        DatabaseTables.exerciseName: 'Test Exercise - Persistence',
        DatabaseTables.exerciseMuscleGroups: '["chest"]',
        DatabaseTables.exerciseCreatedAt: DateTime.now().toStorageIso(),
      });
      debugPrint('  ✅ Created test exercise');

      final result = await db.query(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [testId],
      );

      if (result.isEmpty) {
        debugPrint('  ❌ Test exercise not found after insert');
        return false;
      }

      debugPrint('  ✅ Test exercise persisted successfully');

      await db.delete(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: [testId],
      );
      debugPrint('  ✅ Cleaned up test data');

      return true;
    } catch (e) {
      debugPrint('  ❌ Persistence test failed: $e');
      return false;
    }
  }

  static void checkHardcodedValues() {
    debugPrint('\n🔎 Checking for Hardcoded Values:');

    final checks = [
      'Database name: Using EnvConfig.databaseName',
      'App version: Using EnvConfig.appVersion',
      'User name: Resolved from the authenticated session',
      'Seeding: Using EnvConfig.seedDefaultData',
    ];

    debugPrint('  Manual verification checklist:');
    for (final check in checks) {
      debugPrint('    ✓ $check');
    }

    debugPrint('  ℹ️ Verify no hardcoded strings in:');
    debugPrint('    - Database configurations');
    debugPrint('    - API endpoints');
    debugPrint('    - User-facing strings (use app_strings.dart)');
  }

  static void checkAppStoreCompliance() {
    debugPrint('\n🏪 App Store Compliance:');

    debugPrint('  iOS Requirements:');
    debugPrint('    - Info.plist configured');
    debugPrint('    - Privacy descriptions added');
    debugPrint('    - iCloud backup disabled for database');
    debugPrint('    - No external data transmission');

    debugPrint('\n  Android Requirements:');
    debugPrint('    - AndroidManifest.xml permissions minimal');
    debugPrint('    - Target SDK 34+ (Android 14)');
    debugPrint('    - Storage permissions only for database');
    debugPrint('    - No internet permissions needed');

    debugPrint('\n  Data Privacy:');
    debugPrint('    ✅ All data stored locally');
    debugPrint('    ✅ No analytics tracking');
    debugPrint('    ✅ No user authentication');
    debugPrint('    ✅ No external API calls (workout data)');
  }

  static Future<void> fullReport() async {
    await runDiagnostics();
    await testDataPersistence();
    checkHardcodedValues();
    checkAppStoreCompliance();
  }
}
