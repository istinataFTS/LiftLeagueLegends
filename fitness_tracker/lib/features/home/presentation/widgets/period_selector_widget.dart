import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/lift_theme.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: LiftColors.surface,
        border: Border.fromBorderSide(
          BorderSide(color: LiftColors.border, width: LiftShape.borderWidth),
        ),
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
            color: enabled ? LiftColors.textSecondary : LiftColors.textDisabled,
          ),
          dropdownColor: LiftColors.panelTop,
          style: LiftText.labelLarge.copyWith(
            color: enabled ? LiftColors.textStrong : LiftColors.textDisabled,
          ),
          // Today and Week are intentionally omitted from the user-facing
          // selector. The Fatigue toggle already exposes the live "right
          // now" rolling-weekly view, so neither a Week nor a Today volume
          // option earns its slot. Both enum members still exist because
          // the use case + bloc use them internally (Fatigue → Week,
          // GetMuscleVisualData → Today for daily-stimulus reads).
          items: <DropdownMenuItem<TimePeriod>>[
            _buildMenuItem(
              value: TimePeriod.month,
              label: AppStrings.periodMonth,
            ),
            _buildMenuItem(
              value: TimePeriod.allTime,
              label: AppStrings.periodAllTime,
            ),
          ],
        ),
      ),
    );
  }

  DropdownMenuItem<TimePeriod> _buildMenuItem({
    required TimePeriod value,
    required String label,
  }) {
    return DropdownMenuItem<TimePeriod>(
      key: menuItemKey(value),
      value: value,
      child: Text(label.toUpperCase(), style: LiftText.labelLarge),
    );
  }
}
