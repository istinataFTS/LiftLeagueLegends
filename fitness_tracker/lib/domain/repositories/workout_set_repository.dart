import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../entities/workout_set.dart';

abstract class WorkoutSetRepository {
  Future<Either<Failure, List<WorkoutSet>>> getAllSets({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, WorkoutSet?>> getSetById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<WorkoutSet>>> getSetsByExerciseId(
    String exerciseId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  });

  Future<Either<Failure, List<WorkoutSet>>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
    int? limit,
  });

  Future<Either<Failure, void>> addSet(WorkoutSet set);

  Future<Either<Failure, void>> updateSet(WorkoutSet set);

  Future<Either<Failure, void>> deleteSet(String id);

  Future<Either<Failure, void>> clearAllSets();

  Future<Either<Failure, void>> syncPendingSets();
}
