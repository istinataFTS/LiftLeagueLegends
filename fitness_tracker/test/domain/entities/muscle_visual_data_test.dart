import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
