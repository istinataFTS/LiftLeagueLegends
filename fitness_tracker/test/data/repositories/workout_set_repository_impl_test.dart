import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/workout_set_remote_datasource.dart';
import 'package:fitness_tracker/data/repositories/workout_set_repository_impl.dart';
import 'package:fitness_tracker/data/sync/workout_set_sync_coordinator.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetLocalDataSource extends Mock
    implements WorkoutSetLocalDataSource {}

class MockWorkoutSetRemoteDataSource extends Mock
    implements WorkoutSetRemoteDataSource {}

class MockWorkoutSetSyncCoordinator extends Mock
    implements WorkoutSetSyncCoordinator {}

void main() {
  late MockWorkoutSetLocalDataSource localDataSource;
  late MockWorkoutSetRemoteDataSource remoteDataSource;
  late MockWorkoutSetSyncCoordinator syncCoordinator;
  late WorkoutSetRepositoryImpl repository;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  WorkoutSet buildWorkoutSet({
    required String id,
    required String exerciseId,
    required DateTime date,
    int reps = 10,
    double weight = 80,
    int intensity = 8,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: exerciseId,
      reps: reps,
      weight: weight,
      intensity: intensity,
      date: date,
      createdAt: date,
      updatedAt: date,
      syncMetadata: syncMetadata,
    );
  }

  setUp(() {
    localDataSource = MockWorkoutSetLocalDataSource();
    remoteDataSource = MockWorkoutSetRemoteDataSource();
    syncCoordinator = MockWorkoutSetSyncCoordinator();

    repository = WorkoutSetRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncCoordinator: syncCoordinator,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(() => syncCoordinator.isRemoteSyncEnabled).thenReturn(false);
  });

  group('WorkoutSetRepositoryImpl.getAllSets', () {
    test('returns local sets for localOnly', () async {
      final List<WorkoutSet> localSets = <WorkoutSet>[
        buildWorkoutSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      ];

      when(
        () => localDataSource.getAllSets(),
      ).thenAnswer((_) async => localSets);

      final Either<Failure, List<WorkoutSet>> result = await repository
          .getAllSets();

      expect(result, Right<Failure, List<WorkoutSet>>(localSets));
      verify(() => localDataSource.getAllSets()).called(1);
      verifyNever(() => remoteDataSource.getAllSets());
      verifyNever(() => localDataSource.mergeRemoteSets(any()));
    });

    test(
      'merges remote cache for remoteThenLocal instead of replaceAll',
      () async {
        final List<WorkoutSet> localSets = <WorkoutSet>[
          buildWorkoutSet(
            id: 'set-1',
            exerciseId: 'bench',
            date: baseDate,
            weight: 90,
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.pendingUpdate,
            ),
          ),
        ];

        final List<WorkoutSet> remoteSets = <WorkoutSet>[
          buildWorkoutSet(
            id: 'set-1',
            exerciseId: 'bench',
            date: baseDate,
            weight: 100,
            syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
          ),
          buildWorkoutSet(
            id: 'set-2',
            exerciseId: 'squat',
            date: baseDate.add(const Duration(days: 1)),
            syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
          ),
        ];

        final List<WorkoutSet> mergedSets = <WorkoutSet>[
          localSets.first,
          remoteSets.last,
        ];

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getAllSets(),
        ).thenAnswer((_) async => localSets);
        when(
          () => remoteDataSource.getAllSets(),
        ).thenAnswer((_) async => remoteSets);
        when(
          () => localDataSource.mergeRemoteSets(any()),
        ).thenAnswer((_) async {});
        when(
          () => localDataSource.getAllSets(),
        ).thenAnswer((_) async => mergedSets);

        final Either<Failure, List<WorkoutSet>> result = await repository
            .getAllSets(sourcePreference: DataSourcePreference.remoteThenLocal);

        expect(result, Right<Failure, List<WorkoutSet>>(mergedSets));
        verify(() => remoteDataSource.getAllSets()).called(1);
        verify(() => localDataSource.mergeRemoteSets(any())).called(1);
      },
    );
  });

  group('WorkoutSetRepositoryImpl.getSetById', () {
    test(
      'returns null without remote lookup when local cache is empty',
      () async {
        when(
          () => localDataSource.getSetById('set-1'),
        ).thenAnswer((_) async => null);

        final Either<Failure, WorkoutSet?> result = await repository.getSetById(
          'set-1',
          sourcePreference: DataSourcePreference.localThenRemote,
        );

        expect(result, const Right<Failure, WorkoutSet?>(null));
        verifyNever(() => remoteDataSource.getSetById(any()));
      },
    );

    test(
      'preserves pending local update over remote in remoteThenLocal',
      () async {
        final WorkoutSet localSet = buildWorkoutSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          weight: 80,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        );

        final WorkoutSet remoteSet = buildWorkoutSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          weight: 100,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getSetById('set-1'),
        ).thenAnswer((_) async => localSet);
        when(
          () => remoteDataSource.getSetById('set-1'),
        ).thenAnswer((_) async => remoteSet);
        when(
          () => localDataSource.upsertSet(localSet),
        ).thenAnswer((_) async {});

        final Either<Failure, WorkoutSet?> result = await repository.getSetById(
          'set-1',
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, WorkoutSet?>(localSet));
        verify(() => localDataSource.upsertSet(localSet)).called(1);
      },
    );

    test('returns local cache snapshot after localThenRemote upsert', () async {
      final WorkoutSet remoteSet = buildWorkoutSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getSetById('set-1')).thenAnswer((_) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : remoteSet;
      });
      when(
        () => remoteDataSource.getSetById('set-1'),
      ).thenAnswer((_) async => remoteSet);
      when(() => localDataSource.upsertSet(remoteSet)).thenAnswer((_) async {});

      final Either<Failure, WorkoutSet?> result = await repository.getSetById(
        'set-1',
        sourcePreference: DataSourcePreference.localThenRemote,
      );

      expect(result, Right<Failure, WorkoutSet?>(remoteSet));
      verify(() => localDataSource.getSetById('set-1')).called(2);
      verify(() => localDataSource.upsertSet(remoteSet)).called(1);
    });

    test(
      'returns null when hidden pending delete remains after remote refresh',
      () async {
        final WorkoutSet remoteSet = buildWorkoutSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getSetById('set-1'),
        ).thenAnswer((_) async => null);
        when(
          () => remoteDataSource.getSetById('set-1'),
        ).thenAnswer((_) async => remoteSet);
        when(
          () => localDataSource.upsertSet(remoteSet),
        ).thenAnswer((_) async {});

        final Either<Failure, WorkoutSet?> result = await repository.getSetById(
          'set-1',
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, const Right<Failure, WorkoutSet?>(null));
        verify(() => localDataSource.getSetById('set-1')).called(2);
        verify(() => localDataSource.upsertSet(remoteSet)).called(1);
      },
    );
  });

  group('WorkoutSetRepositoryImpl.getSetsByDateRange', () {
    final DateTime start = DateTime(2026, 3, 22, 0, 0);
    final DateTime end = DateTime(2026, 3, 22, 23, 59, 59);

    test(
      'uses local window only when unconfigured (isConfigured=false)',
      () async {
        final List<WorkoutSet> localSets = <WorkoutSet>[
          buildWorkoutSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
        ];

        when(
          () => localDataSource.getSetsByDateRange(start, end),
        ).thenAnswer((_) async => localSets);

        final result = await repository.getSetsByDateRange(
          start,
          end,
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, List<WorkoutSet>>(localSets));
        verify(() => localDataSource.getSetsByDateRange(start, end)).called(1);
        verifyNever(
          () => remoteDataSource.fetchByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        );
        verifyNever(() => remoteDataSource.getAllSets());
      },
    );

    test('remoteThenLocal calls fetchByDateRange — never getAllSets', () async {
      final List<WorkoutSet> localSets = <WorkoutSet>[
        buildWorkoutSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      ];
      final List<WorkoutSet> remoteSets = <WorkoutSet>[
        buildWorkoutSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          weight: 100,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      ];

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => localSets);
      when(
        () => remoteDataSource.fetchByDateRange(startDate: start, endDate: end),
      ).thenAnswer((_) async => remoteSets);
      when(
        () => localDataSource.mergeRemoteSets(any()),
      ).thenAnswer((_) async {});

      final result = await repository.getSetsByDateRange(
        start,
        end,
        sourcePreference: DataSourcePreference.remoteThenLocal,
      );

      expect(result.isRight(), isTrue);
      verify(
        () => remoteDataSource.fetchByDateRange(startDate: start, endDate: end),
      ).called(1);
      verifyNever(() => remoteDataSource.getAllSets());
      verify(() => localDataSource.mergeRemoteSets(any())).called(1);
    });

    test(
      'falls back to local window when remote throws NetworkSyncException',
      () async {
        final List<WorkoutSet> localSets = <WorkoutSet>[
          buildWorkoutSet(id: 'set-now', exerciseId: 'bench', date: baseDate),
        ];

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getSetsByDateRange(start, end),
        ).thenAnswer((_) async => localSets);
        when(
          () =>
              remoteDataSource.fetchByDateRange(startDate: start, endDate: end),
        ).thenThrow(const NetworkSyncException('offline'));

        final result = await repository.getSetsByDateRange(
          start,
          end,
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, List<WorkoutSet>>(localSets));
        verifyNever(() => localDataSource.mergeRemoteSets(any()));
      },
    );

    test('local-only set within window survives windowed merge', () async {
      final WorkoutSet localOnlySet = buildWorkoutSet(
        id: 'set-local-only',
        exerciseId: 'bench',
        date: baseDate,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpload,
        ),
      );
      // Capture the same list reference in both the mock and the assertion:
      // Right<Failure, List<WorkoutSet>>.== uses List.== (reference equality),
      // so returning a new literal each call would produce a false negative.
      final List<WorkoutSet> localWindow = <WorkoutSet>[localOnlySet];

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => localWindow);
      when(
        () => remoteDataSource.fetchByDateRange(startDate: start, endDate: end),
      ).thenAnswer((_) async => const <WorkoutSet>[]);
      when(
        () => localDataSource.mergeRemoteSets(any()),
      ).thenAnswer((_) async {});

      final result = await repository.getSetsByDateRange(
        start,
        end,
        sourcePreference: DataSourcePreference.remoteThenLocal,
      );

      expect(result, Right<Failure, List<WorkoutSet>>(localWindow));
      final captured = verify(
        () => localDataSource.mergeRemoteSets(captureAny()),
      ).captured;
      final mergedList = captured.first as List<WorkoutSet>;
      expect(mergedList.any((s) => s.id == 'set-local-only'), isTrue);
    });
  });

  group('WorkoutSetRepositoryImpl writes', () {
    test('addSet delegates to sync coordinator', () async {
      final WorkoutSet set = buildWorkoutSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
      );

      when(() => syncCoordinator.persistAddedSet(set)).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.addSet(set);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistAddedSet(set)).called(1);
    });

    test('updateSet delegates to sync coordinator', () async {
      final WorkoutSet set = buildWorkoutSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
      );

      when(
        () => syncCoordinator.persistUpdatedSet(set),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.updateSet(set);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistUpdatedSet(set)).called(1);
    });

    test('deleteSet delegates to sync coordinator', () async {
      when(
        () => syncCoordinator.persistDeletedSet('set-1'),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.deleteSet('set-1');

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistDeletedSet('set-1')).called(1);
    });
  });
}
