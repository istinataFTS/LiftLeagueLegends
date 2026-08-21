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
/// ### What this panel does not repeat
///
/// There is no line naming the selected day. The calendar directly above is
/// already showing which cell is outlined, and printing `FRI · AUG 21` under
/// it said the same thing twice — the counts it also carried are in the two
/// section subtitles.
///
/// The workout section has no muscle filter either. It filtered a list that is
/// now grouped by exercise, where the exercise names are the index; a chip row
/// that hides four of six groups is a worse way to find one of six groups than
/// reading them.
///
/// ### Reaching edit, delete and add
///
///  * **edit a set** — the pencil on the set row, inside its exercise group.
///    This used to be a bare tap on the row with nothing to announce it, which
///    made editing look impossible next to a delete you could find.
///  * **delete a set** — the trash on the same row.
///  * **add to this day** — the `+` in the workout section header, and the
///    empty-state call to action on days with nothing logged.
class HistoryDayContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (selectedDate == null) {
      return const _NoDaySelected();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _WorkoutHistorySection(
          date: selectedDate!,
          sets: workoutSets,
          weightUnit: weightUnit,
        ),
        _NutritionHistorySection(date: selectedDate!, logs: nutritionLogs),
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

  const _WorkoutHistorySection({
    required this.date,
    required this.sets,
    required this.weightUnit,
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

        return CollapsibleSection(
          id: _kWorkoutSectionId,
          title: HistoryStrings.workoutHistoryTitle,
          subtitle: _buildSubtitle(summary),
          trailing: _AddToDayButton(date: date),
          child: _buildContent(context, exerciseMap),
        );
      },
    );
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

    final List<_ExerciseGroup> groups = _groupByExercise(sets, exerciseMap);

    final double totalVolume = sets.fold<double>(
      0,
      (double acc, WorkoutSet s) => acc + s.weight * s.reps,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final _ExerciseGroup group in groups)
          _ExerciseGroupTile(
            key: ValueKey<String>('history-exercise-group-${group.key}'),
            group: group,
            weightUnit: weightUnit,
          ),
        _DayTotalRow(volumeKilograms: totalVolume, weightUnit: weightUnit),
      ],
    );
  }

  /// Collapses the day's sets into one entry per exercise, in the order the
  /// exercises were first logged.
  ///
  /// A superset day logs `A B A B A B`; listing every set flat turns six rows
  /// into eighteen and buries the only question worth asking of the list —
  /// how many times did I do A. Grouping answers it in the header and keeps
  /// the individual sets one tap away.
  ///
  /// Sets whose exercise is gone from the library keep their own group, keyed
  /// by exercise id, so they stay deletable instead of vanishing into a shared
  /// "unknown" bucket where two different missing exercises would merge.
  static List<_ExerciseGroup> _groupByExercise(
    List<WorkoutSet> sets,
    Map<String, Exercise> exerciseById,
  ) {
    final Map<String, List<WorkoutSet>> byExercise =
        <String, List<WorkoutSet>>{};

    for (final WorkoutSet s in sets) {
      byExercise.putIfAbsent(s.exerciseId, () => <WorkoutSet>[]).add(s);
    }

    return byExercise.entries.map((MapEntry<String, List<WorkoutSet>> entry) {
      final List<WorkoutSet> ordered = List<WorkoutSet>.from(entry.value)
        ..sort(
          (WorkoutSet a, WorkoutSet b) => a.createdAt.compareTo(b.createdAt),
        );

      return _ExerciseGroup(
        key: entry.key,
        exercise: exerciseById[entry.key],
        sets: ordered,
      );
    }).toList();
  }
}

/// One exercise's sets for the selected day.
class _ExerciseGroup {
  const _ExerciseGroup({
    required this.key,
    required this.exercise,
    required this.sets,
  });

  /// The exercise id — stable even when [exercise] is null.
  final String key;

  /// Null when the set outlives the library entry it points at.
  final Exercise? exercise;

  /// This exercise's sets for the day, oldest first.
  final List<WorkoutSet> sets;

  double get volumeKilograms => sets.fold<double>(
    0,
    (double acc, WorkoutSet s) => acc + s.weight * s.reps,
  );
}

/// The `+` in the workout section header: add a set to the day being viewed.
///
/// It opens the same sheet the empty state's call to action does. Before this
/// existed, a day that already had one set had no way to gain a second from
/// History — the only add button lived in an empty state that day could no
/// longer show.
class _AddToDayButton extends StatelessWidget {
  const _AddToDayButton({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a set for ${DateFormat('MMMM d').format(date)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            showHistoryWorkoutLogBottomSheet(context, selectedDate: date),
        child: const SizedBox(
          key: ValueKey<String>('history-add-set-button'),
          width: 44,
          height: 44,
          child: Icon(Icons.add, size: 22, color: LiftColors.actionTint),
        ),
      ),
    );
  }
}

/// An exercise group: a header row that expands to the sets under it.
///
/// Collapsed it reads `Bench Press / CHEST · TRICEPS` on the left and
/// `×4 / 320 KG` on the right — the two facts the flat list made you count by
/// eye. Expanded it lists each set with its own edit and delete controls.
///
/// A day usually opens with its groups collapsed; there is no persistence for
/// this state, unlike [CollapsibleSection], because it belongs to one day's
/// view of one exercise and there is nothing stable to key it to across days.
class _ExerciseGroupTile extends StatefulWidget {
  const _ExerciseGroupTile({
    required this.group,
    required this.weightUnit,
    super.key,
  });

  final _ExerciseGroup group;
  final WeightUnit weightUnit;

  @override
  State<_ExerciseGroupTile> createState() => _ExerciseGroupTileState();
}

class _ExerciseGroupTileState extends State<_ExerciseGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final _ExerciseGroup group = widget.group;
    final Exercise? exercise = group.exercise;
    final int setCount = group.sets.length;

    final String? muscleLabel = exercise == null
        ? null
        : exercise.muscleGroups
              .map(MuscleGroups.getDisplayName)
              .join(' · ')
              .toUpperCase();

    final String volumeText = WeightUnitUtils.formatForDisplay(
      group.volumeKilograms,
      widget.weightUnit,
    ).toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _expanded,
          label:
              '${exercise?.name ?? HistoryStrings.unknownExercise}, '
              '$setCount ${setCount == 1 ? 'set' : 'sets'}',
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: _expanded ? LiftColors.rule : LiftColors.hairline,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '×$setCount',
                        style: LiftText.dataSmall.copyWith(
                          color: LiftColors.textPrimary,
                          fontFeatures: LiftText.dataFeatures,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        volumeText,
                        style: LiftText.labelMedium.copyWith(
                          color: LiftColors.textDim,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: LiftColors.textDim,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded)
          for (int i = 0; i < group.sets.length; i++)
            _WorkoutSetRow(
              set: group.sets[i],
              exercise: exercise,
              setNumber: i + 1,
              weightUnit: widget.weightUnit,
            ),
      ],
    );
  }
}

/// One logged set inside its exercise group: the set's ordinal, five
/// cumulative effort marks, `weight × reps`, then edit and delete.
///
/// The marks encode effort by **count** — marks `0..level-1` take
/// [LiftColors.effortOn] and the rest [LiftColors.effortOff]. This is the same
/// encoding `ExerciseSetRow` uses on the Log tab, and deliberately different
/// from `LogIntensitySelector`, which encodes the level the user is choosing
/// as hue on a ramp.
///
/// The exercise name is not repeated here — the group header above carries it.
///
/// [exercise] is null when the set outlives the library entry it points at.
/// The row still renders and still deletes; only edit is unavailable, because
/// the edit dialog needs the exercise to name what is being edited.
class _WorkoutSetRow extends StatelessWidget {
  final WorkoutSet set;
  final Exercise? exercise;
  final int setNumber;
  final WeightUnit weightUnit;

  const _WorkoutSetRow({
    required this.set,
    required this.exercise,
    required this.setNumber,
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

    return Container(
      padding: const EdgeInsets.only(left: 14, top: 9, bottom: 9),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LiftColors.hairline, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 26,
            child: Text(
              '$setNumber',
              style: LiftText.labelMedium.copyWith(color: LiftColors.textFaint),
            ),
          ),
          Row(
            children: List<Widget>.generate(5, (int i) {
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : _markGap),
                child: Container(
                  key: ValueKey<String>('history-effort-mark-$i'),
                  width: _markWidth,
                  height: _markHeight,
                  color: i < level ? LiftColors.effortOn : LiftColors.effortOff,
                ),
              );
            }),
          ),
          const Spacer(),
          LiftNumber(weightValue, weightUnitLabel, LiftText.dataSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '×',
              style: LiftText.dataSmall.copyWith(color: LiftColors.textDim),
            ),
          ),
          LiftNumber('${set.reps}', '', LiftText.dataSmall),
          const SizedBox(width: 4),
          _RowAction(
            keyValue: 'history-edit-set-${set.id}',
            icon: Icons.edit_outlined,
            semanticLabel: 'Edit set',
            color: LiftColors.textDim,
            onTap: exercise == null ? null : () => _showEditDialog(context),
          ),
          _RowAction(
            keyValue: 'history-delete-set-${set.id}',
            icon: Icons.delete_outline,
            semanticLabel: 'Delete set',
            color: LiftColors.textDim,
            onTap: () => _confirmDelete(context, displayWeight),
          ),
        ],
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

/// A bare 36dp-square icon control for a list row. Disabled when [onTap] is
/// null, which is how a set whose exercise is gone loses edit but keeps
/// delete.
class _RowAction extends StatelessWidget {
  const _RowAction({
    required this.keyValue,
    required this.icon,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
  });

  final String keyValue;
  final IconData icon;
  final String semanticLabel;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          key: ValueKey<String>(keyValue),
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? color : LiftColors.textDisabled,
          ),
        ),
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
