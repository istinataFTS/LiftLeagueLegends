import '../../../core/constants/database_tables.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/muscle_factor_model.dart';
import 'database_helper.dart';

/// Local data source for muscle factor operations.
///
/// Owns database row parsing and returns storage models instead of raw maps.
class MuscleFactorLocalDataSource {
  final DatabaseHelper databaseHelper;

  const MuscleFactorLocalDataSource({required this.databaseHelper});

  /// Get a muscle factor by ID.
  Future<MuscleFactorModel?> getFactorById(String id) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.exerciseMuscleFactors,
        where: '${DatabaseTables.factorId} = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      return MuscleFactorModel.fromMap(results.first);
    } catch (e) {
      throw CacheDatabaseException('Failed to get factor by ID: $e');
    }
  }

  /// Get all muscle factors.
  Future<List<MuscleFactorModel>> getAllFactors() async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.exerciseMuscleFactors,
      );

      return results.map(MuscleFactorModel.fromMap).toList(growable: false);
    } catch (e) {
      throw CacheDatabaseException('Failed to get all factors: $e');
    }
  }

  /// Get all muscle factors for a specific exercise.
  Future<List<MuscleFactorModel>> getFactorsForExercise(
    String exerciseId,
  ) async {
    try {
      final db = await databaseHelper.database;
      final List<Map<String, dynamic>> results = await db.query(
        DatabaseTables.exerciseMuscleFactors,
        where: '${DatabaseTables.factorExerciseId} = ?',
        whereArgs: [exerciseId],
      );

      return results.map(MuscleFactorModel.fromMap).toList(growable: false);
    } catch (e) {
      throw CacheDatabaseException('Failed to get factors for exercise: $e');
    }
  }

  /// Add a single muscle factor.
  Future<void> addFactor(MuscleFactorModel factor) async {
    try {
      final db = await databaseHelper.database;
      await db.insert(DatabaseTables.exerciseMuscleFactors, factor.toMap());
    } catch (e) {
      throw CacheDatabaseException('Failed to add factor: $e');
    }
  }

  /// Add multiple muscle factors in a batch.
  Future<void> addFactorsBatch(List<MuscleFactorModel> factors) async {
    try {
      final db = await databaseHelper.database;
      final batch = db.batch();

      for (final MuscleFactorModel factor in factors) {
        batch.insert(DatabaseTables.exerciseMuscleFactors, factor.toMap());
      }

      await batch.commit(noResult: true);
    } catch (e) {
      throw CacheDatabaseException('Failed to add factors batch: $e');
    }
  }

  /// Update an existing muscle factor.
  Future<void> updateFactor(MuscleFactorModel factor) async {
    try {
      final db = await databaseHelper.database;
      await db.update(
        DatabaseTables.exerciseMuscleFactors,
        factor.toMap(),
        where: '${DatabaseTables.factorId} = ?',
        whereArgs: [factor.id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to update factor: $e');
    }
  }

  /// Delete a muscle factor by ID.
  Future<void> deleteFactor(String id) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.exerciseMuscleFactors,
        where: '${DatabaseTables.factorId} = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete factor: $e');
    }
  }

  /// Delete all muscle factors for a specific exercise.
  Future<void> deleteFactorsByExerciseId(String exerciseId) async {
    try {
      final db = await databaseHelper.database;
      await db.delete(
        DatabaseTables.exerciseMuscleFactors,
        where: '${DatabaseTables.factorExerciseId} = ?',
        whereArgs: [exerciseId],
      );
    } catch (e) {
      throw CacheDatabaseException('Failed to delete factors for exercise: $e');
    }
  }

  /// Clear all muscle factors.
  Future<void> clearAllFactors() async {
    try {
      final db = await databaseHelper.database;
      await db.delete(DatabaseTables.exerciseMuscleFactors);
    } catch (e) {
      throw CacheDatabaseException('Failed to clear all factors: $e');
    }
  }
}
