import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/calendar_constants.dart';
import '../../../../core/constants/muscle_groups.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/weight_unit_utils.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/entities/exercise.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../library/application/exercise_bloc.dart';
import '../../../settings/presentation/settings_scope.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../../../../presentation/widgets/history_log_bottom_sheets.dart';
import 'edit_set_dialog.dart';

class DayDetailsBottomSheet extends StatelessWidget {
  const DayDetailsBottomSheet({
    required this.date,
    required this.sets,
    super.key,
  });

  final DateTime date;
  final List<WorkoutSet> sets;

  @override
  Widget build(BuildContext context) {
    final WeightUnit weightUnit = SettingsScope.weightUnitOf(context);
    final bool hasWorkouts = sets.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(CalendarConstants.bottomSheetBorderRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderDark,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context, hasWorkouts),
          if (hasWorkouts) const Divider(height: 1),
          Flexible(
            child: hasWorkouts
                ? _buildWorkoutsList(context, weightUnit)
                : _buildEmptyState(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasWorkouts) {
    final String dateStr = DateFormat('EEEE, MMM d').format(date);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  dateStr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (hasWorkouts) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    '${sets.length} set${sets.length != 1 ? 's' : ''} logged',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Set',
            onPressed: () => _openAddWorkoutSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutsList(BuildContext context, WeightUnit weightUnit) {
    return BlocBuilder<ExerciseBloc, ExerciseState>(
      builder: (BuildContext context, ExerciseState exerciseState) {
        if (exerciseState is! ExercisesLoaded) {
          return const Center(child: CircularProgressIndicator());
        }

        final Map<String, Exercise> exerciseMap = <String, Exercise>{
          for (final Exercise ex in exerciseState.exercises) ex.id: ex,
        };

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: sets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (BuildContext context, int index) {
            final WorkoutSet set = sets[index];
            final Exercise? exercise = exerciseMap[set.exerciseId];

            if (exercise == null) {
              return const SizedBox.shrink();
            }

            return _buildSetCard(context, set, exercise, weightUnit);
          },
        );
      },
    );
  }

  Widget _buildSetCard(
    BuildContext context,
    WorkoutSet set,
    Exercise exercise,
    WeightUnit weightUnit,
  ) {
    final String muscleGroupsList = exercise.muscleGroups
        .map(MuscleGroups.getDisplayName)
        .join(', ');

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
                  onPressed: () =>
                      _showEditDialog(context, set, exercise, weightUnit),
                  tooltip: 'Edit Set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () =>
                      _confirmDelete(context, set, exercise, weightUnit),
                  tooltip: 'Delete Set',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _buildDetailChip(
                  context,
                  icon: Icons.repeat,
                  label: '${set.reps} reps',
                ),
                const SizedBox(width: 8),
                _buildDetailChip(
                  context,
                  icon: Icons.fitness_center,
                  label: WeightUnitUtils.formatForDisplay(
                    set.weight,
                    weightUnit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              muscleGroupsList,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
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

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.fitness_center_outlined,
            size: 64,
            color: AppTheme.textDim,
          ),
          const SizedBox(height: 16),
          Text(
            'No workouts logged',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textMedium),
          ),
          const SizedBox(height: 8),
          Text(
            'Log a workout to start tracking',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddWorkoutSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Log Workout'),
          ),
        ],
      ),
    );
  }

  void _openAddWorkoutSheet(BuildContext context) {
    Navigator.of(context).pop();
    showHistoryWorkoutLogBottomSheet(context, selectedDate: date);
  }

  void _showEditDialog(
    BuildContext context,
    WorkoutSet set,
    Exercise exercise,
    WeightUnit weightUnit,
  ) {
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

  void _confirmDelete(
    BuildContext context,
    WorkoutSet set,
    Exercise exercise,
    WeightUnit weightUnit,
  ) {
    final String displayWeight = WeightUnitUtils.formatForDisplay(
      set.weight,
      weightUnit,
    );

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
