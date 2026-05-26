import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../domain/entities/time_period.dart';

/// Period selector dropdown for muscle visualization.
///
/// Kept inside the Home feature because it is currently owned by the
/// Home progress surface and depends on Home-specific period semantics.
class PeriodSelectorWidget extends StatelessWidget {
  const PeriodSelectorWidget({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.enabled = true,
  });

  static const Key containerKey = ValueKey<String>(
    'home_period_selector_container',
  );
  static const Key dropdownKey = ValueKey<String>(
    'home_period_selector_dropdown',
  );

  static Key menuItemKey(TimePeriod period) =>
      ValueKey<String>('home_period_selector_item_${period.name}');

  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimePeriod>(
          key: dropdownKey,
          value: selectedPeriod,
          onChanged: enabled
              ? (TimePeriod? value) {
                  if (value != null) {
                    onPeriodChanged(value);
                  }
                }
              : null,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? AppTheme.textLight : AppTheme.textDim,
          ),
          dropdownColor: AppTheme.surfaceDark,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.textLight : AppTheme.textDim,
          ),
          // Today and Week are intentionally omitted from the user-facing
          // selector. The Fatigue toggle already exposes the live "right
          // now" rolling-weekly view, so neither a Week nor a Today volume
          // option earns its slot. Both enum members still exist because
          // the use case + bloc use them internally (Fatigue → Week,
          // GetMuscleVisualData → Today for daily-stimulus reads).
          items: <DropdownMenuItem<TimePeriod>>[
            _buildMenuItem(
              context,
              value: TimePeriod.month,
              label: AppStrings.periodMonth,
              icon: Icons.calendar_month,
            ),
            _buildMenuItem(
              context,
              value: TimePeriod.allTime,
              label: AppStrings.periodAllTime,
              icon: Icons.all_inclusive,
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<TimePeriod> _buildMenuItem(
    BuildContext context, {
    required TimePeriod value,
    required String label,
    required IconData icon,
  }) {
    return DropdownMenuItem<TimePeriod>(
      key: menuItemKey(value),
      value: value,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: AppTheme.primaryOrange),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}

/// Compact period selector as a segmented control.
///
/// Kept next to the dropdown because both widgets represent the same
/// feature-owned period selection concern.
class PeriodSegmentedControl extends StatelessWidget {
  const PeriodSegmentedControl({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.enabled = true,
  });

  final TimePeriod selectedPeriod;
  final ValueChanged<TimePeriod> onPeriodChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildSegment(
            context,
            period: TimePeriod.month,
            label: AppStrings.periodMonth,
          ),
          _buildSegment(
            context,
            period: TimePeriod.allTime,
            label: AppStrings.all,
          ),
        ],
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required TimePeriod period,
    required String label,
  }) {
    final bool isSelected = selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: enabled ? () => onPeriodChanged(period) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryOrange : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textDim,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
