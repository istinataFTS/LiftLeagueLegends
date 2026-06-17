import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/home/presentation/mappers/home_view_data_mapper.dart';
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
}
