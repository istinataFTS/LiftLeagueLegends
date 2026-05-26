import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../entities/exercise.dart';

abstract class ExerciseRepository {
  Future<Either<Failure, List<Exercise>>> getAllExercises({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, Exercise?>> getExerciseById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, Exercise?>> getExerciseByName(
    String name, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<Exercise>>> getExercisesForMuscle(
    String muscleGroup, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, void>> addExercise(Exercise exercise);

  Future<Either<Failure, void>> updateExercise(Exercise exercise);

  Future<Either<Failure, void>> deleteExercise(String id);

  Future<Either<Failure, void>> clearAllExercises();

  /// Deletes only exercises owned by [userId]. Seeded/system exercises
  /// (owner_user_id IS NULL) are never touched.
  Future<Either<Failure, void>> clearUserOwnedExercises(String userId);

  Future<Either<Failure, void>> syncPendingExercises();
}
