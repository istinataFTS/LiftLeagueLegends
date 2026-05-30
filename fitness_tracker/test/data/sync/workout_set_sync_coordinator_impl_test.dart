import 'package:fitness_tracker/core/enums/sync_entity_type.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/datasources/local/pending_sync_delete_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/workout_set_remote_datasource.dart';
import 'package:fitness_tracker/data/sync/workout_set_sync_coordinator_impl.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/pending_sync_delete.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetLocalDataSource extends Mock
    implements WorkoutSetLocalDataSource {}

class MockWorkoutSetRemoteDataSource extends Mock
    implements WorkoutSetRemoteDataSource {}

class MockPendingSyncDeleteLocalDataSource extends Mock
    implements PendingSyncDeleteLocalDataSource {}

void main() {
  late MockWorkoutSetLocalDataSource localDataSource;
  late MockWorkoutSetRemoteDataSource remoteDataSource;
  late MockPendingSyncDeleteLocalDataSource pendingDeleteDataSource;
  late WorkoutSetSyncCoordinatorImpl coordinator;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  setUpAll(() {
    registerFallbackValue(
      PendingSyncDelete(
        id: 'fallback-delete',
        entityType: SyncEntityType.workoutSet,
        localEntityId: 'fallback-local-id',
        serverEntityId: 'fallback-server-id',
        createdAt: DateTime(2026, 3, 22, 10, 0),
      ),
    );
    registerFallbackValue(
      WorkoutSet(
        id: 'fallback-set',
        exerciseId: 'fallback-exercise',
        reps: 10,
        weight: 80,
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  WorkoutSet buildWorkoutSet({
    required String id,
    SyncStatus status = SyncStatus.synced,
    String? serverId = 'server-1',
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: 'bench',
      reps: 10,
      weight: 80,
      intensity: 8,
      date: baseDate,
      createdAt: baseDate,
      updatedAt: baseDate,
      syncMetadata: EntitySyncMetadata(status: status, serverId: serverId),
    );
  }

  setUp(() {
    localDataSource = MockWorkoutSetLocalDataSource();
    remoteDataSource = MockWorkoutSetRemoteDataSource();
    pendingDeleteDataSource = MockPendingSyncDeleteLocalDataSource();

    coordinator = WorkoutSetSyncCoordinatorImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
    );
  });

  test(
    'prepareForInitialCloudMigration delegates to local datasource',
    () async {
      when(
        () => localDataSource.prepareForInitialCloudMigration(userId: 'user-1'),
      ).thenAnswer((_) async {});

      await coordinator.prepareForInitialCloudMigration('user-1');

      verify(
        () => localDataSource.prepareForInitialCloudMigration(userId: 'user-1'),
      ).called(1);
      verifyNever(() => remoteDataSource.upsertSet(any()));
    },
  );

  test(
    'delete marks synced row as pending delete before remote delete',
    () async {
      final existing = buildWorkoutSet(id: 'set-1');

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getSetById('set-1'),
      ).thenAnswer((_) async => existing);
      when(
        () => pendingDeleteDataSource.enqueue(any()),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.markAsPendingDelete('set-1'),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.getPendingByEntityType(
          SyncEntityType.workoutSet,
        ),
      ).thenAnswer(
        (_) async => <PendingSyncDelete>[
          PendingSyncDelete(
            id: 'delete-1',
            entityType: SyncEntityType.workoutSet,
            localEntityId: 'set-1',
            serverEntityId: 'server-1',
            createdAt: DateTime.now(),
          ),
        ],
      );
      when(
        () =>
            remoteDataSource.deleteSet(localId: 'set-1', serverId: 'server-1'),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.remove('delete-1'),
      ).thenAnswer((_) async {});
      when(() => localDataSource.deleteSet('set-1')).thenAnswer((_) async {});

      await coordinator.persistDeletedSet('set-1');

      verify(() => localDataSource.markAsPendingDelete('set-1')).called(1);
      verify(
        () =>
            remoteDataSource.deleteSet(localId: 'set-1', serverId: 'server-1'),
      ).called(1);
      verify(() => localDataSource.deleteSet('set-1')).called(1);
    },
  );

  test('delete removes purely local row immediately', () async {
    final existing = buildWorkoutSet(
      id: 'set-1',
      status: SyncStatus.localOnly,
      serverId: null,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(
      () => localDataSource.getSetById('set-1'),
    ).thenAnswer((_) async => existing);
    when(() => localDataSource.deleteSet('set-1')).thenAnswer((_) async {});

    await coordinator.persistDeletedSet('set-1');

    verifyNever(() => localDataSource.markAsPendingDelete(any()));
    verify(() => localDataSource.deleteSet('set-1')).called(1);
  });

  // ---------------------------------------------------------------------------
  // Guest-owner guard
  // ---------------------------------------------------------------------------

  group('sync metadata', () {
    WorkoutSet buildSet({String? ownerUserId}) => WorkoutSet(
      id: 'set-1',
      ownerUserId: ownerUserId,
      exerciseId: 'bench',
      reps: 10,
      weight: 80,
      date: baseDate,
      createdAt: baseDate,
    );

    test(
      'buildAddedLocalEntity stamps authenticated-user set as pendingUpload',
      () {
        when(() => remoteDataSource.isConfigured).thenReturn(true);

        final result = coordinator.buildAddedLocalEntity(
          buildSet(ownerUserId: 'user-1'),
          baseDate,
        );

        expect(result.syncMetadata.status, SyncStatus.pendingUpload);
      },
    );
  });
}
