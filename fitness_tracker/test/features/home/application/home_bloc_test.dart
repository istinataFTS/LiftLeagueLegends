import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/features/home/application/home_bloc.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/usecases/load_home_dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockLoadHomeDashboardData extends Mock implements LoadHomeDashboardData {}

void main() {
  late MockLoadHomeDashboardData mockLoadHomeDashboardData;
  late HomeBloc bloc;

  final DateTime now = DateTime(2026, 3, 19, 10, 0);

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

  HomeDashboardData buildDashboardData({
    List<NutritionLog>? todaysLogs,
    Map<String, double>? macros,
  }) {
    return HomeDashboardData(
      todaysLogs: todaysLogs ?? <NutritionLog>[newerLog, olderLog],
      dailyMacros: macros ?? dailyMacros,
    );
  }

  setUp(() {
    mockLoadHomeDashboardData = MockLoadHomeDashboardData();

    bloc = HomeBloc(loadHomeDashboardData: mockLoadHomeDashboardData);
  });

  tearDown(() async {
    await bloc.close();
  });

  test('initial state is HomeInitial', () {
    expect(bloc.state, const HomeInitial());
  });

  blocTest<HomeBloc, HomeState>(
    'emits [HomeLoading, HomeLoaded] when load succeeds',
    build: () {
      when(
        () => mockLoadHomeDashboardData(),
      ).thenAnswer((_) async => Right(buildDashboardData()));
      return bloc;
    },
    act: (HomeBloc bloc) => bloc.add(const LoadHomeDataEvent()),
    expect: () => <Matcher>[
      const TypeMatcher<HomeLoading>(),
      isA<HomeLoaded>().having(
        (HomeLoaded state) => state.data,
        'data',
        buildDashboardData(),
      ),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'emits HomeError when dashboard loading fails',
    build: () {
      when(
        () => mockLoadHomeDashboardData(),
      ).thenAnswer((_) async => const Left(CacheFailure('dashboard failed')));
      return bloc;
    },
    act: (HomeBloc bloc) => bloc.add(const LoadHomeDataEvent()),
    expect: () => <Matcher>[
      const TypeMatcher<HomeLoading>(),
      isA<HomeError>().having(
        (HomeError state) => state.message,
        'message',
        'dashboard failed',
      ),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'refresh preserves current HomeLoaded state when dashboard refresh fails',
    build: () {
      when(
        () => mockLoadHomeDashboardData(),
      ).thenAnswer((_) async => const Left(CacheFailure('refresh failed')));
      return bloc;
    },
    seed: () => HomeLoaded(
      data: buildDashboardData(todaysLogs: <NutritionLog>[newerLog]),
    ),
    act: (HomeBloc bloc) => bloc.add(const RefreshHomeDataEvent()),
    // Bloc deduplication: emit(state) is a no-op when state hasn't changed,
    // so no new state is emitted when the refresh fails and the current state
    // is preserved.
    expect: () => <HomeState>[],
    verify: (_) {
      // Confirm the bloc still holds the original loaded state
      expect(
        bloc.state,
        HomeLoaded(
          data: buildDashboardData(todaysLogs: <NutritionLog>[newerLog]),
        ),
      );
    },
  );

  blocTest<HomeBloc, HomeState>(
    'refresh emits updated HomeLoaded when dashboard refresh succeeds',
    build: () {
      when(() => mockLoadHomeDashboardData()).thenAnswer(
        (_) async => Right(
          buildDashboardData(todaysLogs: <NutritionLog>[olderLog, newerLog]),
        ),
      );
      return bloc;
    },
    seed: () => HomeLoaded(
      data: buildDashboardData(todaysLogs: <NutritionLog>[newerLog]),
    ),
    act: (HomeBloc bloc) => bloc.add(const RefreshHomeDataEvent()),
    expect: () => <HomeState>[
      HomeLoaded(
        data: buildDashboardData(
          todaysLogs: <NutritionLog>[olderLog, newerLog],
        ),
      ),
    ],
  );
}
