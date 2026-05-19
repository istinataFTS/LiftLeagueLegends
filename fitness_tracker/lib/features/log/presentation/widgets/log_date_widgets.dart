import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/themes/app_theme.dart';

class LogDateContextBanner extends StatelessWidget {
  final DateTime selectedDate;
  final String prefix;

  const LogDateContextBanner({
    super.key,
    required this.selectedDate,
    this.prefix = 'Logging for',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.event_available,
            color: AppTheme.primaryOrange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$prefix ${DateFormat('EEEE, MMM d').format(selectedDate)}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.primaryOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LogDatePickerCard extends StatelessWidget {
  final String label;
  final DateTime selectedDate;
  final VoidCallback onTap;

  const LogDatePickerCard({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surfaceDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderDark),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppTheme.primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMM d, yyyy').format(selectedDate),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: AppTheme.textDim),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
