import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/nutrition_log_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/add_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_daily_macros.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/update_nutrition_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionLogRepository extends Mock
    implements NutritionLogRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _logDate = DateTime(2026, 4, 1);

final _logFixture = NutritionLog(
  id: 'log-1',
  mealName: 'Oats',
  proteinGrams: 10,
  carbsGrams: 40,
  fatGrams: 5,
  calories: 245,
  loggedAt: _logDate,
  createdAt: _logDate,
);

const _authenticatedSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockNutritionLogRepository mockLogRepo;
  late MockAppSessionRepository mockSessionRepo;
  late MockAuthenticatedDataSourcePreferenceResolver mockResolver;

  setUpAll(() {
    registerFallbackValue(_logFixture);
  });

  setUp(() {
    mockLogRepo = MockNutritionLogRepository();
    mockSessionRepo = MockAppSessionRepository();
    mockResolver = MockAuthenticatedDataSourcePreferenceResolver();
  });

  // ---------------------------------------------------------------------------
  // AddNutritionLog
  // ---------------------------------------------------------------------------

  group('AddNutritionLog', () {
    late AddNutritionLog useCase;

    setUp(() {
      useCase = AddNutritionLog(
        mockLogRepo,
        appSessionRepository: mockSessionRepo,
      );
    });

    // "does not set ownerUserId when session fails" removed: AddNutritionLog
    // now propagates the session failure instead of using a guest fallback.

    test('sets ownerUserId when session is authenticated', () async {
      final logWithOwner = _logFixture.copyWith(ownerUserId: 'user-1');

      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockLogRepo.addLog(logWithOwner),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_logFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockLogRepo.addLog(logWithOwner)).called(1);
    });

    // "does not set ownerUserId for unauthenticated guest session" removed.

    test('propagates repository failure', () async {
      final logWithOwner = _logFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockLogRepo.addLog(logWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_logFixture);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteNutritionLog
  // ---------------------------------------------------------------------------

  group('DeleteNutritionLog', () {
    late DeleteNutritionLog useCase;

    setUp(() => useCase = DeleteNutritionLog(mockLogRepo));

    test('delegates to repository on success', () async {
      when(
        () => mockLogRepo.deleteLog('log-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('log-1');

      expect(result.isRight(), isTrue);
    });

    test('propagates repository failure', () async {
      when(
        () => mockLogRepo.deleteLog('log-1'),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('log-1');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetDailyMacros
  // ---------------------------------------------------------------------------

  group('GetDailyMacros', () {
    late GetDailyMacros useCase;

    setUp(() {
      useCase = GetDailyMacros(
        mockLogRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns all-zero totals for empty log list', () async {
      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Right([]));

      final result = await useCase(_logDate);

      expect(result.isRight(), isTrue);
      final totals = (result as Right).value as Map<String, double>;
      expect(totals['protein'], 0);
      expect(totals['carbs'], 0);
      expect(totals['fats'], 0);
      expect(totals['calories'], 0);
    });

    test('returns summed totals across multiple logs', () async {
      final log2 = NutritionLog(
        id: 'log-2',
        mealName: 'Eggs',
        proteinGrams: 20,
        carbsGrams: 2,
        fatGrams: 15,
        calories: 219,
        loggedAt: _logDate,
        createdAt: _logDate,
      );

      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_logFixture, log2]));

      final result = await useCase(_logDate);

      expect(result.isRight(), isTrue);
      final totals = (result as Right).value as Map<String, double>;
      // _logFixture: protein=10, carbs=40, fat=5, cal=245
      // log2:        protein=20, carbs=2,  fat=15, cal=219
      expect(totals['protein'], 30);
      expect(totals['carbs'], 42);
      expect(totals['fats'], 20);
      expect(totals['calories'], 464);
    });

    test('forwards source preference from resolver to repository', () async {
      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Right([]));

      await useCase(_logDate);

      verify(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).called(1);
    });

    test('propagates repository failure', () async {
      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_logDate);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetLogsForDate
  // ---------------------------------------------------------------------------

  group('GetLogsForDate', () {
    late GetLogsForDate useCase;

    setUp(() {
      useCase = GetLogsForDate(
        mockLogRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns logs for the given date', () async {
      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_logFixture]));

      final result = await useCase(_logDate);

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_logFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockLogRepo.getLogsForDate(
          _logDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_logDate);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetLogsByDateRange
  // ---------------------------------------------------------------------------

  group('GetLogsByDateRange', () {
    late GetLogsByDateRange useCase;

    final startDate = DateTime(2026, 4, 1);
    final endDate = DateTime(2026, 4, 7);

    setUp(() {
      useCase = GetLogsByDateRange(
        mockLogRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns logs within the date range', () async {
      when(
        () => mockLogRepo.getLogsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_logFixture]));

      final result = await useCase(startDate: startDate, endDate: endDate);

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_logFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockLogRepo.getLogsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(startDate: startDate, endDate: endDate);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateNutritionLog
  // ---------------------------------------------------------------------------

  group('UpdateNutritionLog', () {
    late UpdateNutritionLog useCase;

    setUp(() {
      useCase = UpdateNutritionLog(
        mockLogRepo,
        appSessionRepository: mockSessionRepo,
      );
    });

    test('stamps ownerUserId from the current authenticated session', () async {
      final logWithOwner = _logFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockLogRepo.updateLog(logWithOwner),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_logFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockLogRepo.updateLog(logWithOwner)).called(1);
    });

    test('propagates repository failure', () async {
      final logWithOwner = _logFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockLogRepo.updateLog(logWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_logFixture);

      expect(result, const Left(_dbFailure));
    });
  });
}
