import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/data/datasources/local/exercise_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/exercise_remote_datasource.dart';
import 'package:fitness_tracker/data/models/exercise_model.dart';
import 'package:fitness_tracker/data/repositories/exercise_repository_impl.dart';
import 'package:fitness_tracker/data/sync/exercise_sync_coordinator.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseLocalDataSource extends Mock
    implements ExerciseLocalDataSource {}

class MockExerciseRemoteDataSource extends Mock
    implements ExerciseRemoteDataSource {}

class MockExerciseSyncCoordinator extends Mock
    implements ExerciseSyncCoordinator {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      ExerciseModel(
        id: 'fallback-id',
        name: 'Fallback Exercise',
        muscleGroups: const <String>['chest'],
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockExerciseLocalDataSource localDataSource;
  late MockExerciseRemoteDataSource remoteDataSource;
  late MockExerciseSyncCoordinator syncCoordinator;
  late ExerciseRepositoryImpl repository;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  Exercise buildExercise({
    required String id,
    required String name,
    List<String> muscleGroups = const <String>['chest', 'triceps'],
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return Exercise(
      id: id,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: baseDate,
      updatedAt: baseDate,
      syncMetadata: syncMetadata,
    );
  }

  ExerciseModel buildExerciseModel({
    required String id,
    required String name,
    List<String> muscleGroups = const <String>['chest', 'triceps'],
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return ExerciseModel(
      id: id,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: baseDate,
      updatedAt: baseDate,
      syncMetadata: syncMetadata,
    );
  }

  setUp(() {
    localDataSource = MockExerciseLocalDataSource();
    remoteDataSource = MockExerciseRemoteDataSource();
    syncCoordinator = MockExerciseSyncCoordinator();

    repository = ExerciseRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncCoordinator: syncCoordinator,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(() => syncCoordinator.isRemoteSyncEnabled).thenReturn(false);
  });

  group('ExerciseRepositoryImpl.getAllExercises', () {
    test('returns local exercises for localOnly', () async {
      final List<ExerciseModel> localExercises = <ExerciseModel>[
        buildExerciseModel(id: 'exercise-1', name: 'Bench Press'),
      ];

      when(
        () => localDataSource.getAllExercises(),
      ).thenAnswer((_) async => localExercises);

      final Either<Failure, List<Exercise>> result = await repository
          .getAllExercises();

      expect(result, Right<Failure, List<Exercise>>(localExercises));
      verify(() => localDataSource.getAllExercises()).called(1);
      verifyNever(() => remoteDataSource.getAllExercises());
      verifyNever(() => localDataSource.mergeRemoteExercises(any()));
    });

    group('remoteThenLocal falls back to local cache on remote failure', () {
      // Helper: stubs local to return [localExercises] and remote to throw [error].
      void stubRemoteThrows(List<ExerciseModel> localExercises, Object error) {
        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getAllExercises(),
        ).thenAnswer((_) async => localExercises);
        when(() => remoteDataSource.getAllExercises()).thenThrow(error);
      }

      final List<ExerciseModel> localCache = <ExerciseModel>[
        ExerciseModel(
          id: 'ex-1',
          name: 'Bench Press',
          muscleGroups: const <String>['chest'],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ];

      test('serves local cache when remote throws AuthSyncException', () async {
        stubRemoteThrows(localCache, const AuthSyncException('token expired'));

        final result = await repository.getAllExercises(
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, List<Exercise>>(localCache));
        verifyNever(() => localDataSource.mergeRemoteExercises(any()));
      });

      test(
        'serves local cache when remote throws NetworkSyncException',
        () async {
          stubRemoteThrows(
            localCache,
            const NetworkSyncException('no internet'),
          );

          final result = await repository.getAllExercises(
            sourcePreference: DataSourcePreference.remoteThenLocal,
          );

          expect(result, Right<Failure, List<Exercise>>(localCache));
          verifyNever(() => localDataSource.mergeRemoteExercises(any()));
        },
      );

      test(
        'serves local cache when remote throws RemoteSyncException',
        () async {
          stubRemoteThrows(
            localCache,
            const RemoteSyncException('postgrest error'),
          );

          final result = await repository.getAllExercises(
            sourcePreference: DataSourcePreference.remoteThenLocal,
          );

          expect(result, Right<Failure, List<Exercise>>(localCache));
          verifyNever(() => localDataSource.mergeRemoteExercises(any()));
        },
      );
    });

    group(
      'localThenRemote skips merge and returns local on remote failure',
      () {
        // Remote is only reached when local cache is empty. The branch calls
        // getAllExercises twice (pre-check + final return), so the mock answers
        // both calls. List equality in Dart is referential, so we assert on
        // isRight() + isEmpty rather than comparing list instances.
        void stubEmptyLocalRemoteThrows(Object error) {
          when(() => remoteDataSource.isConfigured).thenReturn(true);
          when(
            () => localDataSource.getAllExercises(),
          ).thenAnswer((_) async => <ExerciseModel>[]);
          when(() => remoteDataSource.getAllExercises()).thenThrow(error);
        }

        test(
          'returns empty local when remote throws AuthSyncException',
          () async {
            stubEmptyLocalRemoteThrows(
              const AuthSyncException('not signed in'),
            );

            final result = await repository.getAllExercises(
              sourcePreference: DataSourcePreference.localThenRemote,
            );

            expect(result.isRight(), isTrue);
            expect(result.getOrElse(() => throw Exception()), isEmpty);
            verifyNever(() => localDataSource.mergeRemoteExercises(any()));
          },
        );

        test(
          'returns empty local when remote throws NetworkSyncException',
          () async {
            stubEmptyLocalRemoteThrows(const NetworkSyncException('timeout'));

            final result = await repository.getAllExercises(
              sourcePreference: DataSourcePreference.localThenRemote,
            );

            expect(result.isRight(), isTrue);
            expect(result.getOrElse(() => throw Exception()), isEmpty);
            verifyNever(() => localDataSource.mergeRemoteExercises(any()));
          },
        );

        test(
          'returns empty local when remote throws RemoteSyncException',
          () async {
            stubEmptyLocalRemoteThrows(
              const RemoteSyncException('server error'),
            );

            final result = await repository.getAllExercises(
              sourcePreference: DataSourcePreference.localThenRemote,
            );

            expect(result.isRight(), isTrue);
            expect(result.getOrElse(() => throw Exception()), isEmpty);
            verifyNever(() => localDataSource.mergeRemoteExercises(any()));
          },
        );
      },
    );

    test(
      'merges remote cache for remoteThenLocal instead of replaceAll',
      () async {
        final List<ExerciseModel> localExercises = <ExerciseModel>[
          buildExerciseModel(
            id: 'exercise-1',
            name: 'Bench Press',
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.pendingUpdate,
            ),
          ),
        ];

        final List<Exercise> remoteExercises = <Exercise>[
          buildExercise(
            id: 'exercise-1',
            name: 'Bench Press Remote',
            syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
          ),
          buildExercise(
            id: 'exercise-2',
            name: 'Squat',
            muscleGroups: const <String>['quads', 'glutes'],
            syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
          ),
        ];

        final List<ExerciseModel> mergedExercises = <ExerciseModel>[
          localExercises.first,
          buildExerciseModel(
            id: 'exercise-2',
            name: 'Squat',
            muscleGroups: const <String>['quads', 'glutes'],
            syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
          ),
        ];

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getAllExercises(),
        ).thenAnswer((_) async => localExercises);
        when(
          () => remoteDataSource.getAllExercises(),
        ).thenAnswer((_) async => remoteExercises);
        when(
          () => localDataSource.mergeRemoteExercises(any()),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.getAllExercises(),
        ).thenAnswer((_) async => mergedExercises);

        final Either<Failure, List<Exercise>> result = await repository
            .getAllExercises(
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        expect(result, Right<Failure, List<Exercise>>(mergedExercises));
        verify(() => remoteDataSource.getAllExercises()).called(1);
        verify(() => localDataSource.mergeRemoteExercises(any())).called(1);
      },
    );
  });

  group('ExerciseRepositoryImpl.getExerciseById', () {
    test(
      'returns null without remote lookup when local cache is empty',
      () async {
        when(
          () => localDataSource.getExerciseById('exercise-1'),
        ).thenAnswer((_) async => null);

        final Either<Failure, Exercise?> result = await repository
            .getExerciseById(
              'exercise-1',
              sourcePreference: DataSourcePreference.localThenRemote,
            );

        expect(result, const Right<Failure, Exercise?>(null));
        verifyNever(() => remoteDataSource.getExerciseById(any()));
      },
    );

    test(
      'preserves pending local update over remote in remoteThenLocal',
      () async {
        final ExerciseModel localExercise = buildExerciseModel(
          id: 'exercise-1',
          name: 'Bench Press Local',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        );

        final Exercise remoteExercise = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press Remote',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getExerciseById('exercise-1'),
        ).thenAnswer((_) async => localExercise);
        when(
          () => remoteDataSource.getExerciseById('exercise-1'),
        ).thenAnswer((_) async => remoteExercise);
        when(
          () => localDataSource.upsertExercise(localExercise),
        ).thenAnswer((_) async {});

        final Either<Failure, Exercise?> result = await repository
            .getExerciseById(
              'exercise-1',
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        expect(result, Right<Failure, Exercise?>(localExercise));
        verify(() => localDataSource.upsertExercise(localExercise)).called(1);
      },
    );

    test('returns local cache snapshot after localThenRemote upsert', () async {
      final Exercise remoteExercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press',
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final ExerciseModel cachedExercise = buildExerciseModel(
        id: 'exercise-1',
        name: 'Bench Press',
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getExerciseById('exercise-1')).thenAnswer((
        _,
      ) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : cachedExercise;
      });
      when(
        () => remoteDataSource.getExerciseById('exercise-1'),
      ).thenAnswer((_) async => remoteExercise);
      when(
        () => localDataSource.upsertExercise(any()),
      ).thenAnswer((_) async {});

      final Either<Failure, Exercise?> result = await repository
          .getExerciseById(
            'exercise-1',
            sourcePreference: DataSourcePreference.localThenRemote,
          );

      expect(result, Right<Failure, Exercise?>(cachedExercise));
      verify(() => localDataSource.getExerciseById('exercise-1')).called(2);
      verify(() => localDataSource.upsertExercise(any())).called(1);
    });

    test(
      'returns null when hidden pending delete remains after remote refresh',
      () async {
        final Exercise remoteExercise = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getExerciseById('exercise-1'),
        ).thenAnswer((_) async => null);
        when(
          () => remoteDataSource.getExerciseById('exercise-1'),
        ).thenAnswer((_) async => remoteExercise);
        when(
          () => localDataSource.upsertExercise(any()),
        ).thenAnswer((_) async {});

        final Either<Failure, Exercise?> result = await repository
            .getExerciseById(
              'exercise-1',
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        expect(result, const Right<Failure, Exercise?>(null));
        verify(() => localDataSource.getExerciseById('exercise-1')).called(2);
        verify(() => localDataSource.upsertExercise(any())).called(1);
      },
    );
  });

  group('ExerciseRepositoryImpl.getExerciseByName', () {
    test('returns local cache snapshot after localThenRemote upsert', () async {
      final Exercise remoteExercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press',
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final ExerciseModel cachedExercise = buildExerciseModel(
        id: 'exercise-1',
        name: 'Bench Press',
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getExerciseByName('Bench Press')).thenAnswer((
        _,
      ) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : cachedExercise;
      });
      when(
        () => remoteDataSource.getExerciseByName('Bench Press'),
      ).thenAnswer((_) async => remoteExercise);
      when(
        () => localDataSource.upsertExercise(any()),
      ).thenAnswer((_) async {});

      final Either<Failure, Exercise?> result = await repository
          .getExerciseByName(
            'Bench Press',
            sourcePreference: DataSourcePreference.localThenRemote,
          );

      expect(result, Right<Failure, Exercise?>(cachedExercise));
      verify(() => localDataSource.getExerciseByName('Bench Press')).called(2);
      verify(() => localDataSource.upsertExercise(any())).called(1);
    });
  });

  group('ExerciseRepositoryImpl writes', () {
    test('clearUserOwnedExercises delegates to local data source', () async {
      when(
        () => localDataSource.clearUserOwnedExercises('user-1'),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository
          .clearUserOwnedExercises('user-1');

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.clearUserOwnedExercises('user-1')).called(1);
      verifyNever(() => localDataSource.clearAllExercises());
    });

    test('addExercise delegates to sync coordinator', () async {
      final Exercise exercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press',
      );

      when(
        () => syncCoordinator.persistAddedExercise(exercise),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.addExercise(
        exercise,
      );

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistAddedExercise(exercise)).called(1);
    });

    test('updateExercise delegates to sync coordinator', () async {
      final Exercise exercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press',
      );

      when(
        () => syncCoordinator.persistUpdatedExercise(exercise),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.updateExercise(
        exercise,
      );

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistUpdatedExercise(exercise)).called(1);
    });

    test('deleteExercise delegates to sync coordinator', () async {
      when(
        () => syncCoordinator.persistDeletedExercise('exercise-1'),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.deleteExercise(
        'exercise-1',
      );

      expect(result.isRight(), isTrue);
      verify(
        () => syncCoordinator.persistDeletedExercise('exercise-1'),
      ).called(1);
    });
  });
}
