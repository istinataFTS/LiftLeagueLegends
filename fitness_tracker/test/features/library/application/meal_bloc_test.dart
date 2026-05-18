import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/usecases/meals/add_meal.dart';
import 'package:fitness_tracker/domain/usecases/meals/delete_meal.dart';
import 'package:fitness_tracker/domain/usecases/meals/ensure_default_meals.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_all_meals.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_meal_by_id.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_meal_by_name.dart';
import 'package:fitness_tracker/domain/usecases/meals/update_meal.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAllMeals extends Mock implements GetAllMeals {}

class MockGetMealById extends Mock implements GetMealById {}

class MockGetMealByName extends Mock implements GetMealByName {}

class MockAddMeal extends Mock implements AddMeal {}

class MockUpdateMeal extends Mock implements UpdateMeal {}

class MockDeleteMeal extends Mock implements DeleteMeal {}

class MockEnsureDefaultMeals extends Mock implements EnsureDefaultMeals {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _meal = Meal(
  id: 'meal-1',
  name: 'Oats',
  servingSizeGrams: 100,
  carbsPer100g: 60,
  proteinPer100g: 13,
  fatPer100g: 7,
  caloriesPer100g: 380,
  createdAt: DateTime(2026),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockGetAllMeals mockGetAll;
  late MockGetMealById mockGetById;
  late MockGetMealByName mockGetByName;
  late MockAddMeal mockAdd;
  late MockUpdateMeal mockUpdate;
  late MockDeleteMeal mockDelete;
  late MockEnsureDefaultMeals mockEnsureDefaults;

  MealBloc buildBloc() => MealBloc(
    getAllMeals: mockGetAll,
    getMealById: mockGetById,
    getMealByName: mockGetByName,
    addMeal: mockAdd,
    updateMeal: mockUpdate,
    deleteMeal: mockDelete,
    ensureDefaultMeals: mockEnsureDefaults,
  );

  setUpAll(() {
    registerFallbackValue(_meal);
  });

  setUp(() {
    mockGetAll = MockGetAllMeals();
    mockGetById = MockGetMealById();
    mockGetByName = MockGetMealByName();
    mockAdd = MockAddMeal();
    mockUpdate = MockUpdateMeal();
    mockDelete = MockDeleteMeal();
    mockEnsureDefaults = MockEnsureDefaultMeals();
  });

  group('MealBloc', () {
    group('LoadMealsEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [Loading, MealsLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(() => mockGetAll()).thenAnswer((_) async => Right([_meal]));
        },
        act: (bloc) => bloc.add(LoadMealsEvent()),
        expect: () => [
          isA<MealLoading>(),
          MealsLoaded([_meal]),
        ],
      );

      blocTest<MealBloc, MealState>(
        'empty catalog triggers default seeding then reloads',
        build: buildBloc,
        setUp: () {
          final responses = <Either<Failure, List<Meal>>>[
            const Right(<Meal>[]),
            Right([_meal]),
          ];
          when(
            () => mockGetAll(),
          ).thenAnswer((_) async => responses.removeAt(0));
          when(
            () => mockEnsureDefaults(),
          ).thenAnswer((_) async => const Right(50));
        },
        act: (bloc) => bloc.add(LoadMealsEvent()),
        expect: () => [
          isA<MealLoading>(),
          MealsLoaded([_meal]),
        ],
        verify: (_) {
          verify(() => mockEnsureDefaults()).called(1);
        },
      );

      blocTest<MealBloc, MealState>(
        'emits [Loading, MealError] on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetAll(),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(LoadMealsEvent()),
        expect: () => [isA<MealLoading>(), const MealError('db error')],
      );
    });

    group('LoadMealByIdEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [Loading, MealLoaded] when meal is found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('meal-1'),
          ).thenAnswer((_) async => Right(_meal));
        },
        act: (bloc) => bloc.add(const LoadMealByIdEvent('meal-1')),
        expect: () => [isA<MealLoading>(), MealLoaded(_meal)],
      );

      blocTest<MealBloc, MealState>(
        'emits [Loading, MealError] when meal is not found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('meal-1'),
          ).thenAnswer((_) async => const Right(null));
        },
        act: (bloc) => bloc.add(const LoadMealByIdEvent('meal-1')),
        expect: () => [isA<MealLoading>(), const MealError('Meal not found')],
      );

      blocTest<MealBloc, MealState>(
        'emits [Loading, MealError] on repository failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('meal-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const LoadMealByIdEvent('meal-1')),
        expect: () => [isA<MealLoading>(), const MealError('db error')],
      );
    });

    group('LoadMealByNameEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [Loading, MealLoaded] when meal is found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetByName('Oats'),
          ).thenAnswer((_) async => Right(_meal));
        },
        act: (bloc) => bloc.add(const LoadMealByNameEvent('Oats')),
        expect: () => [isA<MealLoading>(), MealLoaded(_meal)],
      );

      blocTest<MealBloc, MealState>(
        'emits [Loading, MealError] when meal name is not found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetByName('Oats'),
          ).thenAnswer((_) async => const Right(null));
        },
        act: (bloc) => bloc.add(const LoadMealByNameEvent('Oats')),
        expect: () => [isA<MealLoading>(), const MealError('Meal not found')],
      );
    });

    group('AddMealEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [OperationSuccess, Loading, MealsLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(() => mockAdd(_meal)).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_meal]));
        },
        act: (bloc) => bloc.add(AddMealEvent(_meal)),
        expect: () => [
          const MealOperationSuccess('Meal added successfully'),
          isA<MealLoading>(),
          MealsLoaded([_meal]),
        ],
      );

      blocTest<MealBloc, MealState>(
        'emits [MealError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockAdd(_meal),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(AddMealEvent(_meal)),
        expect: () => [const MealError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });

    group('UpdateMealEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [OperationSuccess, Loading, MealsLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_meal),
          ).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_meal]));
        },
        act: (bloc) => bloc.add(UpdateMealEvent(_meal)),
        expect: () => [
          const MealOperationSuccess('Meal updated successfully'),
          isA<MealLoading>(),
          MealsLoaded([_meal]),
        ],
      );

      blocTest<MealBloc, MealState>(
        'emits [MealError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_meal),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(UpdateMealEvent(_meal)),
        expect: () => [const MealError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });

    group('DeleteMealEvent', () {
      blocTest<MealBloc, MealState>(
        'emits [OperationSuccess, Loading, MealsLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('meal-1'),
          ).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_meal]));
        },
        act: (bloc) => bloc.add(const DeleteMealEvent('meal-1')),
        expect: () => [
          const MealOperationSuccess('Meal deleted successfully'),
          isA<MealLoading>(),
          MealsLoaded([_meal]),
        ],
      );

      blocTest<MealBloc, MealState>(
        'emits [MealError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('meal-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const DeleteMealEvent('meal-1')),
        expect: () => [const MealError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });
  });
}
