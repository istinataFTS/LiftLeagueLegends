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
      // Horizontal-only padding, dense button, 18dp icon: the selector now
      // shares a row with the section title and the mode toggle, so it has to
      // hold the toggle's height rather than the 48dp a non-dense
      // `DropdownButton` claims, and it has to leave the title enough width
      // not to ellipsise at 360dp.
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
          isDense: true,
          onChanged: enabled
              ? (TimePeriod? value) {
                  if (value != null) {
                    onPeriodChanged(value);
                  }
                }
              : null,
          iconSize: 18,
          icon: Icon(
            Icons.arrow_drop_down,
            color: enabled ? LiftColors.textSecondary : LiftColors.textDisabled,
          ),
          // The closed button is width-driven by its *widest* entry, and it
          // now shares a row with the section title and the mode toggle, so
          // `ALL TIME` is abbreviated there. The menu itself still spells
          // both options out in full.
          selectedItemBuilder: (BuildContext context) => <Widget>[
            _buildButtonLabel('MONTH'),
            _buildButtonLabel('ALL'),
          ],
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

  /// Centred vertically so the abbreviated label sits on the toggle's
  /// baseline; `selectedItemBuilder` entries are laid out at the button's
  /// full height, not the text's.
  Widget _buildButtonLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: LiftText.labelLarge.copyWith(
          color: enabled ? LiftColors.textStrong : LiftColors.textDisabled,
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
