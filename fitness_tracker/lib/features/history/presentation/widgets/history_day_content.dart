import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../presentation/shared/widgets/collapsible_section.dart';
import '../../../library/application/exercise_bloc.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../helpers/history_nutrition_summary_builder.dart';
import '../helpers/history_workout_summary_builder.dart';
import '../../../../presentation/widgets/history_log_bottom_sheets.dart';
import 'edit_nutrition_log_dialog.dart';
import 'edit_set_dialog.dart';

// Stable IDs used for persisting collapsed/expanded state in AppSettings.
const String _kWorkoutSectionId = 'history.workout';
const String _kNutritionSectionId = 'history.nutrition';

class HistoryDayContent extends StatefulWidget {
  final DateTime? selectedDate;
  final List<WorkoutSet> workoutSets;
  final List<NutritionLog> nutritionLogs;
  final WeightUnit weightUnit;
  final VoidCallback onClearSelection;
  final int highlightVersion;

  const HistoryDayContent({
    super.key,
    required this.selectedDate,
    required this.workoutSets,
    required this.nutritionLogs,
    required this.weightUnit,
    required this.onClearSelection,
    this.highlightVersion = 0,
  });

  @override
  State<HistoryDayContent> createState() => _HistoryDayContentState();
}

class _HistoryDayContentState extends State<HistoryDayContent> {
  bool _isHighlighted = false;
  Timer? _highlightResetTimer;

  /// Muscle filter for the workout section. `null` = show all muscles.
  String? _selectedMuscleFilter;

  @override
  void didUpdateWidget(covariant HistoryDayContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    final bool shouldTriggerHighlight =
        widget.highlightVersion != oldWidget.highlightVersion &&
        widget.selectedDate != null;

    if (shouldTriggerHighlight) {
      _triggerHighlight();
    }

    // Reset the filter when the selected date changes.
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedMuscleFilter = null;
    }
  }

  @override
  void dispose() {
    _highlightResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDate == null) {
      return const _SelectionHint(
        icon: Icons.touch_app_outlined,
        message: 'Select a day to view workouts and nutrition history.',
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isHighlighted
            ? AppTheme.primaryOrange.withValues(alpha: 0.06)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isHighlighted
              ? AppTheme.primaryOrange.withValues(alpha: 0.35)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SelectedDayStrip(
            date: widget.selectedDate!,
            setCount: widget.workoutSets.length,
            entryCount: widget.nutritionLogs.length,
            nutritionLogs: widget.nutritionLogs,
            onClearSelection: widget.onClearSelection,
          ),
          const SizedBox(height: 16),
          _WorkoutHistorySection(
            date: widget.selectedDate!,
            sets: widget.workoutSets,
            weightUnit: widget.weightUnit,
            muscleFilter: _selectedMuscleFilter,
            onMuscleFilterChanged: (String? muscle) {
              setState(() => _selectedMuscleFilter = muscle);
            },
          ),
          const SizedBox(height: 16),
          _NutritionHistorySection(
            date: widget.selectedDate!,
            logs: widget.nutritionLogs,
          ),
        ],
      ),
    );
  }

  void _triggerHighlight() {
    _highlightResetTimer?.cancel();

    setState(() {
      _isHighlighted = true;
    });

    _highlightResetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _isHighlighted = false);
    });
  }
}

// ---------------------------------------------------------------------------
// Slim day strip
// ---------------------------------------------------------------------------

class _SelectedDayStrip extends StatelessWidget {
  final DateTime date;
  final int setCount;
  final int entryCount;
  final List<NutritionLog> nutritionLogs;
  final VoidCallback onClearSelection;

  const _SelectedDayStrip({
    required this.date,
    required this.setCount,
    required this.entryCount,
    required this.nutritionLogs,
    required this.onClearSelection,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('EEE, MMM d').format(date);
    final int totalKcal = nutritionLogs.fold<int>(
      0,
      (int acc, NutritionLog log) => acc + log.calories.round(),
    );

    final StringBuffer summary = StringBuffer(formattedDate);
    if (setCount > 0)
      summary.write(' · $setCount set${setCount == 1 ? '' : 's'}');
    if (entryCount > 0) {
      summary.write(' · $entryCount entr${entryCount == 1 ? 'y' : 'ies'}');
    }
    if (totalKcal > 0) summary.write(' · $totalKcal kcal');

    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            summary.toString(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMedium,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onClearSelection,
          icon: const Icon(Icons.close, size: 18),
          tooltip: 'Clear selected day',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Workout history section
// ---------------------------------------------------------------------------

class _WorkoutHistorySection extends StatelessWidget {
  final DateTime date;
  final List<WorkoutSet> sets;
  final WeightUnit weightUnit;
  final String? muscleFilter;
  final ValueChanged<String?> onMuscleFilterChanged;

  const _WorkoutHistorySection({
    required this.date,
    required this.sets,
    required this.weightUnit,
    required this.muscleFilter,
    required this.onMuscleFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExerciseBloc, ExerciseState>(
      builder: (BuildContext context, ExerciseState exerciseState) {
        final Map<String, Exercise> exerciseMap =
            exerciseState is ExercisesLoaded
            ? <String, Exercise>{
                for (final Exercise e in exerciseState.exercises) e.id: e,
              }
            : const <String, Exercise>{};

        final HistoryWorkoutSummary summary =
            HistoryWorkoutSummaryBuilder.build(
              sets: sets,
              exerciseById: exerciseMap,
            );

        final List<WorkoutSet> filteredSets = muscleFilter == null
            ? sets
            : sets.where((WorkoutSet s) {
                final Exercise? ex = exerciseMap[s.exerciseId];
                return ex != null && ex.muscleGroups.contains(muscleFilter);
              }).toList();

        return CollapsibleSection(
          id: _kWorkoutSectionId,
          icon: Icons.fitness_center,
          title: 'Workout history',
          subtitle: '${sets.length} set${sets.length == 1 ? '' : 's'} logged',
          onAddPressed: () =>
              showHistoryWorkoutLogBottomSheet(context, selectedDate: date),
          addTooltip: 'Add workout set',
          headerTrailing: summary.muscleCounts.isEmpty
              ? null
              : _WorkoutSummaryChipRow(summary: summary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (sets.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                _MuscleFilterChips(
                  selectedMuscle: muscleFilter,
                  onChanged: onMuscleFilterChanged,
                ),
                const SizedBox(height: 12),
              ],
              _buildContent(context, exerciseMap, filteredSets),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, Exercise> exerciseMap,
    List<WorkoutSet> filteredSets,
  ) {
    if (sets.isEmpty) {
      return _InlineEmptyHint(
        icon: Icons.fitness_center_outlined,
        title: 'No workouts on this day',
        message: 'Try another date or add a workout for this day.',
        ctaLabel: 'Log workout for ${DateFormat('MMM d').format(date)}',
        onPressed: () =>
            showHistoryWorkoutLogBottomSheet(context, selectedDate: date),
      );
    }

    if (exerciseMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (filteredSets.isEmpty) {
      return const _InlineEmptyHint(
        icon: Icons.search_off,
        title: 'No sets match this filter',
        message: 'Try a different muscle group or clear the filter.',
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < filteredSets.length; i++) ...<Widget>[
          if (exerciseMap.containsKey(filteredSets[i].exerciseId))
            _WorkoutSetCard(
              set: filteredSets[i],
              exercise: exerciseMap[filteredSets[i].exerciseId]!,
              weightUnit: weightUnit,
            )
          else
            _OrphanedWorkoutSetCard(
              set: filteredSets[i],
              weightUnit: weightUnit,
            ),
          if (i < filteredSets.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _WorkoutSummaryChipRow extends StatefulWidget {
  const _WorkoutSummaryChipRow({required this.summary});

  final HistoryWorkoutSummary summary;

  @override
  State<_WorkoutSummaryChipRow> createState() => _WorkoutSummaryChipRowState();
}

class _WorkoutSummaryChipRowState extends State<_WorkoutSummaryChipRow> {
  static const int _visibleLimit = 4;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final List<HistoryMuscleCount> counts = widget.summary.muscleCounts;
    final bool hasMore = counts.length > _visibleLimit;
    final List<HistoryMuscleCount> visible = _expanded
        ? counts
        : counts.take(_visibleLimit).toList();
    final int hiddenCount = counts.length - _visibleLimit;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        ...visible.map(
          (HistoryMuscleCount mc) => _SummaryChip(
            label: mc.displayName,
            value: '×${mc.directSetCount}',
          ),
        ),
        if (hasMore && !_expanded)
          GestureDetector(
            onTap: () => setState(() => _expanded = true),
            child: _SummaryChip(
              label: '+$hiddenCount more',
              value: '',
              dimmed: true,
            ),
          ),
      ],
    );
  }
}

class _MuscleFilterChips extends StatelessWidget {
  final String? selectedMuscle;
  final ValueChanged<String?> onChanged;

  const _MuscleFilterChips({
    required this.selectedMuscle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Text('All'),
              selected: selectedMuscle == null,
              onSelected: (_) => onChanged(null),
              visualDensity: VisualDensity.compact,
            ),
          ),
          ...MuscleGroups.all.map(
            (String muscle) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(MuscleGroups.getDisplayName(muscle)),
                selected: selectedMuscle == muscle,
                onSelected: (_) =>
                    onChanged(selectedMuscle == muscle ? null : muscle),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nutrition history section
// ---------------------------------------------------------------------------

class _NutritionHistorySection extends StatelessWidget {
  final DateTime date;
  final List<NutritionLog> logs;

  const _NutritionHistorySection({required this.date, required this.logs});

  @override
  Widget build(BuildContext context) {
    final summary = HistoryNutritionSummaryBuilder.buildSummary(logs);

    return CollapsibleSection(
      id: _kNutritionSectionId,
      icon: Icons.restaurant_menu,
      title: 'Nutrition history',
      subtitle: '${logs.length} entr${logs.length == 1 ? 'y' : 'ies'} logged',
      onAddPressed: () =>
          showHistoryNutritionTypeBottomSheet(context, selectedDate: date),
      addTooltip: 'Add nutrition entry',
      headerTrailing: logs.isEmpty
          ? null
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.metrics
                  .map(
                    (HistoryNutritionMetricViewData metric) =>
                        _SummaryChip(label: metric.label, value: metric.value),
                  )
                  .toList(growable: false),
            ),
      child: logs.isEmpty
          ? _InlineEmptyHint(
              icon: Icons.restaurant_outlined,
              title: 'No nutrition on this day',
              message: 'Try another date or add nutrition for this day.',
              ctaLabel: 'Log nutrition for ${DateFormat('MMM d').format(date)}',
              onPressed: () => showHistoryNutritionTypeBottomSheet(
                context,
                selectedDate: date,
              ),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < logs.length; i++) ...<Widget>[
                  _NutritionLogCard(log: logs[i]),
                  if (i < logs.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Workout set card
// ---------------------------------------------------------------------------

class _WorkoutSetCard extends StatelessWidget {
  final WorkoutSet set;
  final Exercise exercise;
  final WeightUnit weightUnit;

  const _WorkoutSetCard({
    required this.set,
    required this.exercise,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final String muscleLabel = exercise.muscleGroups
        .map(MuscleGroups.getDisplayName)
        .join(', ');

    final String displayWeight = WeightUnitUtils.formatForDisplay(
      set.weight,
      weightUnit,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    exercise.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditDialog(context),
                  tooltip: 'Edit set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context, displayWeight),
                  tooltip: 'Delete set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetricChip(icon: Icons.repeat, label: '${set.reps} reps'),
                _MetricChip(icon: Icons.fitness_center, label: displayWeight),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              muscleLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<HistoryBloc>(),
        child: EditSetDialog(
          workoutSet: set,
          exercise: exercise,
          weightUnit: weightUnit,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String displayWeight) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Set?'),
        content: Text(
          'Remove ${exercise.name} - ${set.reps} reps @ $displayWeight?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(DeleteSetEvent(set.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Orphaned workout set card (exercise was deleted from library)
// ---------------------------------------------------------------------------

class _OrphanedWorkoutSetCard extends StatelessWidget {
  final WorkoutSet set;
  final WeightUnit weightUnit;

  const _OrphanedWorkoutSetCard({required this.set, required this.weightUnit});

  @override
  Widget build(BuildContext context) {
    final String displayWeight = WeightUnitUtils.formatForDisplay(
      set.weight,
      weightUnit,
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.link_off, size: 16, color: AppTheme.textMedium),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Unknown exercise',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMedium,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context, displayWeight),
                  tooltip: 'Delete set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetricChip(icon: Icons.repeat, label: '${set.reps} reps'),
                _MetricChip(icon: Icons.fitness_center, label: displayWeight),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String displayWeight) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Set?'),
        content: Text('Remove ${set.reps} reps @ $displayWeight?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(DeleteSetEvent(set.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nutrition log card
// ---------------------------------------------------------------------------

class _NutritionLogCard extends StatelessWidget {
  final NutritionLog log;

  const _NutritionLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final String time = DateFormat('HH:mm').format(log.loggedAt);
    final macros = HistoryNutritionSummaryBuilder.buildLogMacros(log);
    final String? consumedGramsLabel =
        HistoryNutritionSummaryBuilder.buildConsumedGramsLabel(log);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  log.isMealLog ? Icons.restaurant : Icons.calculate,
                  color: AppTheme.primaryOrange,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    log.mealName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textDim),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditDialog(context),
                  tooltip: 'Edit nutrition log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context),
                  tooltip: 'Delete nutrition log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (consumedGramsLabel != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  consumedGramsLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MacroChip(label: 'P', value: macros.proteinLabel),
                _MacroChip(label: 'C', value: macros.carbsLabel),
                _MacroChip(label: 'F', value: macros.fatsLabel),
                _MacroChip(label: 'Kcal', value: macros.caloriesLabel),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<HistoryBloc>(),
        child: EditNutritionLogDialog(log: log),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Nutrition Log?'),
        content: Text('Remove "${log.mealName}" from history?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(
                DeleteNutritionHistoryLogEvent(log.id),
              );
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small chip widgets
// ---------------------------------------------------------------------------

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetricChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: AppTheme.primaryOrange),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.primaryOrange,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final bool dimmed;

  const _SummaryChip({
    required this.label,
    required this.value,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = dimmed
        ? AppTheme.borderDark
        : AppTheme.primaryOrange.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: value.isEmpty
          ? Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textDim,
                fontWeight: FontWeight.w500,
              ),
            )
          : RichText(
              text: TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppTheme.textMedium,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;

  const _MacroChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppTheme.primaryOrange,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hint cards
// ---------------------------------------------------------------------------

class _SelectionHint extends StatelessWidget {
  final IconData icon;
  final String message;

  const _SelectionHint({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return _HintCard(icon: icon, title: 'No day selected', message: message);
  }
}

class _InlineEmptyHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onPressed;

  const _InlineEmptyHint({
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _HintCard(
      icon: icon,
      title: title,
      message: message,
      ctaLabel: ctaLabel,
      onPressed: onPressed,
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? ctaLabel;
  final VoidCallback? onPressed;

  const _HintCard({
    required this.icon,
    required this.title,
    required this.message,
    this.ctaLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, color: AppTheme.textDim),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMedium),
                ),
                if (ctaLabel != null && onPressed != null) ...<Widget>[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onPressed,
                    icon: const Icon(Icons.add),
                    label: Text(ctaLabel!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
