import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/themes/lift_theme.dart';

/// Row of preset-value chips. Active chip (value == [selectedValue]) fills
/// [LiftColors.actionFill]. Square corners — chips are the one place a
/// button-radius exception does *not* apply (`LiftShape.radiusChip` is 0).
/// Each chip has a ≥44 dp touch target via surrounding [InkWell] with
/// min-height padding.
class LogQuickChips extends StatelessWidget {
  const LogQuickChips({
    super.key,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final List<num> values;
  final num selectedValue;
  final ValueChanged<num> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          _Chip(
            value: values[i],
            isActive: values[i] == selectedValue,
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(values[i]);
            },
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.value,
    required this.isActive,
    required this.onTap,
  });

  final num value;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: value.toString(),
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? LiftColors.actionFill : Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: isActive ? LiftColors.actionFill : LiftColors.border,
              width: LiftShape.borderWidth,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: LiftText.dataMeta.copyWith(
              color: isActive ? Colors.white : LiftColors.textSecondary,
              fontFeatures: LiftText.dataFeatures,
            ),
          ),
        ),
      ),
    );
  }
}
