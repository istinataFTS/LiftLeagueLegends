import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/home/presentation/mappers/home_view_data_mapper.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2024, 1, 1);

  HomeDashboardData buildHomeData({
    int weeklySetCount = 0,
    Map<String, int> muscleSetCounts = const <String, int>{},
  }) {
    return HomeDashboardData(
      todaysLogs: const <NutritionLog>[],
      dailyMacros: const <String, double>{},
      muscleSetCounts: muscleSetCounts,
      weeklySetCount: weeklySetCount,
    );
  }

  MuscleVisualLoaded buildMuscleVisualState({
    required TimePeriod period,
    required Map<String, MuscleVisualData> muscleData,
  }) {
    return MuscleVisualLoaded(
      muscleData: muscleData,
      currentPeriod: period,
      loadedAt: createdAt,
    );
  }

  const AppSettings settings = AppSettings(
    notificationsEnabled: true,
    weekStartDay: WeekStartDay.monday,
    weightUnit: WeightUnit.kilograms,
  );

  group('HomeViewDataMapper progress mapping', () {
    test('loading state produces isLoading=true with empty muscle summary', () {
      final HomeDashboardData homeData = buildHomeData(weeklySetCount: 5);

      final HomePageViewData result = HomeViewDataMapper.map(
        homeData: homeData,
        muscleVisualState: const MuscleVisualLoading(TimePeriod.month),
        settings: settings,
        userName: 'Tester',
      );

      expect(result.progress.isLoading, isTrue);
      expect(result.progress.errorMessage, isNull);
      expect(result.progress.muscleSummary, isEmpty);
    });

    test('error state carries message and is not loading', () {
      final HomeDashboardData homeData = buildHomeData();

      final HomePageViewData result = HomeViewDataMapper.map(
        homeData: homeData,
        muscleVisualState: const MuscleVisualError(
          message: 'network failure',
          period: TimePeriod.month,
        ),
        settings: settings,
        userName: 'Tester',
      );

      expect(result.progress.isLoading, isFalse);
      expect(result.progress.errorMessage, 'network failure');
      expect(result.progress.muscleSummary, isEmpty);
    });

    test(
      'loaded state populates muscle summary for hasTrained muscles only',
      () {
        final HomeDashboardData homeData = buildHomeData(weeklySetCount: 9);

        final MuscleVisualLoaded visualState = buildMuscleVisualState(
          period: TimePeriod.month,
          muscleData: <String, MuscleVisualData>{
            'chest': const MuscleVisualData(
              muscleGroup: 'chest',
              totalStimulus: 18,
              threshold: 20,
              visualIntensity: 0.6,
              bucket: MuscleVisualBucket.heavy,
              coverageState: MuscleVisualCoverageState.partial,
              aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
              visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.front},
              overflowAmount: 0,
              hasTrained: true,
            ),
            'back': const MuscleVisualData(
              muscleGroup: 'back',
              totalStimulus: 0,
              threshold: 20,
              visualIntensity: 0,
              bucket: MuscleVisualBucket.empty,
              coverageState: MuscleVisualCoverageState.empty,
              aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
              visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.back},
              overflowAmount: 0,
              hasTrained: false,
            ),
          },
        );

        final HomePageViewData result = HomeViewDataMapper.map(
          homeData: homeData,
          muscleVisualState: visualState,
          settings: settings,
          userName: 'Tester',
        );

        expect(result.progress.isLoading, isFalse);
        expect(result.progress.errorMessage, isNull);
        // Only hasTrained=true muscles with totalStimulus > 0 appear.
        expect(result.progress.muscleSummary, hasLength(1));
      },
    );

    test(
      'volume mode shows period selector; initial state defaults to volume',
      () {
        final HomeDashboardData homeData = buildHomeData();

        final HomePageViewData result = HomeViewDataMapper.map(
          homeData: homeData,
          muscleVisualState: const MuscleVisualInitial(),
          settings: settings,
          userName: 'Tester',
        );

        expect(result.progress.showPeriodSelector, isTrue);
      },
    );

    test('macro strip carries raw zeros when all macro values are zero', () {
      final HomeDashboardData homeData = buildHomeData();

      final HomePageViewData result = HomeViewDataMapper.map(
        homeData: homeData,
        muscleVisualState: const MuscleVisualInitial(),
        settings: settings,
        userName: 'Tester',
      );

      expect(result.nutrition.calories, 0);
      expect(result.nutrition.proteinGrams, 0);
      expect(result.nutrition.carbsGrams, 0);
      expect(result.nutrition.fatsGrams, 0);
    });

    test('macro strip carries raw non-zero macro values', () {
      final HomeDashboardData homeData = HomeDashboardData(
        todaysLogs: const <NutritionLog>[],
        dailyMacros: const <String, double>{
          'calories': 1840,
          'protein': 150,
          'carbs': 200,
          'fats': 60,
        },
      );

      final HomePageViewData result = HomeViewDataMapper.map(
        homeData: homeData,
        muscleVisualState: const MuscleVisualInitial(),
        settings: settings,
        userName: 'Tester',
      );

      expect(result.nutrition.calories, 1840);
      expect(result.nutrition.proteinGrams, 150);
      expect(result.nutrition.carbsGrams, 200);
      expect(result.nutrition.fatsGrams, 60);
    });
  });
}
