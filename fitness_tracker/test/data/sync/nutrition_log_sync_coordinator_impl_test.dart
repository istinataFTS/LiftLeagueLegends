import 'package:fitness_tracker/core/enums/sync_entity_type.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/datasources/local/nutrition_log_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/local/pending_sync_delete_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/nutrition_log_remote_datasource.dart';
import 'package:fitness_tracker/data/sync/nutrition_log_sync_coordinator_impl.dart';
import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/pending_sync_delete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionLogLocalDataSource extends Mock
    implements NutritionLogLocalDataSource {}

class MockNutritionLogRemoteDataSource extends Mock
    implements NutritionLogRemoteDataSource {}

class MockPendingSyncDeleteLocalDataSource extends Mock
    implements PendingSyncDeleteLocalDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      NutritionLogModel(
        id: 'fallback-id',
        mealName: 'Fallback Log',
        proteinGrams: 25,
        carbsGrams: 30,
        fatGrams: 10,
        calories: 310,
        loggedAt: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
    registerFallbackValue(
      PendingSyncDelete(
        id: 'fallback-delete',
        entityType: SyncEntityType.nutritionLog,
        localEntityId: 'fallback-local-id',
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockNutritionLogLocalDataSource localDataSource;
  late MockNutritionLogRemoteDataSource remoteDataSource;
  late MockPendingSyncDeleteLocalDataSource pendingDeleteDataSource;
  late NutritionLogSyncCoordinatorImpl coordinator;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  NutritionLogModel buildLog({
    required String id,
    SyncStatus status = SyncStatus.synced,
    String? serverId = 'server-1',
  }) {
    return NutritionLogModel(
      id: id,
      mealId: 'meal-1',
      mealName: 'Chicken Bowl',
      gramsConsumed: 100,
      proteinGrams: 25,
      carbsGrams: 30,
      fatGrams: 10,
      calories: 310,
      loggedAt: baseDate,
      createdAt: baseDate,
      updatedAt: baseDate,
      syncMetadata: EntitySyncMetadata(status: status, serverId: serverId),
    );
  }

  setUp(() {
    localDataSource = MockNutritionLogLocalDataSource();
    remoteDataSource = MockNutritionLogRemoteDataSource();
    pendingDeleteDataSource = MockPendingSyncDeleteLocalDataSource();

    coordinator = NutritionLogSyncCoordinatorImpl(
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
      verifyNever(() => remoteDataSource.upsertLog(any()));
    },
  );

  test(
    'delete marks synced row as pending delete before remote delete',
    () async {
      final NutritionLogModel existing = buildLog(id: 'log-1');

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getLogById('log-1'),
      ).thenAnswer((_) async => existing);
      when(
        () => pendingDeleteDataSource.enqueue(any()),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.markAsPendingDelete('log-1'),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.getPendingByEntityType(
          SyncEntityType.nutritionLog,
        ),
      ).thenAnswer(
        (_) async => <PendingSyncDelete>[
          PendingSyncDelete(
            id: 'delete-1',
            entityType: SyncEntityType.nutritionLog,
            localEntityId: 'log-1',
            serverEntityId: 'server-1',
            createdAt: DateTime.now(),
          ),
        ],
      );
      when(
        () =>
            remoteDataSource.deleteLog(localId: 'log-1', serverId: 'server-1'),
      ).thenAnswer((_) async {});
      when(
        () => pendingDeleteDataSource.remove('delete-1'),
      ).thenAnswer((_) async {});
      when(() => localDataSource.deleteLog('log-1')).thenAnswer((_) async {});

      await coordinator.persistDeletedLog('log-1');

      verify(() => localDataSource.markAsPendingDelete('log-1')).called(1);
      verify(
        () =>
            remoteDataSource.deleteLog(localId: 'log-1', serverId: 'server-1'),
      ).called(1);
      verify(() => localDataSource.deleteLog('log-1')).called(1);
    },
  );

  test('delete removes purely local row immediately', () async {
    final NutritionLogModel existing = buildLog(
      id: 'log-1',
      status: SyncStatus.localOnly,
      serverId: null,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(
      () => localDataSource.getLogById('log-1'),
    ).thenAnswer((_) async => existing);
    when(() => localDataSource.deleteLog('log-1')).thenAnswer((_) async {});

    await coordinator.persistDeletedLog('log-1');

    verifyNever(() => localDataSource.markAsPendingDelete(any()));
    verify(() => localDataSource.deleteLog('log-1')).called(1);
  });

  test('failed remote delete keeps queued delete for retry', () async {
    final NutritionLogModel existing = buildLog(id: 'log-1');

    when(() => remoteDataSource.isConfigured).thenReturn(true);
    when(
      () => localDataSource.getLogById('log-1'),
    ).thenAnswer((_) async => existing);
    when(() => pendingDeleteDataSource.enqueue(any())).thenAnswer((_) async {});
    when(
      () => localDataSource.markAsPendingDelete('log-1'),
    ).thenAnswer((_) async {});
    when(
      () => pendingDeleteDataSource.getPendingByEntityType(
        SyncEntityType.nutritionLog,
      ),
    ).thenAnswer(
      (_) async => <PendingSyncDelete>[
        PendingSyncDelete(
          id: 'delete-1',
          entityType: SyncEntityType.nutritionLog,
          localEntityId: 'log-1',
          serverEntityId: 'server-1',
          createdAt: DateTime.now(),
        ),
      ],
    );
    when(
      () => remoteDataSource.deleteLog(localId: 'log-1', serverId: 'server-1'),
    ).thenThrow(StateError('network'));
    when(
      () => pendingDeleteDataSource.markAttempted(
        'delete-1',
        attemptedAt: any(named: 'attemptedAt'),
        errorMessage: 'Bad state: network',
      ),
    ).thenAnswer((_) async {});

    await coordinator.persistDeletedLog('log-1');

    verify(() => localDataSource.markAsPendingDelete('log-1')).called(1);
    verifyNever(() => localDataSource.deleteLog('log-1'));
    verify(
      () => pendingDeleteDataSource.markAttempted(
        'delete-1',
        attemptedAt: any(named: 'attemptedAt'),
        errorMessage: 'Bad state: network',
      ),
    ).called(1);
  });

  // ---------------------------------------------------------------------------
  // Sync metadata stamping (user-owned only — guest-owner guard removed)
  // ---------------------------------------------------------------------------

  group('sync metadata', () {
    NutritionLog buildLogEntity({String? ownerUserId}) => NutritionLog(
      id: 'log-1',
      ownerUserId: ownerUserId,
      mealName: 'Chicken Bowl',
      proteinGrams: 25,
      carbsGrams: 30,
      fatGrams: 10,
      calories: 310,
      loggedAt: baseDate,
      createdAt: baseDate,
    );

    test(
      'buildAddedLocalEntity stamps authenticated-user log as pendingUpload',
      () {
        when(() => remoteDataSource.isConfigured).thenReturn(true);

        final result = coordinator.buildAddedLocalEntity(
          buildLogEntity(ownerUserId: 'user-1'),
          baseDate,
        );

        expect(result.syncMetadata.status, SyncStatus.pendingUpload);
      },
    );
  });
}
