import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_stimulus_constants.dart'
    show MuscleStimulus;
import '../../../../core/utils/week_range_label_formatter.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/muscle_visual_data.dart';
import '../../../../domain/entities/time_period.dart';
import '../../application/models/home_dashboard_data.dart';
import '../../application/muscle_visual_bloc.dart';
import '../models/home_view_data.dart';

class HomeViewDataMapper {
  const HomeViewDataMapper._();

  /// Maps the 18 canonical muscle-group keys (from [MuscleStimulus] constants)
  /// to the front-side body overlay assets.  Keys are typed constants — any key
  /// mismatch (slug changed, typo) fails at compile-time, not silently at
  /// runtime.  Merged regions (shoulders, traps) list every PNG they tint so a
  /// single canonical value colours the whole region uniformly.
  static const Map<String, List<String>>
  _frontBodyAssetMap = <String, List<String>>{
    // Shoulders = anterior + lateral deltoid heads (there is no front rear
    // delt; front_sidedelt.png is the lateral head viewed from the front).
    MuscleStimulus.shoulders: <String>[
      'assets/images/body/front_delts.png',
      'assets/images/body/front_sidedelt.png',
    ],
    MuscleStimulus.upperTraps: <String>[
      'assets/images/body/front_uppertraps.png',
    ],
    MuscleStimulus.chest: <String>['assets/images/body/front_chest.png'],
    MuscleStimulus.biceps: <String>['assets/images/body/front_biceps.png'],
    MuscleStimulus.forearms: <String>['assets/images/body/front_forearms.png'],
    MuscleStimulus.abs: <String>['assets/images/body/front_abs.png'],
    MuscleStimulus.obliques: <String>['assets/images/body/front_obliques.png'],
    MuscleStimulus.lovehandles: <String>[
      'assets/images/body/front_lovehandles.png',
    ],
    MuscleStimulus.hipadductors: <String>[
      'assets/images/body/front_hipadductors.png',
    ],
    MuscleStimulus.quads: <String>['assets/images/body/front_quads.png'],
    MuscleStimulus.calves: <String>['assets/images/body/front_calves.png'],
  };

  /// Maps the 18 canonical muscle-group keys to the back-side body overlay
  /// assets.
  static const Map<String, List<String>>
  _backBodyAssetMap = <String, List<String>>{
    // Rear delts are the only deltoid head shown on the back face.
    MuscleStimulus.rearDelts: <String>['assets/images/body/back_reardelt.png'],
    MuscleStimulus.upperTraps: <String>[
      'assets/images/body/back_uppertraps.png',
    ],
    // Lower traps = former middle + lower trap regions.
    MuscleStimulus.lowerTraps: <String>[
      'assets/images/body/back_middletraps.png',
      'assets/images/body/back_lowertraps.png',
    ],
    MuscleStimulus.lats: <String>[
      'assets/images/body/back_lats.png',
      'assets/images/body/back_smalllats.png',
    ],
    MuscleStimulus.triceps: <String>['assets/images/body/back_triceps.png'],
    MuscleStimulus.forearms: <String>['assets/images/body/back_forearms.png'],
    MuscleStimulus.lowerBack: <String>['assets/images/body/back_lowerback.png'],
    MuscleStimulus.glutes: <String>['assets/images/body/back_glutes.png'],
    MuscleStimulus.hipadductors: <String>[
      'assets/images/body/back_hipadductors.png',
    ],
    MuscleStimulus.quads: <String>['assets/images/body/back_quads.png'],
    MuscleStimulus.hamstrings: <String>[
      'assets/images/body/back_hamstring.png',
    ],
    MuscleStimulus.calves: <String>['assets/images/body/back_calves.png'],
  };

  static HomePageViewData map({
    required HomeDashboardData homeData,
    required MuscleVisualState muscleVisualState,
    required AppSettings settings,
    required String userName,
  }) {
    final TimePeriod currentPeriod = _resolveCurrentPeriod(muscleVisualState);
    final MuscleMapMode currentMode = _resolveCurrentMode(muscleVisualState);

    return HomePageViewData(
      greeting: '${AppStrings.hello}, $userName!',
      weekRangeLabel: WeekRangeLabelFormatter.formatForDate(
        DateTime.now(),
        weekStartDay: settings.weekStartDay,
      ),
      nutrition: _mapNutrition(dailyMacros: homeData.dailyMacros),
      progress: _mapProgress(
        weeklySetCount: homeData.weeklySetCount,
        muscleVisualState: muscleVisualState,
        currentPeriod: currentPeriod,
        currentMode: currentMode,
      ),
    );
  }

  static TimePeriod _resolveCurrentPeriod(MuscleVisualState muscleVisualState) {
    if (muscleVisualState is MuscleVisualLoaded) {
      return muscleVisualState.currentPeriod;
    }

    if (muscleVisualState is MuscleVisualLoading) {
      return muscleVisualState.period;
    }

    if (muscleVisualState is MuscleVisualError) {
      return muscleVisualState.period;
    }

    return TimePeriod.month;
  }

  static MuscleMapMode _resolveCurrentMode(
    MuscleVisualState muscleVisualState,
  ) {
    if (muscleVisualState is MuscleVisualLoaded) return muscleVisualState.mode;
    if (muscleVisualState is MuscleVisualLoading) return muscleVisualState.mode;
    if (muscleVisualState is MuscleVisualError) return muscleVisualState.mode;
    return MuscleMapMode.volume;
  }

  static HomeMacroStripViewData _mapNutrition({
    required Map<String, double> dailyMacros,
  }) {
    final double calories = dailyMacros['calories'] ?? 0;
    final double protein = dailyMacros['protein'] ?? 0;
    final double carbs = dailyMacros['carbs'] ?? 0;
    final double fats = dailyMacros['fats'] ?? 0;

    return HomeMacroStripViewData(
      caloriesLabel: calories > 0 ? '${calories.round()} kcal' : '–',
      proteinLabel: protein > 0 ? '${protein.round()} g' : '–',
      carbsLabel: carbs > 0 ? '${carbs.round()} g' : '–',
      fatsLabel: fats > 0 ? '${fats.round()} g' : '–',
    );
  }

  /// Collapses any non-user-facing [TimePeriod] to a value the period
  /// dropdown can render. The enum still carries [TimePeriod.today] (used
  /// by the use case for the daily-stimulus read path) and [TimePeriod.week]
  /// (used by the bloc to source Fatigue data), but neither is one of the
  /// dropdown's items — passing them through to [DropdownButton.value]
  /// would crash the build.
  ///
  /// Anything outside the visible set falls back to [TimePeriod.month], the
  /// dropdown's default landing option.
  static TimePeriod _coerceToVisiblePeriod(TimePeriod period) {
    switch (period) {
      case TimePeriod.month:
      case TimePeriod.allTime:
        return period;
      case TimePeriod.today:
      case TimePeriod.week:
        return TimePeriod.month;
    }
  }

  static HomeProgressCardViewData _mapProgress({
    required int weeklySetCount,
    required MuscleVisualState muscleVisualState,
    required TimePeriod currentPeriod,
    required MuscleMapMode currentMode,
  }) {
    final TimePeriod displayPeriod = _coerceToVisiblePeriod(currentPeriod);
    final bool selectorEnabled = muscleVisualState is! MuscleVisualLoading;
    final bool showPeriodSelector = currentMode == MuscleMapMode.volume;

    final String cardTitle = currentMode == MuscleMapMode.fatigue
        ? 'Muscle Fatigue'
        : '${AppStrings.progress} • ${_periodLabel(displayPeriod)}';

    final HomeBodyVisualViewData emptyVisual = HomeBodyVisualViewData(
      frontLayers: const <HomeBodyOverlayViewData>[],
      backLayers: const <HomeBodyOverlayViewData>[],
      subtitle: _bodySubtitle(hasHighlights: false, mode: currentMode),
    );

    if (muscleVisualState is MuscleVisualLoading ||
        muscleVisualState is MuscleVisualInitial) {
      return HomeProgressCardViewData(
        title: cardTitle,
        selectedPeriod: displayPeriod,
        selectorEnabled: selectorEnabled,
        showPeriodSelector: showPeriodSelector,
        muscleMapMode: currentMode,
        bodyVisual: emptyVisual,
        muscleSummary: const <HomeMuscleSummaryItemViewData>[],
        isLoading: true,
        errorMessage: null,
      );
    }

    if (muscleVisualState is MuscleVisualError) {
      return HomeProgressCardViewData(
        title: cardTitle,
        selectedPeriod: displayPeriod,
        selectorEnabled: selectorEnabled,
        showPeriodSelector: showPeriodSelector,
        muscleMapMode: currentMode,
        bodyVisual: emptyVisual,
        muscleSummary: const <HomeMuscleSummaryItemViewData>[],
        isLoading: false,
        errorMessage: muscleVisualState.message,
      );
    }

    final MuscleVisualLoaded loaded = muscleVisualState as MuscleVisualLoaded;

    final List<MuscleVisualData> trained =
        loaded.muscleData.values
            .where(
              (MuscleVisualData item) =>
                  item.hasTrained && item.totalStimulus > 0,
            )
            .toList()
          ..sort(
            (MuscleVisualData a, MuscleVisualData b) =>
                b.totalStimulus.compareTo(a.totalStimulus),
          );

    final HomeBodyVisualViewData bodyVisual = _mapBodyVisual(
      loaded.muscleData,
      mode: currentMode,
    );

    return HomeProgressCardViewData(
      title: cardTitle,
      selectedPeriod: displayPeriod,
      selectorEnabled: selectorEnabled,
      showPeriodSelector: showPeriodSelector,
      muscleMapMode: currentMode,
      bodyVisual: bodyVisual,
      muscleSummary: trained
          .take(6)
          .map(
            (MuscleVisualData item) => HomeMuscleSummaryItemViewData(
              displayName: item.displayName,
              stimulusLabel: item.totalStimulus.toStringAsFixed(0),
              intensityLabel: item.intensityLevel,
              color: item.color,
            ),
          )
          .toList(growable: false),
      isLoading: false,
      errorMessage: null,
    );
  }

  static HomeBodyVisualViewData _mapBodyVisual(
    Map<String, MuscleVisualData> muscleData, {
    required MuscleMapMode mode,
  }) {
    final Map<String, HomeBodyOverlayViewData> frontLayers =
        <String, HomeBodyOverlayViewData>{};
    final Map<String, HomeBodyOverlayViewData> backLayers =
        <String, HomeBodyOverlayViewData>{};

    for (final MuscleVisualData item in muscleData.values) {
      if (!item.hasTrained || item.overlayOpacity <= 0) {
        continue;
      }

      for (final String assetPath
          in _frontBodyAssetMap[item.muscleGroup] ?? const <String>[]) {
        _mergeOverlay(frontLayers, assetPath: assetPath, item: item);
      }

      for (final String assetPath
          in _backBodyAssetMap[item.muscleGroup] ?? const <String>[]) {
        _mergeOverlay(backLayers, assetPath: assetPath, item: item);
      }
    }

    final bool hasHighlights = frontLayers.isNotEmpty || backLayers.isNotEmpty;

    return HomeBodyVisualViewData(
      frontLayers: frontLayers.values.toList(growable: false),
      backLayers: backLayers.values.toList(growable: false),
      subtitle: _bodySubtitle(hasHighlights: hasHighlights, mode: mode),
    );
  }

  static String _bodySubtitle({
    required bool hasHighlights,
    required MuscleMapMode mode,
  }) {
    if (mode == MuscleMapMode.fatigue) {
      return hasHighlights
          ? 'Current fatigue level'
          : 'Muscles fully recovered';
    }
    return hasHighlights ? 'Front and back load' : 'No training load yet';
  }

  static void _mergeOverlay(
    Map<String, HomeBodyOverlayViewData> target, {
    required String assetPath,
    required MuscleVisualData item,
  }) {
    final HomeBodyOverlayViewData candidate = HomeBodyOverlayViewData(
      assetPath: assetPath,
      color: item.color,
      opacity: item.overlayOpacity,
      label: item.displayName,
    );

    final HomeBodyOverlayViewData? existing = target[assetPath];
    if (existing == null || candidate.opacity >= existing.opacity) {
      target[assetPath] = candidate;
    }
  }

  static String _periodLabel(TimePeriod period) {
    switch (period) {
      case TimePeriod.today:
        return AppStrings.periodToday;
      case TimePeriod.week:
        return AppStrings.periodWeek;
      case TimePeriod.month:
        return AppStrings.periodMonth;
      case TimePeriod.allTime:
        return AppStrings.periodAllTime;
    }
  }
}
