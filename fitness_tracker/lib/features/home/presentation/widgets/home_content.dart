import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/time_period.dart';
import '../../application/muscle_visual_bloc.dart' show MuscleMapMode;
import '../home_page_keys.dart';
import '../models/home_view_data.dart';
import 'body_visual_widget.dart';
import 'period_selector_widget.dart';

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
      color: AppTheme.primaryOrange,
      onRefresh: onRefresh,
      child: ListView(
        key: HomePageKeys.refreshListKey,
        padding: const EdgeInsets.all(20),
        children: <Widget>[
          _GreetingSection(viewData: viewData),
          const SizedBox(height: 16),
          _ProgressCard(
            viewData: viewData.progress,
            onPeriodChanged: onPeriodChanged,
            onRetryVisuals: onRetryVisuals,
            onModeChanged: onModeChanged,
          ),
          const SizedBox(height: 16),
          _MacroStrip(viewData: viewData.nutrition),
        ],
      ),
    );
  }
}

class _GreetingSection extends StatelessWidget {
  const _GreetingSection({required this.viewData});

  final HomePageViewData viewData;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          viewData.greeting,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          viewData.weekRangeLabel,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppTheme.textMedium),
        ),
      ],
    );
  }
}

/// Four-tile macro summary card.
///
/// ≥ 360 dp wide  → single `Row` of four `Expanded` tiles.
/// < 360 dp wide  → 2×2 grid (Calories + Protein on row one, Carbs + Fats
///                  on row two) so values stay readable on very narrow screens.
class _MacroStrip extends StatelessWidget {
  const _MacroStrip({required this.viewData});

  final HomeMacroStripViewData viewData;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: HomePageKeys.macroStripKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth >= 360) {
              return _buildWideRow(context);
            }
            return _buildNarrowGrid(context);
          },
        ),
      ),
    );
  }

  Widget _buildWideRow(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _MacroTile(
              label: AppStrings.calories,
              value: viewData.caloriesLabel,
            ),
          ),
          const VerticalDivider(color: AppTheme.borderDark, width: 1),
          Expanded(
            child: _MacroTile(
              label: AppStrings.protein,
              value: viewData.proteinLabel,
            ),
          ),
          const VerticalDivider(color: AppTheme.borderDark, width: 1),
          Expanded(
            child: _MacroTile(
              label: AppStrings.carbs,
              value: viewData.carbsLabel,
            ),
          ),
          const VerticalDivider(color: AppTheme.borderDark, width: 1),
          Expanded(
            child: _MacroTile(
              label: AppStrings.fats,
              value: viewData.fatsLabel,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowGrid(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _MacroTile(
                label: AppStrings.calories,
                value: viewData.caloriesLabel,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _MacroTile(
                label: AppStrings.protein,
                value: viewData.proteinLabel,
              ),
            ),
          ],
        ),
        const Divider(color: AppTheme.borderDark, height: 1),
        Row(
          children: <Widget>[
            Expanded(
              child: _MacroTile(
                label: AppStrings.carbs,
                value: viewData.carbsLabel,
              ),
            ),
            const SizedBox(width: 1),
            Expanded(
              child: _MacroTile(
                label: AppStrings.fats,
                value: viewData.fatsLabel,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.primaryOrange,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
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
    return Card(
      key: HomePageKeys.progressCardKey,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ── Header row: icon + title + mode toggle ──────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.analytics,
                    color: AppTheme.primaryOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    viewData.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _MuscleMapModeToggle(
                  currentMode: viewData.muscleMapMode,
                  onModeChanged: onModeChanged,
                ),
              ],
            ),
            // ── Period selector (volume mode only) ───────────────────────
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
            const SizedBox(height: 20),
            if (viewData.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: CircularProgressIndicator(
                    key: HomePageKeys.progressLoadingIndicatorKey,
                    color: AppTheme.primaryOrange,
                  ),
                ),
              )
            else if (viewData.errorMessage != null)
              Column(
                children: <Widget>[
                  const Icon(
                    Icons.error_outline,
                    color: AppTheme.errorRed,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    viewData.errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    key: HomePageKeys.progressRetryButtonKey,
                    onPressed: onRetryVisuals,
                    icon: const Icon(Icons.refresh),
                    label: const Text(AppStrings.tryAgain),
                  ),
                ],
              )
            else ...<Widget>[
              BodyVisualWidget(viewData: viewData.bodyVisual),
              const SizedBox(height: 16),
              ...viewData.muscleSummary.map(
                (HomeMuscleSummaryItemViewData item) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderDark),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.displayName,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${item.stimulusLabel} • ${item.intensityLabel}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact two-segment toggle that lets the user switch between
/// [MuscleMapMode.volume] (training load for the selected period) and
/// [MuscleMapMode.fatigue] (current accumulated fatigue / rolling weekly load).
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
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildTab(
            context,
            label: 'Volume',
            icon: Icons.bar_chart_rounded,
            mode: MuscleMapMode.volume,
          ),
          _buildTab(
            context,
            label: 'Fatigue',
            icon: Icons.local_fire_department_rounded,
            mode: MuscleMapMode.fatigue,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required String label,
    required IconData icon,
    required MuscleMapMode mode,
  }) {
    final bool isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () => onModeChanged(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppTheme.textDim,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textDim,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
