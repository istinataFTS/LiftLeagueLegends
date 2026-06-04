import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MuscleVisualData.fromFatigue', () {
    const mode = MuscleVisualAggregationMode.rollingWeeklyLoad;

    test('fatigue 0 → untrained: empty bucket, transparent, opacity 0', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 0.0,
        aggregationMode: mode,
      );
      expect(data.bucket, MuscleVisualBucket.empty);
      expect(data.hasTrained, isFalse);
      expect(data.color, Colors.transparent);
      expect(data.overlayOpacity, 0.0);
    });

    test('fatigue 30 → light/green bucket, partial coverage, opacity 0.72', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 30.0,
        aggregationMode: mode,
      );
      expect(data.bucket, MuscleVisualBucket.light);
      expect(data.coverageState, MuscleVisualCoverageState.partial);
      expect(data.color, const Color(0xFF4CAF50));
      expect(data.overlayOpacity, 0.72);
    });

    test('fatigue 50 → moderate/yellow bucket', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 50.0,
        aggregationMode: mode,
      );
      expect(data.bucket, MuscleVisualBucket.moderate);
      expect(data.color, const Color(0xFFFFEB3B));
    });

    test('fatigue 70 → heavy/orange bucket, opacity 0.84', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 70.0,
        aggregationMode: mode,
      );
      expect(data.bucket, MuscleVisualBucket.heavy);
      expect(data.color, const Color(0xFFFF9800));
      expect(data.overlayOpacity, 0.84);
    });

    test('fatigue 90 → maximum/red bucket', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 90.0,
        aggregationMode: mode,
      );
      expect(data.bucket, MuscleVisualBucket.maximum);
      expect(data.color, const Color(0xFFF44336));
    });

    test('fatigue 100 → full coverage, opacity 0.94', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 100.0,
        aggregationMode: mode,
      );
      expect(data.coverageState, MuscleVisualCoverageState.full);
      expect(data.overlayOpacity, 0.94);
    });

    test('threshold is 100 and overflowAmount is 0', () {
      final data = MuscleVisualData.fromFatigue(
        muscleGroup: 'abs',
        fatigue: 60.0,
        aggregationMode: mode,
      );
      expect(data.threshold, 100.0);
      expect(data.overflowAmount, 0.0);
    });
  });

  group('MuscleVisualData final color system', () {
    test('uses locked colors for each bucket', () {
      expect(
        MuscleVisualData(
          muscleGroup: 'abs',
          totalStimulus: 1,
          threshold: 10,
          visualIntensity: 0.1,
          bucket: MuscleVisualBucket.light,
          coverageState: MuscleVisualCoverageState.partial,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
          visibleSurfaces: const {MuscleVisualSurface.front},
          overflowAmount: 0,
          hasTrained: true,
        ).color,
        const Color(0xFF4CAF50),
      );

      expect(
        MuscleVisualData(
          muscleGroup: 'abs',
          totalStimulus: 5,
          threshold: 10,
          visualIntensity: 0.5,
          bucket: MuscleVisualBucket.moderate,
          coverageState: MuscleVisualCoverageState.partial,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
          visibleSurfaces: const {MuscleVisualSurface.front},
          overflowAmount: 0,
          hasTrained: true,
        ).color,
        const Color(0xFFFFEB3B),
      );

      expect(
        MuscleVisualData(
          muscleGroup: 'abs',
          totalStimulus: 7,
          threshold: 10,
          visualIntensity: 0.7,
          bucket: MuscleVisualBucket.heavy,
          coverageState: MuscleVisualCoverageState.partial,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
          visibleSurfaces: const {MuscleVisualSurface.front},
          overflowAmount: 0,
          hasTrained: true,
        ).color,
        const Color(0xFFFF9800),
      );

      expect(
        MuscleVisualData(
          muscleGroup: 'abs',
          totalStimulus: 10,
          threshold: 10,
          visualIntensity: 1.0,
          bucket: MuscleVisualBucket.maximum,
          coverageState: MuscleVisualCoverageState.full,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
          visibleSurfaces: const {MuscleVisualSurface.front},
          overflowAmount: 0,
          hasTrained: true,
        ).color,
        const Color(0xFFF44336),
      );
    });

    test('uses transparent color when untrained', () {
      final data = MuscleVisualData.untrained(
        'abs',
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
      );

      expect(data.color, Colors.transparent);
      expect(data.overlayOpacity, 0.0);
    });

    test('uses full opacity for overflow state', () {
      final data = MuscleVisualData(
        muscleGroup: 'quads',
        totalStimulus: 15,
        threshold: 10,
        visualIntensity: 1.0,
        bucket: MuscleVisualBucket.maximum,
        coverageState: MuscleVisualCoverageState.overflow,
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
        visibleSurfaces: const {MuscleVisualSurface.front},
        overflowAmount: 5,
        hasTrained: true,
      );

      expect(data.overlayOpacity, 1.0);
    });
  });
}
