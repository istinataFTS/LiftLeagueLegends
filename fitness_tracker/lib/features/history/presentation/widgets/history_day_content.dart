import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../presentation/shared/widgets/collapsible_section.dart';
import '../../../../presentation/shared/widgets/macro_label.dart';
import '../../../library/application/exercise_bloc.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../helpers/history_workout_summary_builder.dart';
import '../../../../presentation/widgets/history_log_bottom_sheets.dart';
import '../history_strings.dart';
import 'edit_nutrition_log_dialog.dart';
import 'edit_set_dialog.dart';

// Stable IDs used for persisting collapsed/expanded state in AppSettings.
const String _kWorkoutSectionId = 'history.workout';
const String _kNutritionSectionId = 'history.nutrition';

const double _gutter = 20;

/// The day panel below the History calendar, rebuilt from frames 09
/// (`09-history-workout-expanded.png`) and 10
/// (`10-history-nutrition-expanded.png`) of the Deep Mist export. The export
/// lives outside this repository and is not checked in.
///
/// ### Controls the frames do not draw, and where their function went
///
/// The pre-restyle version of this file painted a `+` in each section header,
/// an edit and a delete [IconButton] on every row, and an `x` on the day
/// strip. None of the three frames shows any of them — the rows are bare, and
/// the section headers carry nothing but two lines of text. Frames 09 and 10
/// are captioned "edit and delete per row" and "add from the section header",
/// which contradicts their own pixels; the pixels win, because that is what
/// this restyle was asked to reproduce.
///
/// Every one of those functions is still reachable, moved onto a gesture the
/// row already had spare:
///
///  * **edit** — tap the row.
///  * **delete** — long-press the row, which opens the same confirmation
///    dialog the trash icon used to.
///  * **add for this day** — the empty-state call to action, which the frames
///    never show (they only show days with data) and which is therefore free
///    to keep a visible button.
///
/// The highlight flash that used to draw a rounded orange border around the
/// whole panel when the selection changed is gone with the radius it depended
/// on; the day strip is the thing that changes, and it changes visibly.
class HistoryDayContent extends StatefulWidget {
  final DateTime? selectedDate;
  final List<WorkoutSet> workoutSets;
  final List<NutritionLog> nutritionLogs;
  final WeightUnit weightUnit;

  const HistoryDayContent({
    super.key,
    required this.selectedDate,
    required this.workoutSets,
    required this.nutritionLogs,
    required this.weightUnit,
  });

  @override
  State<HistoryDayContent> createState() => _HistoryDayContentState();
}

class _HistoryDayContentState extends State<HistoryDayContent> {
  /// Muscle filter for the workout section. `null` = show all muscles.
  String? _selectedMuscleFilter;

  @override
  void didUpdateWidget(covariant HistoryDayContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset the filter when the selected date changes.
    if (widget.selectedDate != oldWidget.selectedDate) {
      _selectedMuscleFilter = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedDate == null) {
      return const _NoDaySelected();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SelectedDayStrip(
          date: widget.selectedDate!,
          setCount: widget.workoutSets.length,
          entryCount: widget.nutritionLogs.length,
          nutritionLogs: widget.nutritionLogs,
        ),
        _WorkoutHistorySection(
          date: widget.selectedDate!,
          sets: widget.workoutSets,
          weightUnit: widget.weightUnit,
          muscleFilter: _selectedMuscleFilter,
          onMuscleFilterChanged: (String? muscle) {
            setState(() => _selectedMuscleFilter = muscle);
          },
        ),
        _NutritionHistorySection(
          date: widget.selectedDate!,
          logs: widget.nutritionLogs,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Selected day strip
// ---------------------------------------------------------------------------

/// `SAT · AUG 8   3 SETS · 4 ENTRIES · 2792 KCAL`.
///
/// The date reads in [LiftText.dataMeta] at full strength and the counts in
/// dim letterspaced mono caps beside it, matching the frame's single line.
/// Zero-valued counts are dropped rather than printed as `0 SETS`.
class _SelectedDayStrip extends StatelessWidget {
  final DateTime date;
  final int setCount;
  final int entryCount;
  final List<NutritionLog> nutritionLogs;

  const _SelectedDayStrip({
    required this.date,
    required this.setCount,
    required this.entryCount,
    required this.nutritionLogs,
  });

  @override
  Widget build(BuildContext context) {
    final String formattedDate = DateFormat('EEE').format(date).toUpperCase();
    final String formattedDay = DateFormat('MMM d').format(date).toUpperCase();

    final int totalKcal = nutritionLogs.fold<int>(
      0,
      (int acc, NutritionLog log) => acc + log.calories.round(),
    );

    final List<String> parts = <String>[
      if (setCount > 0) '$setCount ${setCount == 1 ? 'SET' : 'SETS'}',
      if (entryCount > 0)
        '$entryCount ${entryCount == 1 ? 'ENTRY' : 'ENTRIES'}',
      if (totalKcal > 0) '$totalKcal KCAL',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            '$formattedDate · $formattedDay',
            style: LiftText.dataMeta.copyWith(
              color: LiftColors.textPrimary,
              fontFeatures: LiftText.dataFeatures,
            ),
          ),
          if (parts.isNotEmpty) ...<Widget>[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                parts.join(' · '),
                overflow: TextOverflow.ellipsis,
                style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
              ),
            ),
          ],
        ],
      ),
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
          title: HistoryStrings.workoutHistoryTitle,
          subtitle: _buildSubtitle(summary),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (sets.isNotEmpty) ...<Widget>[
                _MuscleFilterChips(
                  muscles: _orderedMuscles(summary),
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

  /// The muscles this day actually hit, heaviest first, then every remaining
  /// muscle group.
  ///
  /// Frame 09 shows `ALL · CHEST · SHOULDERS · REAR DELTS` on a chest-only
  /// day, so the day's own muscles lead the row — a fixed global order buries
  /// the one chip the user came to press behind however many groups happen to
  /// sort before it. The rest still follow, because filtering to a muscle the
  /// day did not train is a legitimate way to confirm it was not trained.
  List<String> _orderedMuscles(HistoryWorkoutSummary summary) {
    final List<String> present = summary.muscleCounts
        .map((HistoryMuscleCount mc) => mc.muscleGroup)
        .toList();
    final Set<String> seen = present.toSet();

    return <String>[
      ...present,
      ...MuscleGroups.all.where((String m) => !seen.contains(m)),
    ];
  }

  /// `3 SETS · CHEST ×3` — the set count, then the two heaviest-hit muscles.
  String _buildSubtitle(HistoryWorkoutSummary summary) {
    final String setLabel =
        '${sets.length} ${sets.length == 1 ? 'SET' : 'SETS'}';
    if (summary.muscleCounts.isEmpty) {
      return setLabel;
    }

    final String muscles = summary.muscleCounts
        .take(2)
        .map(
          (HistoryMuscleCount mc) =>
              '${mc.displayName.toUpperCase()} ×${mc.directSetCount}',
        )
        .join(' · ');

    return '$setLabel · $muscles';
  }

  Widget _buildContent(
    BuildContext context,
    Map<String, Exercise> exerciseMap,
    List<WorkoutSet> filteredSets,
  ) {
    if (sets.isEmpty) {
      return _EmptySectionHint(
        message: HistoryStrings.noWorkoutsForDayMessage,
        ctaLabel:
            'LOG WORKOUT · ${DateFormat('MMM d').format(date).toUpperCase()}',
        onPressed: () =>
            showHistoryWorkoutLogBottomSheet(context, selectedDate: date),
      );
    }

    if (exerciseMap.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: LiftColors.actionTint),
        ),
      );
    }

    if (filteredSets.isEmpty) {
      return const _EmptySectionHint(
        message: 'No sets match this filter. Try another muscle group.',
      );
    }

    final double totalVolume = filteredSets.fold<double>(
      0,
      (double acc, WorkoutSet s) => acc + s.weight * s.reps,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final WorkoutSet s in filteredSets)
          if (exerciseMap.containsKey(s.exerciseId))
            _WorkoutSetRow(
              set: s,
              exercise: exerciseMap[s.exerciseId]!,
              weightUnit: weightUnit,
            )
          else
            _WorkoutSetRow(set: s, exercise: null, weightUnit: weightUnit),
        _DayTotalRow(volumeKilograms: totalVolume, weightUnit: weightUnit),
      ],
    );
  }
}

/// The frame's `ALL / CHEST / SHOULDERS / REAR DELTS` filter row: square
/// 26dp-tall chips, 1.5px border, the active one filled with
/// [LiftColors.actionFill]. Chips are filters here and nowhere else — the
/// spec forbids using one to display a value.
class _MuscleFilterChips extends StatelessWidget {
  final List<String> muscles;
  final String? selectedMuscle;
  final ValueChanged<String?> onChanged;

  const _MuscleFilterChips({
    required this.muscles,
    required this.selectedMuscle,
    required this.onChanged,
  });

  static const double _height = 26;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: <Widget>[
          _chip(
            label: 'ALL',
            selected: selectedMuscle == null,
            onTap: () => onChanged(null),
          ),
          ...muscles.map(
            (String muscle) => _chip(
              label: MuscleGroups.getDisplayName(muscle).toUpperCase(),
              selected: selectedMuscle == muscle,
              onTap: () => onChanged(selectedMuscle == muscle ? null : muscle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: onTap,
        child: Semantics(
          button: true,
          selected: selected,
          child: Container(
            height: _height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: selected ? LiftColors.actionFill : Colors.transparent,
              border: selected
                  ? null
                  : Border.all(
                      color: LiftColors.border,
                      width: LiftShape.borderWidth,
                    ),
            ),
            child: Text(
              label,
              style: LiftText.labelMedium.copyWith(
                color: selected ? Colors.white : LiftColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One logged set: five cumulative effort marks, the exercise and its muscle,
/// then `weight × reps` right-aligned in tabular mono.
///
/// The marks encode effort by **count**, not height — marks `0..level-1` take
/// [LiftColors.effortOn] and the rest [LiftColors.effortOff]. This is the same
/// encoding `ExerciseSetRow` uses on the Log tab and deliberately different
/// from `LogIntensitySelector`'s height-encoded picker; the two must not be
/// harmonised.
///
/// [exercise] is null when the set outlives the library entry it points at.
/// The row still renders — the set is real data and deleting it has to stay
/// possible — with a dim italic placeholder name and no muscle line.
class _WorkoutSetRow extends StatelessWidget {
  final WorkoutSet set;
  final Exercise? exercise;
  final WeightUnit weightUnit;

  const _WorkoutSetRow({
    required this.set,
    required this.exercise,
    required this.weightUnit,
  });

  static const double _markWidth = 5;
  static const double _markHeight = 11;
  static const double _markGap = 3;

  @override
  Widget build(BuildContext context) {
    final int level = set.validatedIntensity.clamp(0, 5);
    final String displayWeight = WeightUnitUtils.formatForDisplay(
      set.weight,
      weightUnit,
    );
    final (String weightValue, String weightUnitLabel) = _split(displayWeight);

    final String? muscleLabel = exercise == null
        ? null
        : exercise!.muscleGroups
              .map(MuscleGroups.getDisplayName)
              .join(' · ')
              .toUpperCase();

    return InkWell(
      onTap: exercise == null ? null : () => _showEditDialog(context),
      onLongPress: () => _confirmDelete(context, displayWeight),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: LiftColors.hairline, width: 1),
          ),
        ),
        child: Row(
          children: <Widget>[
            Row(
              children: List<Widget>.generate(5, (int i) {
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : _markGap),
                  child: Container(
                    key: ValueKey<String>('history-effort-mark-$i'),
                    width: _markWidth,
                    height: _markHeight,
                    color: i < level
                        ? LiftColors.effortOn
                        : LiftColors.effortOff,
                  ),
                );
              }),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    exercise?.name ?? HistoryStrings.unknownExercise,
                    overflow: TextOverflow.ellipsis,
                    style: LiftText.titleSmall.copyWith(
                      color: exercise == null
                          ? LiftColors.textDim
                          : LiftColors.textPrimary,
                      fontStyle: exercise == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  if (muscleLabel != null &&
                      muscleLabel.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      muscleLabel,
                      overflow: TextOverflow.ellipsis,
                      style: LiftText.labelMedium.copyWith(
                        color: LiftColors.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            LiftNumber(weightValue, weightUnitLabel, LiftText.dataSmall),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '×',
                style: LiftText.dataSmall.copyWith(color: LiftColors.textDim),
              ),
            ),
            LiftNumber('${set.reps}', '', LiftText.dataSmall),
          ],
        ),
      ),
    );
  }

  /// Splits `80 kg` into `('80', 'kg')` so the unit can ride the value.
  static (String, String) _split(String text) {
    final int i = text.indexOf(' ');
    if (i < 0) return (text, '');
    return (text.substring(0, i), text.substring(i + 1));
  }

  void _showEditDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<HistoryBloc>(),
        child: EditSetDialog(
          workoutSet: set,
          exercise: exercise!,
          weightUnit: weightUnit,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String displayWeight) {
    final String name = exercise?.name ?? HistoryStrings.unknownExercise;

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text(HistoryStrings.deleteSetTitle),
        content: Text('Remove $name — ${set.reps} reps @ $displayWeight?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(HistoryStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(DeleteSetEvent(set.id));
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: LiftColors.error),
            child: const Text(HistoryStrings.delete),
          ),
        ],
      ),
    );
  }
}

/// `DAY TOTAL                                            1134 KG`
///
/// `KG` is a spaced word, so it is a separate letterspaced caps label rather
/// than a [LiftNumber] unit — a glued unit would read `1134kg`.
class _DayTotalRow extends StatelessWidget {
  const _DayTotalRow({required this.volumeKilograms, required this.weightUnit});

  final double volumeKilograms;
  final WeightUnit weightUnit;

  @override
  Widget build(BuildContext context) {
    final double converted = WeightUnitUtils.fromStoredKilograms(
      volumeKilograms,
      weightUnit,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            HistoryStrings.dayTotalLabel,
            style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
          ),
          const Spacer(),
          Text(
            converted.round().toString(),
            style: LiftText.dataSmall.copyWith(
              color: LiftColors.textPrimary,
              fontFeatures: LiftText.dataFeatures,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            WeightUnitUtils.unitLabel(weightUnit).toUpperCase(),
            style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
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
    final int kcal = logs.fold<int>(
      0,
      (int acc, NutritionLog l) => acc + l.calories.round(),
    );

    final String entryLabel =
        '${logs.length} ${logs.length == 1 ? 'ENTRY' : 'ENTRIES'}';

    return CollapsibleSection(
      id: _kNutritionSectionId,
      title: HistoryStrings.nutritionHistoryTitle,
      subtitle: kcal > 0 ? '$entryLabel · $kcal KCAL' : entryLabel,
      child: logs.isEmpty
          ? _EmptySectionHint(
              message: HistoryStrings.noNutritionForDayMessage,
              ctaLabel:
                  'LOG NUTRITION · ${DateFormat('MMM d').format(date).toUpperCase()}',
              onPressed: () => showHistoryNutritionTypeBottomSheet(
                context,
                selectedDate: date,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _NutritionTotalsRow(logs: logs),
                const SizedBox(height: 18),
                for (final NutritionLog log in logs) _NutritionLogRow(log: log),
              ],
            ),
    );
  }
}

/// The day's four macro totals as left-aligned columns — the same construct
/// Home's `TODAY · INTAKE` strip uses, so the two read as one element in two
/// places rather than two similar ones.
class _NutritionTotalsRow extends StatelessWidget {
  const _NutritionTotalsRow({required this.logs});

  final List<NutritionLog> logs;

  @override
  Widget build(BuildContext context) {
    double protein = 0;
    double carbs = 0;
    double fats = 0;
    double calories = 0;

    for (final NutritionLog log in logs) {
      protein += log.proteinGrams;
      carbs += log.carbsGrams;
      fats += log.fatGrams;
      calories += log.calories;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _TotalsColumn(
            value: LiftNumber(
              protein.round().toString(),
              'g',
              LiftText.dataMedium,
            ),
            label: const MacroLabel(kind: MacroKind.protein),
          ),
        ),
        Expanded(
          child: _TotalsColumn(
            value: LiftNumber(
              carbs.round().toString(),
              'g',
              LiftText.dataMedium,
            ),
            label: const MacroLabel(kind: MacroKind.carbs),
          ),
        ),
        Expanded(
          child: _TotalsColumn(
            value: LiftNumber(
              fats.round().toString(),
              'g',
              LiftText.dataMedium,
            ),
            label: const MacroLabel(kind: MacroKind.fats),
          ),
        ),
        Expanded(
          child: _TotalsColumn(
            // KCAL is a spaced label, so the calorie count is a plain mono
            // value; a glued `LiftNumber` unit would read `2792kcal`. A bare
            // `Text` has to ask for the tabular figures its siblings get from
            // `LiftNumber`, or this column's digits do not line up with them.
            value: Text(
              calories.round().toString(),
              style: LiftText.dataMedium.copyWith(
                color: LiftColors.textPrimary,
                fontFeatures: LiftText.dataFeatures,
              ),
            ),
            label: Text(
              'KCAL',
              style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
            ),
          ),
        ),
      ],
    );
  }
}

class _TotalsColumn extends StatelessWidget {
  const _TotalsColumn({required this.value, required this.label});

  final Widget value;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: value,
        ),
        const SizedBox(height: 6),
        label,
      ],
    );
  }
}

/// One nutrition entry: name and time, kcal right-aligned, then a second line
/// of coded macro swatches and — for meal logs — the amount consumed.
class _NutritionLogRow extends StatelessWidget {
  final NutritionLog log;

  const _NutritionLogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final String time = DateFormat('HH:mm').format(log.loggedAt);
    final double? gramsConsumed = log.gramsConsumed;

    return InkWell(
      onTap: () => _showEditDialog(context),
      onLongPress: () => _confirmDelete(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: LiftColors.hairline, width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                // The name and its time share one `Expanded` rather than
                // competing with a `Spacer`: a `Flexible` name beside a
                // `Spacer` splits the free space between them, which
                // ellipsised "Direct macro entry" at phone width even though
                // the frame fits it whole.
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          log.mealName,
                          overflow: TextOverflow.ellipsis,
                          style: LiftText.titleSmall.copyWith(
                            color: LiftColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        time,
                        style: LiftText.labelMedium.copyWith(
                          color: LiftColors.textDim,
                          fontFeatures: LiftText.dataFeatures,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  log.calories.round().toString(),
                  style: LiftText.dataSmall.copyWith(
                    color: LiftColors.textPrimary,
                    fontFeatures: LiftText.dataFeatures,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  'KCAL',
                  style: LiftText.labelMedium.copyWith(
                    color: LiftColors.textDim,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _MacroMark(kind: MacroKind.protein, grams: log.proteinGrams),
                const SizedBox(width: 16),
                _MacroMark(kind: MacroKind.carbs, grams: log.carbsGrams),
                const SizedBox(width: 16),
                _MacroMark(kind: MacroKind.fats, grams: log.fatGrams),
                if (gramsConsumed != null) ...<Widget>[
                  const SizedBox(width: 18),
                  Text(
                    '${gramsConsumed.round()} G',
                    style: LiftText.labelMedium.copyWith(
                      color: LiftColors.textFaint,
                    ),
                  ),
                ],
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
        title: const Text(HistoryStrings.deleteNutritionTitle),
        content: Text('Remove "${log.mealName}" from history?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(HistoryStrings.cancel),
          ),
          TextButton(
            onPressed: () {
              context.read<HistoryBloc>().add(
                DeleteNutritionHistoryLogEvent(log.id),
              );
              Navigator.pop(dialogContext);
            },
            style: TextButton.styleFrom(foregroundColor: LiftColors.error),
            child: const Text(HistoryStrings.delete),
          ),
        ],
      ),
    );
  }
}

/// A macro swatch glued to its gram value — the entry-row form of
/// [MacroLabel], which spells the macro's *name* instead. Both take their
/// colour from [MacroKind] so the two can never disagree about which hue
/// means protein.
class _MacroMark extends StatelessWidget {
  const _MacroMark({required this.kind, required this.grams});

  final MacroKind kind;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 9, height: 9, color: kind.color),
        const SizedBox(width: 6),
        LiftNumber(grams.round().toString(), 'g', LiftText.dataMeta),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty states
// ---------------------------------------------------------------------------

/// Shown inside a section that has nothing to list. The frames never render
/// this case, so it is styled to the spec rather than copied from a frame:
/// one dim prompt line, and — where there is something to create — an
/// outlined button, the same treatment frame 04's empty Log tab uses.
class _EmptySectionHint extends StatelessWidget {
  const _EmptySectionHint({
    required this.message,
    this.ctaLabel,
    this.onPressed,
  });

  final String message;
  final String? ctaLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            message,
            style: LiftText.bodyMedium.copyWith(color: LiftColors.textFaint),
          ),
          if (ctaLabel != null && onPressed != null) ...<Widget>[
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onPressed, child: Text(ctaLabel!)),
          ],
        ],
      ),
    );
  }
}

/// Shown in place of the whole day panel before any day is picked.
class _NoDaySelected extends StatelessWidget {
  const _NoDaySelected();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(_gutter, 22, _gutter, 22),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            HistoryStrings.noDaySelectedTitle.toUpperCase(),
            style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
          ),
          const SizedBox(height: 8),
          Text(
            HistoryStrings.noDaySelectedMessage,
            style: LiftText.bodyMedium.copyWith(color: LiftColors.textFaint),
          ),
        ],
      ),
    );
  }
}
