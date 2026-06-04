import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../core/constants/muscle_stimulus_constants.dart';
import '../muscle_visual/muscle_visual_contract.dart';

class MuscleVisualData extends Equatable {
  final String muscleGroup;
  final double totalStimulus;
  final double threshold;
  final double visualIntensity;
  final MuscleVisualBucket bucket;
  final MuscleVisualCoverageState coverageState;
  final MuscleVisualAggregationMode aggregationMode;
  final Set<MuscleVisualSurface> visibleSurfaces;
  final double overflowAmount;
  final bool hasTrained;

  const MuscleVisualData({
    required this.muscleGroup,
    required this.totalStimulus,
    required this.threshold,
    required this.visualIntensity,
    required this.bucket,
    required this.coverageState,
    required this.aggregationMode,
    required this.visibleSurfaces,
    required this.overflowAmount,
    required this.hasTrained,
  });

  factory MuscleVisualData.untrained(
    String muscleGroup, {
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    return MuscleVisualData(
      muscleGroup: muscleGroup,
      totalStimulus: 0.0,
      threshold: 1.0,
      visualIntensity: 0.0,
      bucket: MuscleVisualBucket.empty,
      coverageState: MuscleVisualCoverageState.empty,
      aggregationMode: aggregationMode,
      visibleSurfaces: MuscleVisualContract.visibleSurfacesFor(muscleGroup),
      overflowAmount: 0.0,
      hasTrained: false,
    );
  }

  factory MuscleVisualData.fromFatigue({
    required String muscleGroup,
    required double fatigue,
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    final r = MuscleVisualContract.classifyFatigue(
      muscleGroup: muscleGroup,
      fatigue: fatigue,
      aggregationMode: aggregationMode,
    );
    return MuscleVisualData(
      muscleGroup: muscleGroup,
      totalStimulus: r.stimulus,
      threshold: r.threshold,
      visualIntensity: r.normalizedIntensity,
      bucket: r.bucket,
      coverageState: r.coverageState,
      aggregationMode: r.aggregationMode,
      visibleSurfaces: r.visibleSurfaces,
      overflowAmount: r.overflowAmount,
      hasTrained: r.hasTrained,
    );
  }

  factory MuscleVisualData.fromStimulus({
    required String muscleGroup,
    required double stimulus,
    required double threshold,
    required MuscleVisualAggregationMode aggregationMode,
  }) {
    final result = MuscleVisualContract.classify(
      muscleGroup: muscleGroup,
      stimulus: stimulus,
      threshold: threshold,
      aggregationMode: aggregationMode,
    );

    return MuscleVisualData(
      muscleGroup: muscleGroup,
      totalStimulus: result.stimulus,
      threshold: result.threshold,
      visualIntensity: result.normalizedIntensity,
      bucket: result.bucket,
      coverageState: result.coverageState,
      aggregationMode: result.aggregationMode,
      visibleSurfaces: result.visibleSurfaces,
      overflowAmount: result.overflowAmount,
      hasTrained: result.hasTrained,
    );
  }

  /// Final locked palette for the 2D human model.
  /// Kept here so the widget does not invent colors on its own.
  Color get color {
    switch (bucket) {
      case MuscleVisualBucket.empty:
        return Colors.transparent;
      case MuscleVisualBucket.light:
        return const Color(0xFF4CAF50);
      case MuscleVisualBucket.moderate:
        return const Color(0xFFFFEB3B);
      case MuscleVisualBucket.heavy:
        return const Color(0xFFFF9800);
      case MuscleVisualBucket.maximum:
        return const Color(0xFFF44336);
    }
  }

  /// Fixed overlay alpha per state so the model looks consistent instead of
  /// drifting with arbitrary opacity math in the widget.
  double get overlayOpacity {
    switch (coverageState) {
      case MuscleVisualCoverageState.empty:
        return 0.0;
      case MuscleVisualCoverageState.partial:
        switch (bucket) {
          case MuscleVisualBucket.empty:
            return 0.0;
          case MuscleVisualBucket.light:
            return 0.72;
          case MuscleVisualBucket.moderate:
            return 0.78;
          case MuscleVisualBucket.heavy:
            return 0.84;
          case MuscleVisualBucket.maximum:
            return 0.90;
        }
      case MuscleVisualCoverageState.full:
        return 0.94;
      case MuscleVisualCoverageState.overflow:
        return 1.0;
    }
  }

  bool get appearsOnFront =>
      visibleSurfaces.contains(MuscleVisualSurface.front);

  bool get appearsOnBack => visibleSurfaces.contains(MuscleVisualSurface.back);

  bool get isOverflowing => coverageState == MuscleVisualCoverageState.overflow;

  String get intensityLevel {
    switch (bucket) {
      case MuscleVisualBucket.empty:
        return 'Untrained';
      case MuscleVisualBucket.light:
        return 'Light';
      case MuscleVisualBucket.moderate:
        return 'Moderate';
      case MuscleVisualBucket.heavy:
        return 'Heavy';
      case MuscleVisualBucket.maximum:
        return 'Maximum';
    }
  }

  String get displayName => MuscleStimulus.getDisplayName(muscleGroup);

  MuscleVisualData copyWith({
    String? muscleGroup,
    double? totalStimulus,
    double? threshold,
    double? visualIntensity,
    MuscleVisualBucket? bucket,
    MuscleVisualCoverageState? coverageState,
    MuscleVisualAggregationMode? aggregationMode,
    Set<MuscleVisualSurface>? visibleSurfaces,
    double? overflowAmount,
    bool? hasTrained,
  }) {
    return MuscleVisualData(
      muscleGroup: muscleGroup ?? this.muscleGroup,
      totalStimulus: totalStimulus ?? this.totalStimulus,
      threshold: threshold ?? this.threshold,
      visualIntensity: visualIntensity ?? this.visualIntensity,
      bucket: bucket ?? this.bucket,
      coverageState: coverageState ?? this.coverageState,
      aggregationMode: aggregationMode ?? this.aggregationMode,
      visibleSurfaces: visibleSurfaces ?? this.visibleSurfaces,
      overflowAmount: overflowAmount ?? this.overflowAmount,
      hasTrained: hasTrained ?? this.hasTrained,
    );
  }

  @override
  List<Object?> get props => [
    muscleGroup,
    totalStimulus,
    threshold,
    visualIntensity,
    bucket,
    coverageState,
    aggregationMode,
    visibleSurfaces,
    overflowAmount,
    hasTrained,
  ];
}
