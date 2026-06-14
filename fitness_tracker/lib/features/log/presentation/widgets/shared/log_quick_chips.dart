import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter/services.dart';

import '../../../../../core/themes/app_theme.dart';

/// Row of preset-value chips. Active chip (value == [selectedValue]) is filled orange.
/// Each chip has a ≥44 dp touch target via surrounding [InkWell] with min-height padding.
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
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryOrange : AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppTheme.primaryOrange : AppTheme.borderDark,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: TextStyle(
              color: isActive ? Colors.white : AppTheme.textMedium,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
