import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/themes/app_theme.dart';

/// Compact date pill used in each tab's header area.
/// Shows 'Today' when [date] is today, otherwise 'MMM d'.
/// Tap opens the OS date picker using the app's dark [ColorScheme].
class LogDatePill extends StatelessWidget {
  const LogDatePill({
    super.key,
    required this.date,
    required this.onDateSelected,
    this.firstDate,
    this.lastDate,
  });

  final DateTime date;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? firstDate;
  final DateTime? lastDate;

  bool _isToday(DateTime d) {
    final DateTime now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _label() =>
      _isToday(date) ? AppStrings.today : DateFormat('MMM d').format(date);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Select date, currently ${_label()}',
      child: InkWell(
        onTap: () => _selectDate(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppTheme.textDim,
              ),
              const SizedBox(width: 6),
              Text(
                _label(),
                style: const TextStyle(
                  color: AppTheme.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 16, color: AppTheme.textDim),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime effectiveFirst = firstDate ?? DateTime(2020);
    final DateTime effectiveLast = lastDate ?? now;
    DateTime initial = date;
    if (initial.isBefore(effectiveFirst)) initial = effectiveFirst;
    if (initial.isAfter(effectiveLast)) initial = effectiveLast;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: effectiveFirst,
      lastDate: effectiveLast,
      builder: (BuildContext ctx, Widget? child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryOrange,
              onPrimary: Colors.white,
              surface: AppTheme.surfaceDark,
              onSurface: AppTheme.textLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onDateSelected(picked);
  }
}
