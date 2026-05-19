import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../features/log/log.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';

Future<void> showHistoryWorkoutLogBottomSheet(
  BuildContext context, {
  required DateTime selectedDate,
}) {
  return _showHistoryFormSheet(
    context,
    title: 'Log workout',
    selectedDate: selectedDate,
    child: LogExerciseTab(
      initialDate: selectedDate,
      showSuccessFeedback: false,
      onLoggedSuccess: (DateTime loggedDate) {
        final HistoryBloc historyBloc = context.read<HistoryBloc>();
        historyBloc.add(SelectDateEvent(loggedDate));
        historyBloc.add(const RefreshCurrentMonthEvent());

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}

Future<void> showHistoryNutritionTypeBottomSheet(
  BuildContext context, {
  required DateTime selectedDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.surfaceDark,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Log nutrition for ${DateFormat('EEEE, MMM d').format(selectedDate)}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              _NutritionTypeOption(
                icon: Icons.restaurant_menu,
                title: 'Log meal',
                subtitle: 'Choose a saved meal and enter the consumed amount.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showHistoryMealLogBottomSheet(
                    context,
                    selectedDate: selectedDate,
                  );
                },
              ),
              const SizedBox(height: 12),
              _NutritionTypeOption(
                icon: Icons.calculate,
                title: 'Log macros',
                subtitle: 'Enter protein, carbs, and fats directly.',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showHistoryMacrosLogBottomSheet(
                    context,
                    selectedDate: selectedDate,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showHistoryMealLogBottomSheet(
  BuildContext context, {
  required DateTime selectedDate,
}) {
  return _showHistoryFormSheet(
    context,
    title: 'Log meal',
    selectedDate: selectedDate,
    child: LogMealTab(
      initialDate: selectedDate,
      showSuccessFeedback: false,
      onLoggedSuccess: (DateTime loggedDate) {
        final HistoryBloc historyBloc = context.read<HistoryBloc>();
        historyBloc.add(SelectDateEvent(loggedDate));
        historyBloc.add(const RefreshCurrentMonthEvent());

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}

Future<void> showHistoryMacrosLogBottomSheet(
  BuildContext context, {
  required DateTime selectedDate,
}) {
  return _showHistoryFormSheet(
    context,
    title: 'Log macros',
    selectedDate: selectedDate,
    child: LogMacrosTab(
      initialDate: selectedDate,
      showSuccessFeedback: false,
      onLoggedSuccess: (DateTime loggedDate) {
        final HistoryBloc historyBloc = context.read<HistoryBloc>();
        historyBloc.add(SelectDateEvent(loggedDate));
        historyBloc.add(const RefreshCurrentMonthEvent());

        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}

Future<void> _showHistoryFormSheet(
  BuildContext context, {
  required String title,
  required DateTime selectedDate,
  required Widget child,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return FractionallySizedBox(
        heightFactor: 0.94,
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.backgroundDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat(
                              'EEEE, MMM d, yyyy',
                            ).format(selectedDate),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textMedium),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(child: child),
            ],
          ),
        ),
      );
    },
  );
}

class _NutritionTypeOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NutritionTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.borderDark),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.primaryOrange),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right, color: AppTheme.textDim),
            ],
          ),
        ),
      ),
    );
  }
}
