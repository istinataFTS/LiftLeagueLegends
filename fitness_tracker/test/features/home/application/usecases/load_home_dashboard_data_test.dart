import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/services/muscle_load_resolver.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_daily_macros.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/usecases/load_home_dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetLogsForDate extends Mock implements GetLogsForDate {}

class MockGetDailyMacros extends Mock implements GetDailyMacros {}

class MockMuscleLoadResolver extends Mock implements MuscleLoadResolver {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

void main() {
  late MockGetLogsForDate mockGetLogsForDate;
  late MockGetDailyMacros mockGetDailyMacros;
  late MockMuscleLoadResolver mockMuscleLoadResolver;
  late MockAppSessionRepository mockAppSessionRepository;

  late LoadHomeDashboardData usecase;

  final DateTime now = DateTime(2026, 3, 19, 10, 0);

  const Map<String, int> muscleSetCounts = <String, int>{'chest': 1};
  const int weeklySetCount = 1;

  final NutritionLog olderLog = NutritionLog(
    id: 'log-older',
    mealName: 'Oats',
    proteinGrams: 20,
    carbsGrams: 40,
    fatGrams: 8,
    calories: 312,
    loggedAt: now.subtract(const Duration(hours: 4)),
    createdAt: now.subtract(const Duration(hours: 4)),
    syncMetadata: const EntitySyncMetadata(),
  );

  final NutritionLog newerLog = NutritionLog(
    id: 'log-newer',
    mealName: 'Chicken and Rice',
    proteinGrams: 45,
    carbsGrams: 60,
    fatGrams: 12,
    calories: 528,
    loggedAt: now.subtract(const Duration(hours: 1)),
    createdAt: now.subtract(const Duration(hours: 1)),
    syncMetadata: const EntitySyncMetadata(),
  );

  final Map<String, double> dailyMacros = <String, double>{
    'protein': 120,
    'carbs': 140,
    'fats': 40,
    'calories': 1600,
  };

  const AppSession authenticatedSession = AppSession(
    authMode: AuthMode.authenticated,
    user: AppUser(id: 'user-1', email: 'test@example.com'),
  );

  setUp(() {
    mockGetLogsForDate = MockGetLogsForDate();
    mockGetDailyMacros = MockGetDailyMacros();
    mockMuscleLoadResolver = MockMuscleLoadResolver();
    mockAppSessionRepository = MockAppSessionRepository();

    usecase = LoadHomeDashboardData(
      getLogsForDate: mockGetLogsForDate,
      getDailyMacros: mockGetDailyMacros,
      muscleLoadResolver: mockMuscleLoadResolver,
      appSessionRepository: mockAppSessionRepository,
    );
  });

  void stubSuccessfulCoreLoads() {
    when(
      () => mockAppSessionRepository.getCurrentSession(),
    ).thenAnswer((_) async => const Right(authenticatedSession));
    when(
      () => mockMuscleLoadResolver.getSetCountsByMuscle(
        userId: any(named: 'userId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const Right(muscleSetCounts));
    when(
      () => mockMuscleLoadResolver.getTotalSetCount(
        userId: any(named: 'userId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => const Right(weeklySetCount));
  }

  test(
    'returns aggregated dashboard data when all core loads succeed',
    () async {
      stubSuccessfulCoreLoads();

      when(
        () => mockGetLogsForDate(any()),
      ).thenAnswer((_) async => Right(<NutritionLog>[olderLog, newerLog]));
      when(
        () => mockGetDailyMacros(any()),
      ).thenAnswer((_) async => Right(dailyMacros));

      final result = await usecase();

      expect(
        result,
        Right<Failure, HomeDashboardData>(
          HomeDashboardData(
            todaysLogs: <NutritionLog>[newerLog, olderLog],
            dailyMacros: dailyMacros,
            muscleSetCounts: muscleSetCounts,
            weeklySetCount: weeklySetCount,
          ),
        ),
      );
    },
  );

  test('falls back to empty muscle counts for guest sessions', () async {
    when(
      () => mockAppSessionRepository.getCurrentSession(),
    ).thenAnswer((_) async => const Right(AppSession.guest()));
    when(
      () => mockGetLogsForDate(any()),
    ).thenAnswer((_) async => Right(<NutritionLog>[newerLog]));
    when(
      () => mockGetDailyMacros(any()),
    ).thenAnswer((_) async => Right(dailyMacros));

    final result = await usecase();

    expect(
      result,
      Right<Failure, HomeDashboardData>(
        HomeDashboardData(
          todaysLogs: <NutritionLog>[newerLog],
          dailyMacros: dailyMacros,
          muscleSetCounts: const <String, int>{},
        ),
      ),
    );
    verifyNever(
      () => mockMuscleLoadResolver.getSetCountsByMuscle(
        userId: any(named: 'userId'),
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    );
  });

  test('falls back to empty logs when logs loading fails', () async {
    stubSuccessfulCoreLoads();

    when(
      () => mockGetLogsForDate(any()),
    ).thenAnswer((_) async => const Left(CacheFailure('logs failed')));
    when(
      () => mockGetDailyMacros(any()),
    ).thenAnswer((_) async => Right(dailyMacros));

    final result = await usecase();

    expect(
      result,
      Right<Failure, HomeDashboardData>(
        HomeDashboardData(
          todaysLogs: const <NutritionLog>[],
          dailyMacros: dailyMacros,
          muscleSetCounts: muscleSetCounts,
          weeklySetCount: weeklySetCount,
        ),
      ),
    );
  });

  test('falls back to empty daily macros when macros loading fails', () async {
    stubSuccessfulCoreLoads();

    when(
      () => mockGetLogsForDate(any()),
    ).thenAnswer((_) async => Right(<NutritionLog>[newerLog]));
    when(
      () => mockGetDailyMacros(any()),
    ).thenAnswer((_) async => const Left(CacheFailure('macros failed')));

    final result = await usecase();

    expect(
      result,
      Right<Failure, HomeDashboardData>(
        HomeDashboardData(
          todaysLogs: <NutritionLog>[newerLog],
          dailyMacros: HomeDashboardData.emptyDailyMacros,
          muscleSetCounts: muscleSetCounts,
          weeklySetCount: weeklySetCount,
        ),
      ),
    );
  });
}
