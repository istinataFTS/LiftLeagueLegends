import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MuscleVisualContract.visibleSurfacesFor', () {
    test('returns front surface for front-only muscle', () {
      final result = MuscleVisualContract.visibleSurfacesFor('abs');

      expect(result, {MuscleVisualSurface.front});
    });

    test('returns back surface for back-only muscle', () {
      final result = MuscleVisualContract.visibleSurfacesFor('lats');

      expect(result, {MuscleVisualSurface.back});
    });

    test('returns both surfaces for dual-visibility muscle', () {
      final result = MuscleVisualContract.visibleSurfacesFor('side-delts');

      expect(result, {MuscleVisualSurface.front, MuscleVisualSurface.back});
    });
  });

  group('MuscleVisualContract.aggregationModeForPeriod', () {
    test('maps each period to explicit aggregation semantics', () {
      expect(
        MuscleVisualContract.aggregationModeForPeriod(TimePeriod.today),
        MuscleVisualAggregationMode.remainingDailyCapacity,
      );
      expect(
        MuscleVisualContract.aggregationModeForPeriod(TimePeriod.week),
        MuscleVisualAggregationMode.rollingWeeklyLoad,
      );
      expect(
        MuscleVisualContract.aggregationModeForPeriod(TimePeriod.month),
        MuscleVisualAggregationMode.trailingThirtyDayLoad,
      );
      expect(
        MuscleVisualContract.aggregationModeForPeriod(TimePeriod.allTime),
        MuscleVisualAggregationMode.allTimePeakNormalized,
      );
    });
  });

  group('MuscleVisualContract.classify', () {
    test('returns empty state for zero stimulus', () {
      final result = MuscleVisualContract.classify(
        muscleGroup: 'abs',
        stimulus: 0,
        threshold: 10,
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      );

      expect(result.hasTrained, isFalse);
      expect(result.bucket, MuscleVisualBucket.empty);
      expect(result.coverageState, MuscleVisualCoverageState.empty);
      expect(result.normalizedIntensity, 0);
      expect(result.overflowAmount, 0);
    });

    test('returns partial state below threshold', () {
      final result = MuscleVisualContract.classify(
        muscleGroup: 'abs',
        stimulus: 5,
        threshold: 10,
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      );

      expect(result.hasTrained, isTrue);
      expect(result.coverageState, MuscleVisualCoverageState.partial);
      expect(result.normalizedIntensity, 0.5);
      expect(result.overflowAmount, 0);
    });

    test('returns full state at threshold', () {
      final result = MuscleVisualContract.classify(
        muscleGroup: 'abs',
        stimulus: 10,
        threshold: 10,
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      );

      expect(result.coverageState, MuscleVisualCoverageState.full);
      expect(result.normalizedIntensity, 1.0);
      expect(result.overflowAmount, 0);
    });

    test(
      'returns overflow state above threshold while keeping intensity capped',
      () {
        final result = MuscleVisualContract.classify(
          muscleGroup: 'abs',
          stimulus: 14,
          threshold: 10,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
        );

        expect(result.coverageState, MuscleVisualCoverageState.overflow);
        expect(result.normalizedIntensity, 1.0);
        expect(result.overflowAmount, 4.0);
      },
    );
  });
}
