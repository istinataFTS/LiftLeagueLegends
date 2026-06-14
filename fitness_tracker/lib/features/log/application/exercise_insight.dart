import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../domain/entities/workout_set.dart';
import '../../../domain/muscle_visual/muscle_visual_contract.dart';

/// Per-muscle fatigue summary the Exercise tab renders as a chip.
/// `coarseGroup` is a key from `MuscleGroups.all`; `percent` is the visual
/// intensity (0..100, week aggregation) for the most-loaded granular
/// sub-muscle in that coarse group.
class MuscleFatigue extends Equatable {
  final String coarseGroup;
  final String displayName;
  final int percent;
  final MuscleVisualBucket bucket;
  final Color color;

  const MuscleFatigue({
    required this.coarseGroup,
    required this.displayName,
    required this.percent,
    required this.bucket,
    required this.color,
  });

  @override
  List<Object?> get props => <Object?>[
    coarseGroup,
    displayName,
    percent,
    bucket,
    color,
  ];
}

/// Read model exposing the values the Exercise tab needs once an exercise has
/// been selected: best historical set, today's set count and total kg volume,
/// and a fatigue chip per targeted coarse muscle group.
class ExerciseInsight extends Equatable {
  final String exerciseId;
  final WorkoutSet? personalRecord;
  final int setsToday;
  final double volumeTodayKg;
  final List<MuscleFatigue> muscles;

  const ExerciseInsight({
    required this.exerciseId,
    required this.personalRecord,
    required this.setsToday,
    required this.volumeTodayKg,
    required this.muscles,
  });

  @override
  List<Object?> get props => <Object?>[
    exerciseId,
    personalRecord,
    setsToday,
    volumeTodayKg,
    muscles,
  ];
}
