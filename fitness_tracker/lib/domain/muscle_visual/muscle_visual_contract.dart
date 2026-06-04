import '../../core/constants/muscle_stimulus_constants.dart';
import '../../core/constants/svg_muscle_mapping.dart';
import '../entities/time_period.dart';

enum MuscleVisualBucket { empty, light, moderate, heavy, maximum }

enum MuscleVisualCoverageState { empty, partial, full, overflow }

enum MuscleVisualAggregationMode {
  remainingDailyCapacity,
  rollingWeeklyLoad,
  trailingThirtyDayLoad,
  allTimePeakNormalized,
}

enum MuscleVisualSurface { front, back }

class MuscleVisualComputationResult {
  final double stimulus;
  final double threshold;
  final double normalizedIntensity;
  final double overflowAmount;
  final bool hasTrained;
  final MuscleVisualBucket bucket;
  final MuscleVisualCoverageState coverageState;
  final MuscleVisualAggregationMode aggregationMode;
  final Set<MuscleVisualSurface> visibleSurfaces;

  const MuscleVisualComputationResult({
    required this.stimulus,
    required this.threshold,
    required this.normalizedIntensity,
    required this.overflowAmount,
    required this.hasTrained,
    required this.bucket,
    required this.coverageState,
    required this.aggregationMode,
    required this.visibleSurfaces,
  });
}

class MuscleVisualContract {
  const MuscleVisualContract._();

  static Set<MuscleVisualSurface> visibleSurfacesFor(String muscleGroup) {
    final surfaces = <MuscleVisualSurface>{};

    if (SvgMuscleMapping.isVisibleOnFront(muscleGroup)) {
      surfaces.add(MuscleVisualSurface.front);
    }

    if (SvgMuscleMapping.isVisibleOnBack(muscleGroup)) {
      surfaces.add(MuscleVisualSurface.back);
    }

    return surfaces;
  }

  static MuscleVisualAggregationMode aggregationModeForPeriod(
    TimePeriod period,
  ) {
    switch (period) {
      case TimePeriod.today:
        return MuscleVisualAggregationMode.remainingDailyCapacity;
      case TimePeriod.week:
        return MuscleVisualAggregationMode.rollingWeeklyLoad;
      case TimePeriod.month:
        return MuscleVisualAggregationMode.trailingThirtyDayLoad;
      case TimePeriod.allTime:
        return MuscleVisualAggregationMode.allTimePeakNormalized;
    }
  }

  static MuscleVisualComputationResult classify({
    required String muscleGroup,
    required double stimulus,
    required double threshold,
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    final safeStimulus = stimulus < 0 ? 0.0 : stimulus;
    final safeThreshold = threshold <= 0 ? 1.0 : threshold;
    final rawRatio = safeStimulus / safeThreshold;
    final normalizedIntensity = rawRatio.clamp(0.0, 1.0);
    final overflowAmount = safeStimulus > safeThreshold
        ? safeStimulus - safeThreshold
        : 0.0;
    final hasTrained = safeStimulus > 0.0;

    return MuscleVisualComputationResult(
      stimulus: safeStimulus,
      threshold: safeThreshold,
      normalizedIntensity: normalizedIntensity,
      overflowAmount: overflowAmount,
      hasTrained: hasTrained,
      bucket: _bucketForIntensity(normalizedIntensity, hasTrained: hasTrained),
      coverageState: _coverageStateFor(
        stimulus: safeStimulus,
        threshold: safeThreshold,
      ),
      aggregationMode: aggregationMode,
      visibleSurfaces: visibleSurfacesFor(muscleGroup),
    );
  }

  static MuscleVisualBucket _bucketForIntensity(
    double intensity, {
    required bool hasTrained,
  }) {
    if (!hasTrained || intensity == 0.0) {
      return MuscleVisualBucket.empty;
    }

    if (intensity < MuscleStimulus.colorThresholdGreen) {
      return MuscleVisualBucket.light;
    }

    if (intensity < MuscleStimulus.colorThresholdYellow) {
      return MuscleVisualBucket.moderate;
    }

    if (intensity < MuscleStimulus.colorThresholdOrange) {
      return MuscleVisualBucket.heavy;
    }

    return MuscleVisualBucket.maximum;
  }

  static MuscleVisualCoverageState _coverageStateFor({
    required double stimulus,
    required double threshold,
  }) {
    if (stimulus <= 0.0) {
      return MuscleVisualCoverageState.empty;
    }

    if (stimulus > threshold) {
      return MuscleVisualCoverageState.overflow;
    }

    if (stimulus == threshold) {
      return MuscleVisualCoverageState.full;
    }

    return MuscleVisualCoverageState.partial;
  }

  /// Classifies a 0–100 fatigue value into the locked band buckets.
  /// < 20 → empty (recovered/gray); [20,40) light/green; [40,60) moderate/yellow;
  /// [60,80) heavy/orange; >= 80 maximum/red.
  static MuscleVisualComputationResult classifyFatigue({
    required String muscleGroup,
    required double fatigue,
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    final f = fatigue.clamp(0.0, 100.0);
    final normalized = f / 100.0;
    final hasTrained = normalized >= MuscleStimulus.fatigueBandMild;
    final bucket = _fatigueBucket(normalized);
    final coverage = !hasTrained
        ? MuscleVisualCoverageState.empty
        : (normalized >= 1.0
              ? MuscleVisualCoverageState.full
              : MuscleVisualCoverageState.partial);
    return MuscleVisualComputationResult(
      stimulus: f,
      threshold: 100.0,
      normalizedIntensity: normalized,
      overflowAmount: 0.0,
      hasTrained: hasTrained,
      bucket: bucket,
      coverageState: coverage,
      aggregationMode: aggregationMode,
      visibleSurfaces: visibleSurfacesFor(muscleGroup),
    );
  }

  static MuscleVisualBucket _fatigueBucket(double normalized) {
    if (normalized < MuscleStimulus.fatigueBandMild) {
      return MuscleVisualBucket.empty;
    }
    if (normalized < MuscleStimulus.fatigueBandModerate) {
      return MuscleVisualBucket.light;
    }
    if (normalized < MuscleStimulus.fatigueBandHigh) {
      return MuscleVisualBucket.moderate;
    }
    if (normalized < MuscleStimulus.fatigueBandSevere) {
      return MuscleVisualBucket.heavy;
    }
    return MuscleVisualBucket.maximum;
  }
}
