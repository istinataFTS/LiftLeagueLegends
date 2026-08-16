import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../domain/entities/time_period.dart';
import '../../application/muscle_visual_bloc.dart' show MuscleMapMode;

enum HomeTone { muted, primary, warning, success }

class HomePageViewData extends Equatable {
  const HomePageViewData({
    required this.greeting,
    required this.weekRangeLabel,
    required this.nutrition,
    required this.progress,
  });

  final String greeting;
  final String weekRangeLabel;
  final HomeMacroStripViewData nutrition;
  final HomeProgressCardViewData progress;

  @override
  List<Object?> get props => <Object?>[
    greeting,
    weekRangeLabel,
    nutrition,
    progress,
  ];
}

/// Today's intake totals, raw. The widget formats them (`value.round()`) and
/// the macro composition bar needs the grams unrounded, so the mapper hands
/// numbers across rather than pre-baked label strings.
class HomeMacroStripViewData extends Equatable {
  const HomeMacroStripViewData({
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatsGrams,
  });

  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatsGrams;

  @override
  List<Object?> get props => <Object?>[
    calories,
    proteinGrams,
    carbsGrams,
    fatsGrams,
  ];
}

class HomeProgressCardViewData extends Equatable {
  const HomeProgressCardViewData({
    required this.title,
    required this.selectedPeriod,
    required this.selectorEnabled,
    required this.showPeriodSelector,
    required this.muscleMapMode,
    required this.bodyVisual,
    required this.muscleSummary,
    required this.isLoading,
    required this.errorMessage,
  });

  final String title;
  final TimePeriod selectedPeriod;

  /// Whether the period dropdown is responsive to taps (disabled while loading).
  final bool selectorEnabled;

  /// Whether the period selector is visible at all.
  /// Hidden in fatigue mode because fatigue is always "right now".
  final bool showPeriodSelector;

  /// Which visualisation lens is active.
  final MuscleMapMode muscleMapMode;

  final HomeBodyVisualViewData bodyVisual;

  /// Ranked per-muscle rows. Populated but **not currently rendered** — PR B3
  /// gave the whole screen to the muscle map; Spec C's "tap a group for its
  /// own figure" work reads this back.
  final List<HomeMuscleSummaryItemViewData> muscleSummary;
  final bool isLoading;
  final String? errorMessage;

  @override
  List<Object?> get props => <Object?>[
    title,
    selectedPeriod,
    selectorEnabled,
    showPeriodSelector,
    muscleMapMode,
    bodyVisual,
    muscleSummary,
    isLoading,
    errorMessage,
  ];
}

class HomeBodyVisualViewData extends Equatable {
  const HomeBodyVisualViewData({
    required this.frontLayers,
    required this.backLayers,
    required this.subtitle,
  });

  final List<HomeBodyOverlayViewData> frontLayers;
  final List<HomeBodyOverlayViewData> backLayers;

  /// Descriptive status caption. Populated but **not currently rendered** —
  /// the Deep Mist muscle-map panel (PR B3) carries no status line.
  final String subtitle;

  bool get hasHighlights => frontLayers.isNotEmpty || backLayers.isNotEmpty;

  @override
  List<Object?> get props => <Object?>[frontLayers, backLayers, subtitle];
}

class HomeBodyOverlayViewData extends Equatable {
  const HomeBodyOverlayViewData({
    required this.assetPath,
    required this.color,
    required this.opacity,
    required this.label,
  });

  final String assetPath;
  final Color color;
  final double opacity;
  final String label;

  @override
  List<Object?> get props => <Object?>[assetPath, color, opacity, label];
}

/// One ranked muscle row. Built by the mapper but **not currently rendered**
/// — see [HomeProgressCardViewData.muscleSummary].
class HomeMuscleSummaryItemViewData extends Equatable {
  const HomeMuscleSummaryItemViewData({
    required this.displayName,
    required this.stimulusLabel,
    required this.intensityLabel,
    required this.color,
  });

  final String displayName;
  final String stimulusLabel;
  final String intensityLabel;
  final Color color;

  @override
  List<Object?> get props => <Object?>[
    displayName,
    stimulusLabel,
    intensityLabel,
    color,
  ];
}
