import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/calendar_constants.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../bloc/history_bloc.dart';
import '../bloc/history_event.dart';
import '../../../../presentation/widgets/history_log_bottom_sheets.dart';
import 'edit_nutrition_log_dialog.dart';

class NutritionDayDetailsBottomSheet extends StatelessWidget {
  final DateTime date;
  final List<NutritionLog> logs;

  const NutritionDayDetailsBottomSheet({
    super.key,
    required this.date,
    required this.logs,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasLogs = logs.isNotEmpty;

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
          _buildHeader(context, hasLogs),
          if (hasLogs) const Divider(height: 1),
          Flexible(
            child: hasLogs
                ? _buildNutritionList(context)
                : _buildEmptyState(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool hasLogs) {
    final String dateStr = DateFormat('EEEE, MMM d').format(date);
    final _NutritionTotals totals = _calculateTotals();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (hasLogs) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '${logs.length} nutrition entr${logs.length == 1 ? 'y' : 'ies'} logged',
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
                tooltip: 'Add Nutrition',
                onPressed: () => _openAddNutritionSheet(context),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          if (hasLogs) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderDark),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _buildSummaryChip(
                    'Protein',
                    '${totals.protein.toStringAsFixed(0)}g',
                  ),
                  _buildSummaryChip(
                    'Carbs',
                    '${totals.carbs.toStringAsFixed(0)}g',
                  ),
                  _buildSummaryChip(
                    'Fats',
                    '${totals.fats.toStringAsFixed(0)}g',
                  ),
                  _buildSummaryChip(
                    'Calories',
                    '${totals.calories.round()} kcal',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: RichText(
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

  Widget _buildNutritionList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: logs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final NutritionLog log = logs[index];
        return _buildNutritionCard(context, log);
      },
    );
  }

  Widget _buildNutritionCard(BuildContext context, NutritionLog log) {
    final String time = DateFormat('HH:mm').format(log.loggedAt);

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
                  onPressed: () => _showEditDialog(context, log),
                  tooltip: 'Edit Nutrition Log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => _confirmDelete(context, log),
                  tooltip: 'Delete Nutrition Log',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (log.gramsConsumed != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${log.gramsConsumed!.toStringAsFixed(0)} g consumed',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _buildMacroChip('P', '${log.proteinGrams.toStringAsFixed(0)}g'),
                _buildMacroChip('C', '${log.carbsGrams.toStringAsFixed(0)}g'),
                _buildMacroChip('F', '${log.fatGrams.toStringAsFixed(0)}g'),
                _buildMacroChip('Kcal', '${log.calories.round()}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, String value) {
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

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.restaurant_outlined,
            size: 64,
            color: AppTheme.textDim,
          ),
          const SizedBox(height: 16),
          Text(
            'No nutrition logged',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textMedium),
          ),
          const SizedBox(height: 8),
          Text(
            'Log a meal or direct macros to start tracking.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openAddNutritionSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Log Nutrition'),
          ),
        ],
      ),
    );
  }

  void _openAddNutritionSheet(BuildContext context) {
    Navigator.of(context).pop();
    showHistoryNutritionTypeBottomSheet(context, selectedDate: date);
  }

  void _showEditDialog(BuildContext context, NutritionLog log) {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => BlocProvider.value(
        value: context.read<HistoryBloc>(),
        child: EditNutritionLogDialog(log: log),
      ),
    );
  }

  void _confirmDelete(BuildContext context, NutritionLog log) {
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

  _NutritionTotals _calculateTotals() {
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

    return _NutritionTotals(
      protein: protein,
      carbs: carbs,
      fats: fats,
      calories: calories,
    );
  }
}

class _NutritionTotals {
  final double protein;
  final double carbs;
  final double fats;
  final double calories;

  const _NutritionTotals({
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.calories,
  });
}
