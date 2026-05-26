import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../core/errors/sync_exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/sync/local_remote_merge.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../datasources/local/exercise_local_datasource.dart';
import '../datasources/remote/exercise_remote_datasource.dart';
import '../models/exercise_model.dart';
import '../sync/exercise_sync_coordinator.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseLocalDataSource localDataSource;
  final ExerciseRemoteDataSource remoteDataSource;
  final ExerciseSyncCoordinator syncCoordinator;

  static final LocalRemoteMerge<Exercise> _merge = LocalRemoteMerge<Exercise>(
    getId: (exercise) => exercise.id,
    getUpdatedAt: (exercise) => exercise.updatedAt,
    getSyncMetadata: (exercise) => exercise.syncMetadata,
  );

  const ExerciseRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncCoordinator,
  });

  @override
  Future<Either<Failure, List<Exercise>>> getAllExercises({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      switch (sourcePreference) {
        case DataSourcePreference.localOnly:
          return localDataSource.getAllExercises();

        case DataSourcePreference.remoteOnly:
          if (!remoteDataSource.isConfigured) {
            return const <Exercise>[];
          }
          return remoteDataSource.getAllExercises();

        case DataSourcePreference.localThenRemote:
          final localExercises = await localDataSource.getAllExercises();
          if (localExercises.isNotEmpty || !remoteDataSource.isConfigured) {
            return localExercises;
          }

          final remoteForLocal = await _tryRemoteFetch(
            remoteDataSource.getAllExercises,
            context: 'getAllExercises(localThenRemote)',
          );
          if (remoteForLocal != null && remoteForLocal.isNotEmpty) {
            await localDataSource.mergeRemoteExercises(
              remoteForLocal.map(ExerciseModel.fromEntity).toList(),
            );
          }
          return localDataSource.getAllExercises();

        case DataSourcePreference.remoteThenLocal:
          if (!remoteDataSource.isConfigured) {
            return localDataSource.getAllExercises();
          }

          final localExercises = await localDataSource.getAllExercises();
          final remoteExercises = await _tryRemoteFetch(
            remoteDataSource.getAllExercises,
            context: 'getAllExercises(remoteThenLocal)',
          );

          if (remoteExercises == null || remoteExercises.isEmpty) {
            return localExercises;
          }

          final merged = _merge.mergeLists(
            localItems: localExercises,
            remoteItems: remoteExercises,
          );

          await localDataSource.mergeRemoteExercises(
            merged.map(ExerciseModel.fromEntity).toList(),
          );

          return localDataSource.getAllExercises();
      }
    });
  }

  @override
  Future<Either<Failure, Exercise?>> getExerciseById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      switch (sourcePreference) {
        case DataSourcePreference.localOnly:
          return localDataSource.getExerciseById(id);

        case DataSourcePreference.remoteOnly:
          if (!remoteDataSource.isConfigured) {
            return null;
          }
          return remoteDataSource.getExerciseById(id);

        case DataSourcePreference.localThenRemote:
          final localExercise = await localDataSource.getExerciseById(id);
          if (localExercise != null) {
            return localExercise;
          }

          if (!remoteDataSource.isConfigured) {
            return null;
          }

          final remoteExercise = await remoteDataSource.getExerciseById(id);
          if (remoteExercise != null) {
            await localDataSource.upsertExercise(
              ExerciseModel.fromEntity(remoteExercise),
            );
          }
          return localDataSource.getExerciseById(id);

        case DataSourcePreference.remoteThenLocal:
          if (!remoteDataSource.isConfigured) {
            return localDataSource.getExerciseById(id);
          }

          final localExercise = await localDataSource.getExerciseById(id);
          final remoteExercise = await remoteDataSource.getExerciseById(id);

          if (remoteExercise == null) {
            return localExercise;
          }

          if (localExercise == null) {
            await localDataSource.upsertExercise(
              ExerciseModel.fromEntity(remoteExercise),
            );
            return localDataSource.getExerciseById(id);
          }

          final merged = _merge.chooseWinner(
            local: localExercise,
            remote: remoteExercise,
          );

          await localDataSource.upsertExercise(
            ExerciseModel.fromEntity(merged),
          );

          return localDataSource.getExerciseById(id);
      }
    });
  }

  @override
  Future<Either<Failure, Exercise?>> getExerciseByName(
    String name, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      switch (sourcePreference) {
        case DataSourcePreference.localOnly:
          return localDataSource.getExerciseByName(name);

        case DataSourcePreference.remoteOnly:
          if (!remoteDataSource.isConfigured) {
            return null;
          }
          return remoteDataSource.getExerciseByName(name);

        case DataSourcePreference.localThenRemote:
          final localExercise = await localDataSource.getExerciseByName(name);
          if (localExercise != null) {
            return localExercise;
          }

          if (!remoteDataSource.isConfigured) {
            return null;
          }

          final remoteExercise = await remoteDataSource.getExerciseByName(name);
          if (remoteExercise != null) {
            await localDataSource.upsertExercise(
              ExerciseModel.fromEntity(remoteExercise),
            );
          }
          return localDataSource.getExerciseByName(name);

        case DataSourcePreference.remoteThenLocal:
          if (!remoteDataSource.isConfigured) {
            return localDataSource.getExerciseByName(name);
          }

          final localExercise = await localDataSource.getExerciseByName(name);
          final remoteExercise = await remoteDataSource.getExerciseByName(name);

          if (remoteExercise == null) {
            return localExercise;
          }

          if (localExercise == null) {
            await localDataSource.upsertExercise(
              ExerciseModel.fromEntity(remoteExercise),
            );
            return localDataSource.getExerciseByName(name);
          }

          final merged = _merge.chooseWinner(
            local: localExercise,
            remote: remoteExercise,
          );

          await localDataSource.upsertExercise(
            ExerciseModel.fromEntity(merged),
          );

          return localDataSource.getExerciseByName(name);
      }
    });
  }

  @override
  Future<Either<Failure, List<Exercise>>> getExercisesForMuscle(
    String muscleGroup, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      if (sourcePreference == DataSourcePreference.localOnly ||
          !remoteDataSource.isConfigured) {
        return localDataSource.getExercisesForMuscle(muscleGroup);
      }

      final exercises = await getAllExercises(
        sourcePreference: sourcePreference,
      );
      return exercises.fold(
        (_) => const <Exercise>[],
        (items) => items
            .where((exercise) => exercise.muscleGroups.contains(muscleGroup))
            .toList(),
      );
    });
  }

  @override
  Future<Either<Failure, void>> addExercise(Exercise exercise) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistAddedExercise(exercise);
    });
  }

  @override
  Future<Either<Failure, void>> updateExercise(Exercise exercise) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistUpdatedExercise(exercise);
    });
  }

  @override
  Future<Either<Failure, void>> deleteExercise(String id) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistDeletedExercise(id);
    });
  }

  @override
  Future<Either<Failure, void>> clearAllExercises() {
    return RepositoryGuard.run(() async {
      await localDataSource.clearAllExercises();
    });
  }

  @override
  Future<Either<Failure, void>> clearUserOwnedExercises(String userId) {
    return RepositoryGuard.run(() async {
      await localDataSource.clearUserOwnedExercises(userId);
    });
  }

  @override
  Future<Either<Failure, void>> syncPendingExercises() {
    return RepositoryGuard.run(() async {
      await syncCoordinator.syncPendingChanges();
    });
  }

  /// Runs [fetch] and returns `null` on any transient remote failure
  /// (auth, network, or backend error), logging a warning with [context].
  /// Local DB exceptions propagate unchanged so they surface as real errors.
  static Future<List<Exercise>?> _tryRemoteFetch(
    Future<List<Exercise>> Function() fetch, {
    required String context,
  }) async {
    try {
      return await fetch();
    } on AuthSyncException catch (e) {
      AppLogger.warning(
        '$context: auth failure, will use local cache — $e',
        category: 'exercise_repository',
      );
      return null;
    } on NetworkSyncException catch (e) {
      AppLogger.warning(
        '$context: network failure, will use local cache — $e',
        category: 'exercise_repository',
      );
      return null;
    } on RemoteSyncException catch (e) {
      AppLogger.warning(
        '$context: remote failure, will use local cache — $e',
        category: 'exercise_repository',
      );
      return null;
    }
  }
}
