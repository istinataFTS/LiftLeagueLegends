import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/meal_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/meals/add_meal.dart';
import 'package:fitness_tracker/domain/usecases/meals/delete_meal.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_all_meals.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_meal_by_id.dart';
import 'package:fitness_tracker/domain/usecases/meals/get_meal_by_name.dart';
import 'package:fitness_tracker/domain/usecases/meals/update_meal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMealRepository extends Mock implements MealRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _mealFixture = Meal(
  id: 'meal-1',
  name: 'Chicken Rice',
  servingSizeGrams: 200,
  carbsPer100g: 30,
  proteinPer100g: 25,
  fatPer100g: 5,
  caloriesPer100g: 265,
  createdAt: DateTime(2026),
);

const _authenticatedSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockMealRepository mockMealRepo;
  late MockAppSessionRepository mockSessionRepo;
  late MockAuthenticatedDataSourcePreferenceResolver mockResolver;

  setUpAll(() {
    registerFallbackValue(_mealFixture);
  });

  setUp(() {
    mockMealRepo = MockMealRepository();
    mockSessionRepo = MockAppSessionRepository();
    mockResolver = MockAuthenticatedDataSourcePreferenceResolver();
  });

  // ---------------------------------------------------------------------------
  // AddMeal
  // ---------------------------------------------------------------------------

  group('AddMeal', () {
    late AddMeal useCase;

    setUp(() {
      useCase = AddMeal(mockMealRepo, appSessionRepository: mockSessionRepo);
    });

    // "does not set ownerUserId when session fails" removed: AddMeal now
    // propagates the session failure instead of using a guest fallback.

    test('sets ownerUserId when session is authenticated', () async {
      final mealWithOwner = _mealFixture.copyWith(ownerUserId: 'user-1');

      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockMealRepo.addMeal(mealWithOwner),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_mealFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockMealRepo.addMeal(mealWithOwner)).called(1);
    });

    // "does not set ownerUserId for unauthenticated guest session" removed.

    test('propagates repository failure', () async {
      final mealWithOwner = _mealFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockMealRepo.addMeal(mealWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_mealFixture);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteMeal
  // ---------------------------------------------------------------------------

  group('DeleteMeal', () {
    late DeleteMeal useCase;

    setUp(() => useCase = DeleteMeal(mockMealRepo));

    test('delegates to repository on success', () async {
      when(
        () => mockMealRepo.deleteMeal('meal-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('meal-1');

      expect(result.isRight(), isTrue);
    });

    test('propagates repository failure', () async {
      when(
        () => mockMealRepo.deleteMeal('meal-1'),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('meal-1');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetAllMeals
  // ---------------------------------------------------------------------------

  group('GetAllMeals', () {
    late GetAllMeals useCase;

    setUp(() {
      useCase = GetAllMeals(
        mockMealRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns list of meals from repository', () async {
      when(
        () => mockMealRepo.getAllMeals(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_mealFixture]));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_mealFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockMealRepo.getAllMeals(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase();

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetMealById
  // ---------------------------------------------------------------------------

  group('GetMealById', () {
    late GetMealById useCase;

    setUp(() {
      useCase = GetMealById(
        mockMealRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns meal when found', () async {
      when(
        () => mockMealRepo.getMealById(
          'meal-1',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right(_mealFixture));

      final result = await useCase('meal-1');

      expect(result, Right(_mealFixture));
    });

    test('returns null when meal not found', () async {
      when(
        () => mockMealRepo.getMealById(
          'missing',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('missing');

      expect(result, const Right(null));
    });

    test('propagates repository failure', () async {
      when(
        () => mockMealRepo.getMealById(
          'meal-1',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('meal-1');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetMealByName
  // ---------------------------------------------------------------------------

  group('GetMealByName', () {
    late GetMealByName useCase;

    setUp(() {
      useCase = GetMealByName(
        mockMealRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns meal when found by name', () async {
      when(
        () => mockMealRepo.getMealByName(
          'Chicken Rice',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right(_mealFixture));

      final result = await useCase('Chicken Rice');

      expect(result, Right(_mealFixture));
    });

    test('returns null when no meal matches name', () async {
      when(
        () => mockMealRepo.getMealByName(
          'Unknown',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('Unknown');

      expect(result, const Right(null));
    });

    test('propagates repository failure', () async {
      when(
        () => mockMealRepo.getMealByName(
          'Chicken Rice',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('Chicken Rice');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateMeal
  // ---------------------------------------------------------------------------

  group('UpdateMeal', () {
    late UpdateMeal useCase;

    setUp(() {
      useCase = UpdateMeal(mockMealRepo, appSessionRepository: mockSessionRepo);
    });

    test('stamps ownerUserId from the current authenticated session', () async {
      final mealWithOwner = _mealFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockMealRepo.updateMeal(mealWithOwner),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_mealFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockMealRepo.updateMeal(mealWithOwner)).called(1);
    });

    test('propagates repository failure', () async {
      final mealWithOwner = _mealFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockMealRepo.updateMeal(mealWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_mealFixture);

      expect(result, const Left(_dbFailure));
    });
  });
}
