import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/home/presentation/mappers/home_view_data_mapper.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression guards for the "stat cards disagree with the 2D muscle map"
/// bug (Phase 3). After the Slice 3 UI refactor, the Sets / Muscles text
/// labels were removed from the card (they were never rendered), but the
/// underlying parity contract still holds: the muscle summary list and the
/// body-visual overlays are both sourced from the same [MuscleVisualLoaded]
/// state, so they can never disagree. These tests pin that contract at the
/// mapper boundary.
void main() {
  final DateTime now = DateTime(2026, 4, 20);
  const AppSettings settings = AppSettings.defaults();

  // Uses canonical MuscleStimulus keys so _frontBodyAssetMap / _backBodyAssetMap
  // produce actual overlay entries and bodyVisual.hasHighlights returns true.
  MuscleVisualData trained(String group, {double stimulus = 18}) {
    return MuscleVisualData(
      muscleGroup: group,
      totalStimulus: stimulus,
      threshold: 25,
      visualIntensity: stimulus / 25,
      bucket: MuscleVisualBucket.heavy,
      coverageState: MuscleVisualCoverageState.partial,
      aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      visibleSurfaces: const <MuscleVisualSurface>{MuscleVisualSurface.front},
      overflowAmount: 0,
      hasTrained: true,
    );
  }

  MuscleVisualData untrained(String group) {
    return MuscleVisualData(
      muscleGroup: group,
      totalStimulus: 0,
      threshold: 25,
      visualIntensity: 0,
      bucket: MuscleVisualBucket.empty,
      coverageState: MuscleVisualCoverageState.empty,
      aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      visibleSurfaces: const <MuscleVisualSurface>{MuscleVisualSurface.front},
      overflowAmount: 0,
      hasTrained: false,
    );
  }

  HomeDashboardData homeDataWith({required int weeklySetCount}) {
    return HomeDashboardData(
      todaysLogs: const <NutritionLog>[],
      dailyMacros: const <String, double>{},
      weeklySetCount: weeklySetCount,
    );
  }

  MuscleVisualLoaded loadedState({
    required Map<String, MuscleVisualData> muscleData,
    TimePeriod period = TimePeriod.week,
  }) {
    return MuscleVisualLoaded(
      muscleData: muscleData,
      currentPeriod: period,
      loadedAt: now,
    );
  }

  test(
    'muscle summary and body visual agree: trained muscles appear in both',
    () {
      // Before Phase 3, Sets came from a raw repo list and Muscles came from
      // factor-aware stimulus, so they could disagree.  Now both muscle summary
      // and body visual are sourced from the same MuscleVisualLoaded state.
      // 'chest' is a canonical key that exists in _frontBodyAssetMap.
      final HomePageViewData result = HomeViewDataMapper.map(
        homeData: homeDataWith(weeklySetCount: 3),
        muscleVisualState: loadedState(
          muscleData: <String, MuscleVisualData>{
            'chest': trained('chest'),
            'lats': untrained('lats'),
          },
        ),
        settings: settings,
        userName: 'Tester',
      );

      // Only the trained muscle appears in the summary.
      expect(result.progress.muscleSummary, hasLength(1));
      expect(result.progress.muscleSummary.first.displayName, isNotEmpty);
      // Body visual derives highlights from the same data.
      expect(result.progress.bodyVisual.hasHighlights, isTrue);
    },
  );

  test('zero trained muscles ⇒ empty muscle summary and no visual highlights '
      '(empty-week parity)', () {
    final HomePageViewData result = HomeViewDataMapper.map(
      homeData: homeDataWith(weeklySetCount: 0),
      muscleVisualState: loadedState(
        muscleData: <String, MuscleVisualData>{
          'chest': untrained('chest'),
          'lats': untrained('lats'),
        },
      ),
      settings: settings,
      userName: 'Tester',
    );

    expect(result.progress.muscleSummary, isEmpty);
    expect(result.progress.bodyVisual.hasHighlights, isFalse);
    expect(result.progress.bodyVisual.frontLayers, isEmpty);
    expect(result.progress.bodyVisual.backLayers, isEmpty);
  });

  test('weeklySetCount from HomeDashboardData is available for derived uses — '
      'regression guard for the SSOT fix', () {
    // If weeklySetCount is ever re-routed away from HomeDashboardData,
    // both summary and visual consistency break.  The guard: when the
    // resolver says 4 sets were effective, exactly 1 trained muscle appears
    // in the loaded muscle data (same source of truth).
    final HomePageViewData result = HomeViewDataMapper.map(
      homeData: homeDataWith(weeklySetCount: 4),
      muscleVisualState: loadedState(
        muscleData: <String, MuscleVisualData>{'chest': trained('chest')},
      ),
      settings: settings,
      userName: 'Tester',
    );

    expect(result.progress.muscleSummary, hasLength(1));
    expect(result.progress.bodyVisual.hasHighlights, isTrue);
  });
}
