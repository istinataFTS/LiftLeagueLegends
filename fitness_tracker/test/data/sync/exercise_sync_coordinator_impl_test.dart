import 'package:fitness_tracker/core/enums/sync_entity_type.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/datasources/local/exercise_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/pending_sync_delete_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/exercise_remote_datasource.dart';
import 'package:fitness_tracker/data/models/exercise_model.dart';
import 'package:fitness_tracker/data/sync/exercise_sync_coordinator_impl.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/pending_sync_delete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseLocalDataSource extends Mock
    implements ExerciseLocalDataSource {}

class MockExerciseRemoteDataSource extends Mock
    implements ExerciseRemoteDataSource {}

class MockPendingSyncDeleteLocalDataSource extends Mock
    implements PendingSyncDeleteLocalDataSource {}

void main() {
  late MockExerciseLocalDataSource localDataSource;
  late MockExerciseRemoteDataSource remoteDataSource;
  late MockPendingSyncDeleteLocalDataSource pendingDeleteDataSource;
  late ExerciseSyncCoordinatorImpl coordinator;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  setUpAll(() {
    registerFallbackValue(
      PendingSyncDelete(
        id: 'fallback-delete',
        entityType: SyncEntityType.exercise,
        localEntityId: 'fallback-local-id',
        serverEntityId: 'fallback-server-id',
        createdAt: DateTime(2026, 3, 22, 10, 0),
      ),
    );
    registerFallbackValue(
      ExerciseModel(
        id: 'fallback-exercise',
        name: 'Fallback Exercise',
        muscleGroups: const <String>['chest'],
        createdAt: DateTime(2026, 3, 22, 10, 0),
      ),
    );
  });

  Exercise buildExercise({
    required String id,
    String? ownerUserId = 'user-1',
    SyncStatus status = SyncStatus.synced,
    String? serverId = 'server-1',
  }) {
    return Exercise(
      id: id,
      ownerUserId: ownerUserId,
      name: 'Bench Press',
      muscleGroups: const <String>['chest', 'triceps'],
      createdAt: baseDate,
      updatedAt: baseDate,
      syncMetadata: EntitySyncMetadata(status: status, serverId: serverId),
    );
  }

  setUp(() {
    localDataSource = MockExerciseLocalDataSource();
    remoteDataSource = MockExerciseRemoteDataSource();
    pendingDeleteDataSource = MockPendingSyncDeleteLocalDataSource();

    coordinator = ExerciseSyncCoordinatorImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      pendingSyncDeleteLocalDataSource: pendingDeleteDataSource,
    );
  });

  // ---------------------------------------------------------------------------
  // buildAddedLocalEntity / buildUpdatedLocalEntity sync-status stamping
  // ---------------------------------------------------------------------------

  group('ExerciseSyncCoordinatorImpl sync metadata', () {
    test(
      'buildAddedLocalEntity gives user-owned exercise pendingUpload when remote is configured',
      () {
        when(() => remoteDataSource.isConfigured).thenReturn(true);

        final Exercise userExercise = Exercise(
          id: 'exercise-1',
          ownerUserId: 'user-1',
          name: 'Bench Press',
          muscleGroups: const <String>['chest'],
          createdAt: baseDate,
        );

        final result = coordinator.buildAddedLocalEntity(
          userExercise,
          baseDate,
        );

        expect(result.syncMetadata.status, SyncStatus.pendingUpload);
      },
    );

    test(
      'buildAddedLocalEntity gives user-owned exercise localOnly when remote is not configured',
      () {
        when(() => remoteDataSource.isConfigured).thenReturn(false);

        final Exercise userExercise = Exercise(
          id: 'exercise-1',
          ownerUserId: 'user-1',
          name: 'Bench Press',
          muscleGroups: const <String>['chest'],
          createdAt: baseDate,
        );

        final result = coordinator.buildAddedLocalEntity(
          userExercise,
          baseDate,
        );

        expect(result.syncMetadata.status, SyncStatus.localOnly);
      },
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
      verifyNever(() => remoteDataSource.upsertExercise(any()));
    },
  );

  test(
    'delete marks synced row as pending delete before remote delete',
    () async {
      final Exercise existing = buildExercise(id: 'exercise-1');

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getExerciseById('exercise-1'),
      ).thenAnswer((_) async => ExerciseModel.fromEntity(existing));
      when(
        () => pendingDeleteDataSource.enqueue(any()),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.markAsPendingDelete('exercise-1'),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.getPendingByEntityType(
          SyncEntityType.exercise,
        ),
      ).thenAnswer(
        (_) async => <PendingSyncDelete>[
          PendingSyncDelete(
            id: 'delete-1',
            entityType: SyncEntityType.exercise,
            localEntityId: 'exercise-1',
            serverEntityId: 'server-1',
            createdAt: DateTime.now(),
          ),
        ],
      );
      when(
        () => remoteDataSource.deleteExercise(
          localId: 'exercise-1',
          serverId: 'server-1',
        ),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.remove('delete-1'),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.deleteExercise('exercise-1'),
      ).thenAnswer((_) async {});

      await coordinator.persistDeletedExercise('exercise-1');

      verify(() => localDataSource.markAsPendingDelete('exercise-1')).called(1);
      verify(
        () => remoteDataSource.deleteExercise(
          localId: 'exercise-1',
          serverId: 'server-1',
        ),
      ).called(1);
      verify(() => localDataSource.deleteExercise('exercise-1')).called(1);
    },
  );

  test('delete removes purely local row immediately', () async {
    final Exercise existing = buildExercise(
      id: 'exercise-1',
      status: SyncStatus.localOnly,
      serverId: null,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(
      () => localDataSource.getExerciseById('exercise-1'),
    ).thenAnswer((_) async => ExerciseModel.fromEntity(existing));
    when(
      () => localDataSource.deleteExercise('exercise-1'),
    ).thenAnswer((_) async {});

    await coordinator.persistDeletedExercise('exercise-1');

    verifyNever(() => localDataSource.markAsPendingDelete(any()));
    verify(() => localDataSource.deleteExercise('exercise-1')).called(1);
  });

  // ---------------------------------------------------------------------------
  // insertLocal name+owner reconciliation
  //
  // Regression cover for the "initial migration step failed: exercises" pull
  // bug: when the remote payload's id differs from the local row that
  // already owns the (name, owner) UNIQUE slot, a blind INSERT trips the
  // constraint and aborts the entire feature pull. The coordinator must
  // detect this and update the existing local row in place.
  // ---------------------------------------------------------------------------

  group('ExerciseSyncCoordinatorImpl.insertLocal reconciliation', () {
    test('falls back to updateExercise when a different local row owns the '
        'same (name, owner) slot — preserves the local id so child rows '
        "(workout_sets, factors) keep resolving", () async {
      final Exercise remote = buildExercise(
        id: 'remote-id',
        serverId: 'remote-id',
      );
      final Exercise localCollision = buildExercise(
        id: 'local-id',
        serverId: null,
      );

      when(
        () => localDataSource.getByNameAndOwner(
          name: remote.name,
          ownerUserId: remote.ownerUserId,
        ),
      ).thenAnswer((_) async => ExerciseModel.fromEntity(localCollision));
      when(
        () => localDataSource.updateExercise(any()),
      ).thenAnswer((_) async {});

      await coordinator.insertLocal(remote);

      final captured =
          verify(
                () => localDataSource.updateExercise(captureAny()),
              ).captured.single
              as ExerciseModel;

      expect(
        captured.id,
        'local-id',
        reason:
            'must adopt the remote payload onto the existing local id; '
            'changing the id would orphan workout_sets.exercise_id',
      );
      expect(
        captured.syncMetadata.serverId,
        'remote-id',
        reason: 'remote id is captured as serverId for future pulls',
      );
      verifyNever(() => localDataSource.insertExercise(any()));
    });

    test('inserts when no name+owner collision exists', () async {
      final Exercise remote = buildExercise(id: 'remote-id');

      when(
        () => localDataSource.getByNameAndOwner(
          name: remote.name,
          ownerUserId: remote.ownerUserId,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => localDataSource.insertExercise(any()),
      ).thenAnswer((_) async {});

      await coordinator.insertLocal(remote);

      verify(() => localDataSource.insertExercise(any())).called(1);
      verifyNever(() => localDataSource.updateExercise(any()));
    });

    test('is a no-op-style insert when the name+owner row found is the same id '
        "(should never happen in practice, but proves the guard doesn't "
        'spuriously rewrite valid rows)', () async {
      final Exercise remote = buildExercise(id: 'same-id');

      when(
        () => localDataSource.getByNameAndOwner(
          name: remote.name,
          ownerUserId: remote.ownerUserId,
        ),
      ).thenAnswer((_) async => ExerciseModel.fromEntity(remote));
      when(
        () => localDataSource.insertExercise(any()),
      ).thenAnswer((_) async {});

      await coordinator.insertLocal(remote);

      verify(() => localDataSource.insertExercise(any())).called(1);
      verifyNever(() => localDataSource.updateExercise(any()));
    });
  });
}
