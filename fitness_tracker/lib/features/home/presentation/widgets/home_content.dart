import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/entities/time_period.dart';
import '../../../../presentation/widgets/macro_composition_bar.dart';
import '../../application/muscle_visual_bloc.dart' show MuscleMapMode;
import '../home_page_keys.dart';
import '../models/home_view_data.dart';
import 'body_visual_widget.dart';
import 'period_selector_widget.dart';

/// Horizontal page gutter. The two section rules deliberately sit *outside*
/// it so they run edge to edge (`export/01-home.png`).
const double _gutter = 20;

/// Height below which the page stops shrinking the muscle map and starts
/// scrolling instead. Chosen so an 800dp phone at normal text scale is
/// unaffected — the viewport wins and nothing scrolls.
const double _minPageHeight = 640;

/// Home, built around the 2D muscle map.
///
/// The map is the screen: everything else is a header above it and an intake
/// row below it, separated by full-bleed rules. Nothing here is a `Card` and
/// nothing takes an opaque background — the two-tone ground shows through.
class HomeContent extends StatelessWidget {
  const HomeContent({
    super.key,
    required this.viewData,
    required this.onRefresh,
    required this.onPeriodChanged,
    required this.onRetryVisuals,
    required this.onModeChanged,
  });

  final HomePageViewData viewData;
  final Future<void> Function() onRefresh;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final VoidCallback onRetryVisuals;
  final ValueChanged<MuscleMapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // Accent-as-foreground: the spinner is a mark, not a filled surface.
      color: LiftColors.actionTint,
      onRefresh: onRefresh,
      // `BodyVisualWidget` contains an `Expanded`, so the muscle-map section
      // must be given a bounded height — which means the `Column` needs a
      // tight one. `SizedBox(height: viewport)` is that bound: `Expanded`
      // then distributes exactly the slack the header, rules and intake row
      // leave behind, and the figure letterboxes inside it.
      //
      // Do not go back to `ConstrainedBox(minHeight:)` + `IntrinsicHeight`.
      // `IntrinsicHeight` sizes the column to `computeMaxIntrinsicHeight`,
      // and `RenderAspectRatio` answers that with `width / aspectRatio` — so
      // the figure's height would be derived from the content *width*, the
      // column would outgrow the screen, and `Expanded` would bound nothing.
      //
      // Scroll extent is therefore 0 by design at normal text scale;
      // `AlwaysScrollableScrollPhysics` is what keeps the pull-to-refresh
      // drag alive on a view that does not overflow.
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // The scroll child is normally exactly viewport-tall: that tight
          // height is what lets the muscle map's `Expanded` take the slack,
          // and it keeps `maxScrollExtent` at 0 so the screen matches
          // frame 01 with no scrollbar. But `Expanded` floors at 0, not at
          // something readable, so when the fixed chrome grows —
          // accessibility text scaling, a short window — the page has to be
          // allowed to outgrow the viewport and scroll rather than
          // overflow. The chrome is all text, so it grows with the text
          // scaler and the floor does too.
          final double scaledFloor =
              _minPageHeight * MediaQuery.textScalerOf(context).scale(1);
          return SingleChildScrollView(
            key: HomePageKeys.refreshListKey,
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: math.max(constraints.maxHeight, scaledFloor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _HeaderSection(viewData: viewData),
                  const _SectionRule(key: HomePageKeys.headerRuleKey),
                  Expanded(
                    child: _MuscleMapSection(
                      viewData: viewData.progress,
                      onPeriodChanged: onPeriodChanged,
                      onRetryVisuals: onRetryVisuals,
                      onModeChanged: onModeChanged,
                    ),
                  ),
                  const _SectionRule(key: HomePageKeys.intakeRuleKey),
                  _IntakeSection(viewData: viewData.nutrition),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Full-bleed hairline. Carries no horizontal padding on purpose — it runs
/// the whole screen width while every other block is inset to the gutter.
class _SectionRule extends StatelessWidget {
  const _SectionRule({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: LiftShape.borderWidth, color: LiftColors.rule);
  }
}

/// Week range over greeting — the range reads first, the way a log book's
/// page number does.
class _HeaderSection extends StatelessWidget {
  const _HeaderSection({required this.viewData});

  final HomePageViewData viewData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            viewData.weekRangeLabel.toUpperCase(),
            style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
          ),
          const SizedBox(height: 6),
          Text(
            viewData.greeting,
            style: LiftText.headlineLarge.copyWith(
              color: LiftColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title + mode toggle over the muscle map, which takes every dp of
/// vertical space the header and intake row leave behind.
class _MuscleMapSection extends StatelessWidget {
  const _MuscleMapSection({
    required this.viewData,
    required this.onPeriodChanged,
    required this.onRetryVisuals,
    required this.onModeChanged,
  });

  final HomeProgressCardViewData viewData;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final VoidCallback onRetryVisuals;
  final ValueChanged<MuscleMapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 14, _gutter, 16),
      child: Column(
        key: HomePageKeys.progressCardKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              // One flex child, no `Spacer`. A `Flexible` title next to a
              // `Spacer` would split the free width evenly and ellipsize
              // `MUSCLE FATIGUE` at roughly half the room it needs.
              Expanded(
                child: Text(
                  viewData.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: LiftText.labelLarge.copyWith(
                    color: LiftColors.textStrong,
                  ),
                ),
              ),
              _MuscleMapModeToggle(
                currentMode: viewData.muscleMapMode,
                onModeChanged: onModeChanged,
              ),
            ],
          ),
          // Period selector is volume-mode only — fatigue is always "now".
          if (viewData.showPeriodSelector) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: PeriodSelectorWidget(
                selectedPeriod: viewData.selectedPeriod,
                onPeriodChanged: onPeriodChanged,
                enabled: viewData.selectorEnabled,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (viewData.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          key: HomePageKeys.progressLoadingIndicatorKey,
          color: LiftColors.actionTint,
        ),
      );
    }

    final String? errorMessage = viewData.errorMessage;
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: LiftColors.error, size: 40),
            const SizedBox(height: 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: HomePageKeys.progressRetryButtonKey,
              onPressed: onRetryVisuals,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.tryAgain),
            ),
          ],
        ),
      );
    }

    return BodyVisualWidget(viewData: viewData.bodyVisual);
  }
}

/// `TODAY · INTAKE`: four left-aligned columns over the macro composition bar.
class _IntakeSection extends StatelessWidget {
  const _IntakeSection({required this.viewData});

  final HomeMacroStripViewData viewData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 16, _gutter, 16),
      child: Column(
        key: HomePageKeys.macroStripKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TODAY · INTAKE',
            style: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _IntakeColumn(
                  // KCAL is a spaced label, so the calorie count is a plain
                  // mono value — a glued `LiftNumber` unit would read `2792kcal`.
                  value: Text(
                    viewData.calories.round().toString(),
                    style: LiftText.dataMedium.copyWith(
                      color: LiftColors.textPrimary,
                    ),
                  ),
                  label: 'KCAL',
                ),
              ),
              Expanded(
                child: _IntakeColumn(
                  value: LiftNumber(
                    viewData.proteinGrams.round().toString(),
                    'g',
                    LiftText.dataMedium,
                  ),
                  label: 'PROTEIN',
                ),
              ),
              Expanded(
                child: _IntakeColumn(
                  value: LiftNumber(
                    viewData.carbsGrams.round().toString(),
                    'g',
                    LiftText.dataMedium,
                  ),
                  label: 'CARBS',
                ),
              ),
              Expanded(
                child: _IntakeColumn(
                  value: LiftNumber(
                    viewData.fatsGrams.round().toString(),
                    'g',
                    LiftText.dataMedium,
                  ),
                  label: 'FATS',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Real macro colours, not frame 01's greyscale mock: a *macro*
          // composition bar drawn in non-macro colours carries no
          // information. Percentages are off here because the three gram
          // values are already spelled out immediately above the bar.
          Semantics(
            label: 'Today macro composition',
            child: MacroCompositionBar(
              proteinGrams: viewData.proteinGrams,
              carbsGrams: viewData.carbsGrams,
              fatsGrams: viewData.fatsGrams,
              showPercentages: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntakeColumn extends StatelessWidget {
  const _IntakeColumn({required this.value, required this.label});

  final Widget value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        value,
        const SizedBox(height: 4),
        Text(
          label,
          style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
        ),
      ],
    );
  }
}

/// Two-segment toggle between [MuscleMapMode.volume] (training load over the
/// selected period) and [MuscleMapMode.fatigue] (accumulated fatigue now).
///
/// Square, iconless, and untransitioned: the selected fill runs to the inner
/// edge of the frame with no gutter, matching the Log tab underline's
/// no-animation call from PR B2.
///
/// The frame's 26 dp height is below the 44 dp minimum touch target enforced
/// elsewhere in this project. That is a deliberate, owner-approved trade —
/// the screens match the frames — and each segment is still roughly
/// 66x26 dp.
class _MuscleMapModeToggle extends StatelessWidget {
  const _MuscleMapModeToggle({
    required this.currentMode,
    required this.onModeChanged,
  });

  final MuscleMapMode currentMode;
  final ValueChanged<MuscleMapMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: LiftColors.surface,
        border: Border.fromBorderSide(
          BorderSide(color: LiftColors.border, width: LiftShape.borderWidth),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTab(MuscleMapMode.volume),
          _buildTab(MuscleMapMode.fatigue),
        ],
      ),
    );
  }

  Widget _buildTab(MuscleMapMode mode) {
    final bool isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        // `actionFill` is a fill under a white label — never a foreground.
        color: isSelected ? LiftColors.actionFill : Colors.transparent,
        child: Text(
          mode.name.toUpperCase(),
          style: LiftText.labelLarge.copyWith(
            color: isSelected ? Colors.white : LiftColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
