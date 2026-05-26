import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/meal_local_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/meal_remote_datasource.dart';
import 'package:fitness_tracker/data/models/meal_model.dart';
import 'package:fitness_tracker/data/repositories/meal_repository_impl.dart';
import 'package:fitness_tracker/data/sync/meal_sync_coordinator.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMealLocalDataSource extends Mock implements MealLocalDataSource {}

class MockMealRemoteDataSource extends Mock implements MealRemoteDataSource {}

class MockMealSyncCoordinator extends Mock implements MealSyncCoordinator {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      MealModel(
        id: 'fallback-id',
        name: 'Fallback Meal',
        servingSizeGrams: 100,
        proteinPer100g: 20,
        carbsPer100g: 30,
        fatPer100g: 10,
        caloriesPer100g: 290,
        createdAt: DateTime(2026),
      ),
    );
    registerFallbackValue(
      Meal(
        id: 'fallback-meal-id',
        name: 'Fallback Meal Entity',
        servingSizeGrams: 100,
        proteinPer100g: 20,
        carbsPer100g: 30,
        fatPer100g: 10,
        caloriesPer100g: 290,
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockMealLocalDataSource localDataSource;
  late MockMealRemoteDataSource remoteDataSource;
  late MockMealSyncCoordinator syncCoordinator;
  late MealRepositoryImpl repository;

  final DateTime createdAt = DateTime(2026, 3, 20, 10, 0);

  MealModel buildMealModel({
    required String id,
    required String name,
    double servingSizeGrams = 100,
    double proteinPer100g = 20,
    double carbsPer100g = 30,
    double fatPer100g = 10,
    double caloriesPer100g = 290,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return MealModel(
      id: id,
      name: name,
      servingSizeGrams: servingSizeGrams,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      caloriesPer100g: caloriesPer100g,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      syncMetadata: syncMetadata,
    );
  }

  Meal buildMealEntity({
    required String id,
    required String name,
    double servingSizeGrams = 100,
    double proteinPer100g = 20,
    double carbsPer100g = 30,
    double fatPer100g = 10,
    double caloriesPer100g = 290,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return Meal(
      id: id,
      name: name,
      servingSizeGrams: servingSizeGrams,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      caloriesPer100g: caloriesPer100g,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      syncMetadata: syncMetadata,
    );
  }

  setUp(() {
    localDataSource = MockMealLocalDataSource();
    remoteDataSource = MockMealRemoteDataSource();
    syncCoordinator = MockMealSyncCoordinator();

    repository = MealRepositoryImpl(
      localDataSource: localDataSource,
      remoteDataSource: remoteDataSource,
      syncCoordinator: syncCoordinator,
    );

    when(() => remoteDataSource.isConfigured).thenReturn(false);
    when(() => syncCoordinator.isRemoteSyncEnabled).thenReturn(false);
  });

  group('MealRepositoryImpl.getAllMeals', () {
    test('returns local meals for localOnly without touching remote', () async {
      final List<MealModel> localMeals = <MealModel>[
        buildMealModel(id: '1', name: 'Chicken Bowl'),
      ];

      when(
        () => localDataSource.getAllMeals(),
      ).thenAnswer((_) async => localMeals);

      final Either<Failure, List<Meal>> result = await repository.getAllMeals();

      expect(result, Right<Failure, List<Meal>>(localMeals));
      verify(() => localDataSource.getAllMeals()).called(1);
      verifyNever(() => remoteDataSource.getAllMeals());
      verifyNever(() => localDataSource.mergeRemoteMeals(any()));
    });

    test(
      'returns empty list for remoteOnly when remote is not configured',
      () async {
        when(() => remoteDataSource.isConfigured).thenReturn(false);

        final Either<Failure, List<Meal>> result = await repository.getAllMeals(
          sourcePreference: DataSourcePreference.remoteOnly,
        );

        expect(result, const Right(<Meal>[]));
        verifyNever(() => remoteDataSource.getAllMeals());
        verifyNever(() => localDataSource.getAllMeals());
      },
    );

    test(
      'returns local data first for localThenRemote when local has items',
      () async {
        final List<MealModel> localMeals = <MealModel>[
          buildMealModel(id: '1', name: 'Oats'),
        ];

        when(
          () => localDataSource.getAllMeals(),
        ).thenAnswer((_) async => localMeals);
        when(() => remoteDataSource.isConfigured).thenReturn(true);

        final Either<Failure, List<Meal>> result = await repository.getAllMeals(
          sourcePreference: DataSourcePreference.localThenRemote,
        );

        expect(result, Right<Failure, List<Meal>>(localMeals));
        verify(() => localDataSource.getAllMeals()).called(1);
        verifyNever(() => remoteDataSource.getAllMeals());
        verifyNever(() => localDataSource.mergeRemoteMeals(any()));
      },
    );

    test('remoteThenLocal merges cache instead of replaceAll and preserves '
        'pending local update', () async {
      final MealModel localPendingMeal = buildMealModel(
        id: 'meal-1',
        name: 'Local Edited Bowl',
        updatedAt: createdAt.add(const Duration(hours: 2)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final Meal remoteMeal = buildMealEntity(
        id: 'meal-1',
        name: 'Remote Bowl',
        updatedAt: createdAt.add(const Duration(hours: 3)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final Meal remoteOnlyMeal = buildMealEntity(
        id: 'meal-2',
        name: 'Greek Yogurt',
        updatedAt: createdAt.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      final List<MealModel> mergedMeals = <MealModel>[
        localPendingMeal,
        MealModel.fromEntity(remoteOnlyMeal),
      ];

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(
        () => localDataSource.getAllMeals(),
      ).thenAnswer((_) async => <MealModel>[localPendingMeal]);
      when(
        () => remoteDataSource.getAllMeals(),
      ).thenAnswer((_) async => <Meal>[remoteMeal, remoteOnlyMeal]);
      when(
        () => localDataSource.mergeRemoteMeals(any()),
      ).thenAnswer((_) async {});
      when(
        () => localDataSource.getAllMeals(),
      ).thenAnswer((_) async => mergedMeals);

      final Either<Failure, List<Meal>> result = await repository.getAllMeals(
        sourcePreference: DataSourcePreference.remoteThenLocal,
      );

      expect(result, Right<Failure, List<Meal>>(mergedMeals));
      verify(() => remoteDataSource.getAllMeals()).called(1);
      verify(() => localDataSource.mergeRemoteMeals(any())).called(1);
      verifyNever(() => localDataSource.replaceAllMeals(any()));
    });
  });

  group('MealRepositoryImpl.getMealById', () {
    test(
      'falls back to local for remoteThenLocal when remote returns null',
      () async {
        final MealModel localMeal = buildMealModel(id: 'meal-1', name: 'Oats');

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => localMeal);
        when(
          () => remoteDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => null);

        final Either<Failure, Meal?> result = await repository.getMealById(
          'meal-1',
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, Meal?>(localMeal));
        verify(() => remoteDataSource.getMealById('meal-1')).called(1);
        verify(() => localDataSource.getMealById('meal-1')).called(1);
        verifyNever(() => localDataSource.upsertMeal(any()));
      },
    );

    test('returns local cache snapshot after localThenRemote upsert', () async {
      final Meal remoteMeal = buildMealEntity(
        id: 'meal-1',
        name: 'Chicken Bowl',
      );

      final MealModel cachedMeal = buildMealModel(
        id: 'meal-1',
        name: 'Chicken Bowl',
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getMealById('meal-1')).thenAnswer((_) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : cachedMeal;
      });
      when(
        () => remoteDataSource.getMealById('meal-1'),
      ).thenAnswer((_) async => remoteMeal);
      when(() => localDataSource.upsertMeal(any())).thenAnswer((_) async {});

      final Either<Failure, Meal?> result = await repository.getMealById(
        'meal-1',
        sourcePreference: DataSourcePreference.localThenRemote,
      );

      expect(result, Right<Failure, Meal?>(cachedMeal));
      verify(() => localDataSource.getMealById('meal-1')).called(2);
      verify(() => localDataSource.upsertMeal(any())).called(1);
    });

    test(
      'preserves pending local update over remote during remoteThenLocal',
      () async {
        final MealModel localPendingMeal = buildMealModel(
          id: 'meal-1',
          name: 'Local Edited Bowl',
          updatedAt: createdAt.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        );

        final Meal remoteMeal = buildMealEntity(
          id: 'meal-1',
          name: 'Remote Updated Bowl',
          updatedAt: createdAt.add(const Duration(hours: 2)),
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => localPendingMeal);
        when(
          () => remoteDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => remoteMeal);
        when(
          () => localDataSource.upsertMeal(localPendingMeal),
        ).thenAnswer((_) async {});

        final Either<Failure, Meal?> result = await repository.getMealById(
          'meal-1',
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, Right<Failure, Meal?>(localPendingMeal));
        verify(() => localDataSource.upsertMeal(localPendingMeal)).called(1);
      },
    );

    test(
      'returns null when hidden pending delete remains after remote refresh',
      () async {
        final Meal remoteMeal = buildMealEntity(
          id: 'meal-1',
          name: 'Chicken Bowl',
        );

        when(() => remoteDataSource.isConfigured).thenReturn(true);
        when(
          () => localDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => null);
        when(
          () => remoteDataSource.getMealById('meal-1'),
        ).thenAnswer((_) async => remoteMeal);
        when(() => localDataSource.upsertMeal(any())).thenAnswer((_) async {});

        final Either<Failure, Meal?> result = await repository.getMealById(
          'meal-1',
          sourcePreference: DataSourcePreference.remoteThenLocal,
        );

        expect(result, const Right<Failure, Meal?>(null));
        verify(() => localDataSource.getMealById('meal-1')).called(2);
        verify(() => localDataSource.upsertMeal(any())).called(1);
      },
    );
  });

  group('MealRepositoryImpl.getMealByName', () {
    test('returns local cache snapshot after localThenRemote upsert', () async {
      final Meal remoteMeal = buildMealEntity(
        id: 'meal-1',
        name: 'Chicken Bowl',
      );

      final MealModel cachedMeal = buildMealModel(
        id: 'meal-1',
        name: 'Chicken Bowl',
      );

      int localReadCount = 0;

      when(() => remoteDataSource.isConfigured).thenReturn(true);
      when(() => localDataSource.getMealByName('Chicken Bowl')).thenAnswer((
        _,
      ) async {
        localReadCount += 1;
        return localReadCount == 1 ? null : cachedMeal;
      });
      when(
        () => remoteDataSource.getMealByName('Chicken Bowl'),
      ).thenAnswer((_) async => remoteMeal);
      when(() => localDataSource.upsertMeal(any())).thenAnswer((_) async {});

      final Either<Failure, Meal?> result = await repository.getMealByName(
        'Chicken Bowl',
        sourcePreference: DataSourcePreference.localThenRemote,
      );

      expect(result, Right<Failure, Meal?>(cachedMeal));
      verify(() => localDataSource.getMealByName('Chicken Bowl')).called(2);
      verify(() => localDataSource.upsertMeal(any())).called(1);
    });
  });

  group('MealRepositoryImpl writes', () {
    test('addMeal delegates to sync coordinator', () async {
      final Meal meal = buildMealEntity(id: 'meal-1', name: 'Chicken Bowl');

      when(
        () => syncCoordinator.persistAddedMeal(meal),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.addMeal(meal);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistAddedMeal(meal)).called(1);
    });

    test('updateMeal delegates to sync coordinator', () async {
      final Meal meal = buildMealEntity(id: 'meal-1', name: 'Updated Bowl');

      when(
        () => syncCoordinator.persistUpdatedMeal(meal),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.updateMeal(meal);

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistUpdatedMeal(meal)).called(1);
    });

    test('deleteMeal delegates to sync coordinator', () async {
      when(
        () => syncCoordinator.persistDeletedMeal('meal-1'),
      ).thenAnswer((_) async {});

      final Either<Failure, void> result = await repository.deleteMeal(
        'meal-1',
      );

      expect(result.isRight(), isTrue);
      verify(() => syncCoordinator.persistDeletedMeal('meal-1')).called(1);
    });
  });
}
