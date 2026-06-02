import 'package:dartz/dartz.dart';

import '../../core/enums/data_source_preference.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../core/errors/sync_exceptions.dart';
import '../../core/logging/app_logger.dart';
import '../../core/sync/local_remote_merge.dart';
import '../../domain/entities/workout_set.dart';
import '../../domain/repositories/workout_set_repository.dart';
import '../datasources/local/workout_set_local_datasource.dart';
import '../datasources/remote/workout_set_remote_datasource.dart';
import '../sync/workout_set_sync_coordinator.dart';

class WorkoutSetRepositoryImpl implements WorkoutSetRepository {
  final WorkoutSetLocalDataSource localDataSource;
  final WorkoutSetRemoteDataSource remoteDataSource;
  final WorkoutSetSyncCoordinator syncCoordinator;

  static final LocalRemoteMerge<WorkoutSet> _merge =
      LocalRemoteMerge<WorkoutSet>(
        getId: (set) => set.id,
        getUpdatedAt: (set) => set.updatedAt,
        getSyncMetadata: (set) => set.syncMetadata,
      );

  const WorkoutSetRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
    required this.syncCoordinator,
  });

  @override
  Future<Either<Failure, List<WorkoutSet>>> getAllSets({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      return _readAllSets(sourcePreference);
    });
  }

  @override
  Future<Either<Failure, WorkoutSet?>> getSetById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      switch (sourcePreference) {
        case DataSourcePreference.localOnly:
          return localDataSource.getSetById(id);

        case DataSourcePreference.remoteOnly:
          if (!remoteDataSource.isConfigured) {
            return null;
          }
          return remoteDataSource.getSetById(id);

        case DataSourcePreference.localThenRemote:
          final local = await localDataSource.getSetById(id);
          if (local != null) {
            return local;
          }

          if (!remoteDataSource.isConfigured) {
            return null;
          }

          final remote = await remoteDataSource.getSetById(id);
          if (remote != null) {
            await localDataSource.upsertSet(remote);
          }
          return localDataSource.getSetById(id);

        case DataSourcePreference.remoteThenLocal:
          if (!remoteDataSource.isConfigured) {
            return localDataSource.getSetById(id);
          }

          final local = await localDataSource.getSetById(id);
          final remote = await remoteDataSource.getSetById(id);

          if (remote == null) {
            return local;
          }

          if (local == null) {
            await localDataSource.upsertSet(remote);
            return localDataSource.getSetById(id);
          }

          final merged = _merge.chooseWinner(local: local, remote: remote);
          await localDataSource.upsertSet(merged);
          return localDataSource.getSetById(id);
      }
    });
  }

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByExerciseId(
    String exerciseId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) {
    return RepositoryGuard.run(() async {
      if (sourcePreference == DataSourcePreference.localOnly ||
          !remoteDataSource.isConfigured) {
        return localDataSource.getSetsByExerciseId(exerciseId);
      }

      final sets = await _readAllSets(sourcePreference);
      return sets.where((set) => set.exerciseId == exerciseId).toList();
    });
  }

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
    int? limit,
  }) {
    return RepositoryGuard.run(() async {
      if (sourcePreference == DataSourcePreference.localOnly ||
          !remoteDataSource.isConfigured) {
        return localDataSource.getSetsByDateRange(
          startDate,
          endDate,
          limit: limit,
        );
      }
      final local = await localDataSource.getSetsByDateRange(
        startDate,
        endDate,
        limit: limit,
      );
      final remote = await _tryRemoteFetch(
        () => remoteDataSource.fetchByDateRange(
          startDate: startDate,
          endDate: endDate,
          limit: limit,
        ),
        context: 'getSetsByDateRange(remoteThenLocal)',
      );
      if (remote == null) return local;
      final merged = _merge.mergeLists(localItems: local, remoteItems: remote);
      await localDataSource.mergeRemoteSets(merged);
      return localDataSource.getSetsByDateRange(
        startDate,
        endDate,
        limit: limit,
      );
    });
  }

  @override
  Future<Either<Failure, void>> addSet(WorkoutSet set) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistAddedSet(set);
    });
  }

  @override
  Future<Either<Failure, void>> updateSet(WorkoutSet set) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistUpdatedSet(set);
    });
  }

  @override
  Future<Either<Failure, void>> deleteSet(String id) {
    return RepositoryGuard.run(() async {
      await syncCoordinator.persistDeletedSet(id);
    });
  }

  @override
  Future<Either<Failure, void>> clearAllSets() {
    return RepositoryGuard.run(() async {
      await localDataSource.clearAllSets();
    });
  }

  @override
  Future<Either<Failure, void>> syncPendingSets() {
    return RepositoryGuard.run(() async {
      await syncCoordinator.syncPendingChanges();
    });
  }

  Future<List<WorkoutSet>> _readAllSets(
    DataSourcePreference sourcePreference,
  ) async {
    switch (sourcePreference) {
      case DataSourcePreference.localOnly:
        return localDataSource.getAllSets();

      case DataSourcePreference.remoteOnly:
        if (!remoteDataSource.isConfigured) {
          return const <WorkoutSet>[];
        }
        return remoteDataSource.getAllSets();

      case DataSourcePreference.localThenRemote:
        final local = await localDataSource.getAllSets();
        if (local.isNotEmpty || !remoteDataSource.isConfigured) {
          return local;
        }

        final remote = await _tryRemoteFetch(
          remoteDataSource.getAllSets,
          context: 'getAllSets(localThenRemote)',
        );
        if (remote != null && remote.isNotEmpty) {
          await localDataSource.mergeRemoteSets(remote);
        }
        return localDataSource.getAllSets();

      case DataSourcePreference.remoteThenLocal:
        if (!remoteDataSource.isConfigured) {
          return localDataSource.getAllSets();
        }

        final local = await localDataSource.getAllSets();
        final remote = await _tryRemoteFetch(
          remoteDataSource.getAllSets,
          context: 'getAllSets(remoteThenLocal)',
        );

        if (remote == null || remote.isEmpty) {
          return local;
        }

        final merged = _merge.mergeLists(
          localItems: local,
          remoteItems: remote,
        );

        await localDataSource.mergeRemoteSets(merged);
        return localDataSource.getAllSets();
    }
  }

  /// Runs [fetch] and returns `null` on any transient remote failure
  /// (auth, network, or backend error), logging a warning with [context].
  /// Local DB exceptions propagate unchanged so they surface as real errors.
  static Future<List<WorkoutSet>?> _tryRemoteFetch(
    Future<List<WorkoutSet>> Function() fetch, {
    required String context,
  }) async {
    try {
      return await fetch();
    } on AuthSyncException catch (e) {
      AppLogger.warning(
        '$context: auth failure, will use local cache — $e',
        category: 'workout_set_repository',
      );
      return null;
    } on NetworkSyncException catch (e) {
      AppLogger.warning(
        '$context: network failure, will use local cache — $e',
        category: 'workout_set_repository',
      );
      return null;
    } on RemoteSyncException catch (e) {
      AppLogger.warning(
        '$context: remote failure, will use local cache — $e',
        category: 'workout_set_repository',
      );
      return null;
    }
  }
}
