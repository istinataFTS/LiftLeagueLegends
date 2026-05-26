import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/nutrition_log_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/nutrition_log_remote_datasource.dart';
import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
import 'package:fitness_tracker/data/repositories/nutrition_log_repository_impl.dart';
import 'package:fitness_tracker/data/sync/nutrition_log_sync_coordinator.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/repositories/nutrition_log_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionLogLocalDataSource extends Mock
    implements NutritionLogLocalDataSource {}

class MockNutritionLogRemoteDataSource extends Mock
    implements NutritionLogRemoteDataSource {}

class MockNutritionLogSyncCoordinator extends Mock
    implements NutritionLogSyncCoordinator {}

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
      NutritionLog(
        id: 'fallback-log-id',
        mealName: 'Fallback Log Entity',
        proteinGrams: 25,
        carbsGrams: 30,
        fatGrams: 10,
        calories: 310,
        loggedAt: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockNutritionLogLocalDataSource localDataSource;
  late MockNutritionLogRemoteDataSource remoteDataSource;
  late MockNutritionLogSyncCoordinator syncCoordinator;
  late NutritionLogRepositoryImpl repository;

  final DateTime targetDate = DateTime(2026, 3, 21, 12, 0);

  NutritionLogModel buildLogModel({
    required String id,
    required DateTime loggedAt,
    String? mealId,
    String mealName = 'Chicken Bowl',
    double? gramsConsumed = 100,
    double protein = 25,
    double carbs = 30,
    double fat = 10,
    double calories = 310,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return NutritionLogModel(
      id: id,
      mealId: mealId,
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      updatedAt: updatedAt ?? loggedAt,
      syncMetadata: syncMetadata,
    );
  }

  NutritionLog buildLogEntity({
    required String id,
    required DateTime loggedAt,
    String? mealId,
    String mealName = 'Chicken Bowl',
    double? gramsConsumed = 100,
    double protein = 25,
    double carbs = 30,
    double fat = 10,
    double calories = 310,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return NutritionLog(
      id: id,
      mealId: mealId,
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      updatedAt: updatedAt ?? loggedAt,
      syncMetadata: syncMetadata,
    );
  }

  setUp(() {
    localDataSource = MockNutritionLogLocalDataSource();
    remoteDataSource = MockNutritionLogRemoteDataSource();
    syncCoordinator = MockNutritionLogSyncCoordinator();

    repository = NutritionLogRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncCoordinator: syncCoordinator,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(() => syncCoordinator.isRemoteSyncEnabled).thenReturn(false);
  });

  group('NutritionLogRepositoryImpl.getAllLogs', () {
    test('returns local logs for localOnly without touching remote', () async {
      final List<NutritionLogModel> localLogs = <NutritionLogModel>[
        buildLogModel(id: '1', loggedAt: targetDate),
      ];

      when(
        () => localDataSource.getAllLogs(),
      ).thenAnswer((_) async => localLogs);

      final Either<Failure, List<NutritionLog>> result = await repository
          .getAllLogs();

      expect(result, Right<Failure, List<NutritionLog>>(localLogs));
      verify(() => localDataSource.getAllLogs()).called(1);
      verifyNever(() => remoteDataSource.getAllLogs());
      verifyNever(() => localDataSource.mergeRemoteLogs(any()));
    });

    test('remoteThenLocal merges cache instead of replaceAll and preserves '
        'pending local update', () async {
      final NutritionLogModel localPendingLog = buildLogModel(
        id: '1',
        loggedAt: targetDate,
        calories: 330,
        updatedAt: targetDate.add(const Duration(minutes: 30)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final NutritionLog remoteLog = buildLogEntity(
        id: '1',
        loggedAt: targetDate,
        calories: 500,
        updatedAt: targetDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final NutritionLog remoteOnlyLog = buildLogEntity(
        id: '2',
        loggedAt: targetDate.add(const Duration(hours: 2)),
        calories: 420,
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final List<NutritionLogModel> mergedLogs = <NutritionLogModel>[
        localPendingLog,
        NutritionLogModel.fromEntity(remoteOnlyLog),
      ];

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getAllLogs(),
      ).thenAnswer((_) async => <NutritionLogModel>[localPendingLog]);
      when(
        () => remoteDataSource.getAllLogs(),
      ).thenAnswer((_) async => <NutritionLog>[remoteLog, remoteOnlyLog]);
      when(
        () => localDataSource.mergeRemoteLogs(any()),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.getAllLogs(),
      ).thenAnswer((_) async => mergedLogs);

      final Either<Failure, List<NutritionLog>> result = await repository
          .getAllLogs(sourcePreference: DataSourcePreference.remoteThenLocal);

      expect(result, Right<Failure, List<NutritionLog>>(mergedLogs));
      verify(() => remoteDataSource.getAllLogs()).called(1);
      verify(() => localDataSource.mergeRemoteLogs(any())).called(1);
      verifyNever(() => localDataSource.replaceAllLogs(any()));
    });
  });

  group('NutritionLogRepositoryImpl.getLogById', () {
    test('falls back to local when remoteThenLocal returns null', () async {
      final NutritionLogModel localLog = buildLogModel(
        id: 'log-1',
        loggedAt: targetDate,
      );

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getLogById('log-1'),
      ).thenAnswer((_) async => localLog);
      when(
        () => remoteDataSource.getLogById('log-1'),
      ).thenAnswer((_) async => null);

      final Either<Failure, NutritionLog?> result = await repository.getLogById(
        'log-1',
        sourcePreference: DataSourcePreference.remoteThenLocal,
      );

      expect(result, Right<Failure, NutritionLog?>(localLog));
      verify(() => remoteDataSource.getLogById('log-1')).called(1);
      verify(() => localDataSource.getLogById('log-1')).called(1);
      verifyNever(() => localDataSource.upsertLog(any()));
    });

    test('returns local cache snapshot after localThenRemote upsert', () async {
      final NutritionLog remoteLog = buildLogEntity(
        id: 'log-1',
        loggedAt: targetDate,
        calories: 420,
      );

      final NutritionLogModel cachedLog = buildLogModel(
        id: 'log-1',
        loggedAt: targetDate,
        calories: 420,
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getLogById('log-1')).thenAnswer((_) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : cachedLog;
      });
      when(
        () => remoteDataSource.getLogById('log-1'),
      ).thenAnswer((_) async => remoteLog);
      when(() => localDataSource.upsertLog(any())).thenAnswer((_) async {});

      final Either<Failure, NutritionLog?> result = await repository.getLogById(
        'log-1',
        sourcePreference: DataSourcePreference.localThenRemote,
      );

      expect(result, Right<Failure, NutritionLog?>(cachedLog));
      verify(() => localDataSource.getLogById('log-1')).called(2);
      verify(() => localDataSource.upsertLog(any())).called(1);
    });

    test(
      'preserves pending local update during remoteThenLocal merge',
      () async {
        final NutritionLogModel localPendingLog = buildLogModel(
          id: 'log-1',
          loggedAt: targetDate,
          calories: 330,
          updatedAt: targetDate.add(const Duration(minutes: 30)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        );

        final NutritionLog remoteLog = buildLogEntity(
          id: 'log-1',
          loggedAt: targetDate,
          calories: 500,
          updatedAt: targetDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getLogById('log-1'),
        ).thenAnswer((_) async => localPendingLog);
        when(
          () => remoteDataSource.getLogById('log-1'),
        ).thenAnswer((_) async => remoteLog);
        when(
          () => localDataSource.upsertLog(localPendingLog),
        ).thenAnswer((_) async {});

        final Either<Failure, NutritionLog?> result = await repository
            .getLogById(
              'log-1',
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        expect(result, Right<Failure, NutritionLog?>(localPendingLog));
        verify(() => localDataSource.upsertLog(localPendingLog)).called(1);
      },
    );

    test(
      'returns null when hidden pending delete remains after remote refresh',
      () async {
        final NutritionLog remoteLog = buildLogEntity(
          id: 'log-1',
          loggedAt: targetDate,
          calories: 420,
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getLogById('log-1'),
        ).thenAnswer((_) async => null);
        when(
          () => remoteDataSource.getLogById('log-1'),
        ).thenAnswer((_) async => remoteLog);
        when(() => localDataSource.upsertLog(any())).thenAnswer((_) async {});

        final Either<Failure, NutritionLog?> result = await repository
            .getLogById(
              'log-1',
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        expect(result, const Right<Failure, NutritionLog?>(null));
        verify(() => localDataSource.getLogById('log-1')).called(2);
        verify(() => localDataSource.upsertLog(any())).called(1);
      },
    );
  });

  group('NutritionLogRepositoryImpl.getDailyMacros', () {
    test(
      'returns local datasource macros when remote is not configured',
      () async {
        when(() => remoteDataSource.isConfigured).thenReturn(false);
        when(() => localDataSource.getDailyMacros(targetDate)).thenAnswer(
          (_) async => <String, double>{
            'totalCarbs': 80,
            'totalProtein': 60,
            'totalFat': 20,
            'totalCalories': 740,
            'logsCount': 2,
          },
        );

        final Either<Failure, DailyMacros> result = await repository
            .getDailyMacros(
              targetDate,
              sourcePreference: DataSourcePreference.remoteThenLocal,
            );

        result.fold((_) => fail('expected Right result'), (DailyMacros macros) {
          expect(macros.totalCarbs, 80);
          expect(macros.totalProtein, 60);
          expect(macros.totalFat, 20);
          expect(macros.totalCalories, 740);
          expect(macros.logsCount, 2);
          expect(macros.date, targetDate);
        });

        verify(() => localDataSource.getDailyMacros(targetDate)).called(1);
        verifyNever(() => remoteDataSource.getLogsByDate(any()));
      },
    );

    test('aggregates logs into daily macros via repository path', () async {
      final List<NutritionLog> mergedLogs = <NutritionLog>[
        buildLogEntity(
          id: '1',
          loggedAt: targetDate,
          protein: 25,
          carbs: 40,
          fat: 10,
          calories: 350,
        ),
        buildLogEntity(
          id: '2',
          loggedAt: targetDate.add(const Duration(hours: 3)),
          protein: 35,
          carbs: 20,
          fat: 15,
          calories: 355,
        ),
      ];

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getAllLogs(),
      ).thenAnswer((_) async => const <NutritionLogModel>[]);
      when(
        () => remoteDataSource.getAllLogs(),
      ).thenAnswer((_) async => mergedLogs);
      when(
        () => localDataSource.mergeRemoteLogs(any()),
      ).thenAnswer((_) async {});
      when(() => localDataSource.getAllLogs()).thenAnswer(
        (_) async => mergedLogs.map(NutritionLogModel.fromEntity).toList(),
      );

      final Either<Failure, DailyMacros> result = await repository
          .getDailyMacros(
            targetDate,
            sourcePreference: DataSourcePreference.remoteThenLocal,
          );

      result.fold((_) => fail('expected Right result'), (DailyMacros macros) {
        expect(macros.totalProtein, 60);
        expect(macros.totalCarbs, 60);
        expect(macros.totalFat, 25);
        expect(macros.totalCalories, 705);
        expect(macros.logsCount, 2);
        expect(macros.date, targetDate);
      });
    });
  });

  group('NutritionLogRepositoryImpl deletes and writes', () {
    test('deleteLogsByDate delegates each matching log deletion to sync '
        'coordinator', () async {
      final List<NutritionLogModel> dateLogs = <NutritionLogModel>[
        buildLogModel(id: 'log-1', loggedAt: targetDate),
        buildLogModel(
          id: 'log-2',
          loggedAt: targetDate.add(const Duration(hours: 2)),
        ),
      ];

      when(
        () => localDataSource.getLogsByDate(targetDate),
      ).thenAnswer((_) async => dateLogs);
      when(
        () => syncCoordinator.persistDeletedLog(any()),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.deleteLogsByDate(
        targetDate,
      );

      expect(result.isRight(), isTrue);
      verify(() => localDataSource.getLogsByDate(targetDate)).called(1);
      verify(() => syncCoordinator.persistDeletedLog('log-1')).called(1);
      verify(() => syncCoordinator.persistDeletedLog('log-2')).called(1);
    });

    test('addLog delegates to sync coordinator', () async {
      final NutritionLog log = buildLogEntity(
        id: 'log-1',
        loggedAt: targetDate,
      );

      when(() => syncCoordinator.persistAddedLog(log)).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.addLog(log);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistAddedLog(log)).called(1);
    });

    test('updateLog delegates to sync coordinator', () async {
      final NutritionLog log = buildLogEntity(
        id: 'log-1',
        loggedAt: targetDate,
        calories: 420,
      );

      when(
        () => syncCoordinator.persistUpdatedLog(log),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.updateLog(log);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistUpdatedLog(log)).called(1);
    });

    test('deleteLog delegates to sync coordinator', () async {
      when(
        () => syncCoordinator.persistDeletedLog('log-1'),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.deleteLog('log-1');

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistDeletedLog('log-1')).called(1);
    });
  });
}
