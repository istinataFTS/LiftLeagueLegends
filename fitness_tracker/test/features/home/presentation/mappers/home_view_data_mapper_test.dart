import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/home/presentation/mappers/home_view_data_mapper.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps trained muscles into front and back body overlays', () {
    final viewData = HomeViewDataMapper.map(
      homeData: HomeDashboardData(
        todaysLogs: const <NutritionLog>[],
        dailyMacros: HomeDashboardData.emptyDailyMacros,
      ),
      muscleVisualState: MuscleVisualLoaded(
        muscleData: <String, MuscleVisualData>{
          'chest': const MuscleVisualData(
            muscleGroup: 'chest',
            totalStimulus: 18,
            threshold: 25,
            visualIntensity: 0.72,
            bucket: MuscleVisualBucket.heavy,
            coverageState: MuscleVisualCoverageState.partial,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.front},
            overflowAmount: 0,
            hasTrained: true,
          ),
          'lats': const MuscleVisualData(
            muscleGroup: 'lats',
            totalStimulus: 24,
            threshold: 25,
            visualIntensity: 0.96,
            bucket: MuscleVisualBucket.maximum,
            coverageState: MuscleVisualCoverageState.full,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.back},
            overflowAmount: 0,
            hasTrained: true,
          ),
        },
        currentPeriod: TimePeriod.week,
        loadedAt: DateTime(2026, 3, 27),
      ),
      settings: const AppSettings.defaults(),
      userName: 'Tester',
    );

    expect(viewData.greeting, 'Hello, Tester!');
    expect(viewData.progress.bodyVisual.frontLayers, isNotEmpty);
    expect(viewData.progress.bodyVisual.backLayers, isNotEmpty);
    expect(
      viewData.progress.bodyVisual.frontLayers.any(
        (layer) => layer.assetPath.endsWith('front_chest.png'),
      ),
      isTrue,
    );
    expect(
      viewData.progress.bodyVisual.backLayers.any(
        (layer) => layer.assetPath.endsWith('back_lats.png'),
      ),
      isTrue,
    );
  });

  test('overlay and summary colours come from the Deep Mist fatigue ramp', () {
    final viewData = HomeViewDataMapper.map(
      homeData: HomeDashboardData(
        todaysLogs: const <NutritionLog>[],
        dailyMacros: HomeDashboardData.emptyDailyMacros,
      ),
      muscleVisualState: MuscleVisualLoaded(
        muscleData: <String, MuscleVisualData>{
          'chest': const MuscleVisualData(
            muscleGroup: 'chest',
            totalStimulus: 18,
            threshold: 25,
            visualIntensity: 0.72,
            bucket: MuscleVisualBucket.heavy,
            coverageState: MuscleVisualCoverageState.partial,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.front},
            overflowAmount: 0,
            hasTrained: true,
          ),
          'lats': const MuscleVisualData(
            muscleGroup: 'lats',
            totalStimulus: 24,
            threshold: 25,
            visualIntensity: 0.96,
            bucket: MuscleVisualBucket.maximum,
            coverageState: MuscleVisualCoverageState.full,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: <MuscleVisualSurface>{MuscleVisualSurface.back},
            overflowAmount: 0,
            hasTrained: true,
          ),
        },
        currentPeriod: TimePeriod.week,
        loadedAt: DateTime(2026, 3, 27),
      ),
      settings: const AppSettings.defaults(),
      userName: 'Tester',
    );

    // `heavy` is bucket index 3, `maximum` is index 4 — brighter = more
    // fatigued, so the ramp must not be read in reverse.
    expect(
      viewData.progress.bodyVisual.frontLayers.first.color,
      LiftColors.fatigue[3],
    );
    expect(
      viewData.progress.bodyVisual.backLayers.first.color,
      LiftColors.fatigue[4],
    );
    expect(
      viewData.progress.muscleSummary
          .map((HomeMuscleSummaryItemViewData item) => item.color)
          .toSet(),
      <Color>{LiftColors.fatigue[3], LiftColors.fatigue[4]},
    );

    // The retired green→red heatmap must not survive anywhere in Home.
    final Set<Color> legacyHeatmap = <Color>{
      const Color(0xFF4CAF50),
      const Color(0xFFFFEB3B),
      const Color(0xFFFF9800),
      const Color(0xFFF44336),
    };
    final Iterable<Color> allColours = <Color>[
      ...viewData.progress.bodyVisual.frontLayers.map(
        (HomeBodyOverlayViewData l) => l.color,
      ),
      ...viewData.progress.bodyVisual.backLayers.map(
        (HomeBodyOverlayViewData l) => l.color,
      ),
      ...viewData.progress.muscleSummary.map(
        (HomeMuscleSummaryItemViewData i) => i.color,
      ),
    ];
    for (final Color colour in allColours) {
      expect(legacyHeatmap.contains(colour), isFalse);
    }
  });

  // `muscleSummary` no longer renders (the frame drops the per-muscle rows and
  // Spec C is expected to want them back), but the mapper still sorts and caps
  // the list. These two cases are the only coverage of that ordering since
  // `muscle_training_summary_widget_test.dart` was deleted.
  MuscleVisualData trainedMuscle(String group, double stimulus) {
    return MuscleVisualData(
      muscleGroup: group,
      totalStimulus: stimulus,
      threshold: 25,
      visualIntensity: stimulus / 25,
      bucket: MuscleVisualBucket.moderate,
      coverageState: MuscleVisualCoverageState.partial,
      aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      visibleSurfaces: const <MuscleVisualSurface>{MuscleVisualSurface.front},
      overflowAmount: 0,
      hasTrained: true,
    );
  }

  HomePageViewData mapMuscles(Map<String, MuscleVisualData> muscleData) {
    return HomeViewDataMapper.map(
      homeData: HomeDashboardData(
        todaysLogs: const <NutritionLog>[],
        dailyMacros: HomeDashboardData.emptyDailyMacros,
      ),
      muscleVisualState: MuscleVisualLoaded(
        muscleData: muscleData,
        currentPeriod: TimePeriod.week,
        loadedAt: DateTime(2026, 3, 27),
      ),
      settings: const AppSettings.defaults(),
      userName: 'Tester',
    );
  }

  test('muscle summary is ranked by descending total stimulus', () {
    final HomePageViewData viewData = mapMuscles(<String, MuscleVisualData>{
      'chest': trainedMuscle('chest', 8),
      'lats': trainedMuscle('lats', 22),
      'quads': trainedMuscle('quads', 15),
    });

    expect(
      viewData.progress.muscleSummary
          .map((HomeMuscleSummaryItemViewData item) => item.stimulusLabel)
          .toList(),
      <String>['22', '15', '8'],
    );
  });

  test('muscle summary is capped at six entries', () {
    final HomePageViewData viewData = mapMuscles(<String, MuscleVisualData>{
      'chest': trainedMuscle('chest', 21),
      'lats': trainedMuscle('lats', 20),
      'quads': trainedMuscle('quads', 19),
      'biceps': trainedMuscle('biceps', 18),
      'triceps': trainedMuscle('triceps', 17),
      'glutes': trainedMuscle('glutes', 16),
      'calves': trainedMuscle('calves', 15),
      'hamstrings': trainedMuscle('hamstrings', 14),
    });

    expect(viewData.progress.muscleSummary, hasLength(6));
    // The cap keeps the top six, not an arbitrary six.
    expect(viewData.progress.muscleSummary.last.stimulusLabel, '16');
  });

  test('week range label is zero-padded and em-dash separated', () {
    final viewData = HomeViewDataMapper.map(
      homeData: HomeDashboardData(
        todaysLogs: const <NutritionLog>[],
        dailyMacros: HomeDashboardData.emptyDailyMacros,
      ),
      muscleVisualState: const MuscleVisualInitial(),
      settings: const AppSettings.defaults(),
      userName: 'Tester',
    );

    expect(
      viewData.weekRangeLabel,
      matches(RegExp(r'^[A-Z][a-z]{2} \d{2} — [A-Z][a-z]{2} \d{2}$')),
    );
  });
}
