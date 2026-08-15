import 'package:flutter/material.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/themes/lift_theme.dart';

/// Log's three sub-tabs as mono caps over a tint underline (frame 02).
/// Segment height stays 44 px for touch compliance.
class LogTabSelector extends StatelessWidget {
  const LogTabSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const List<String> _labels = <String>[
    AppStrings.logExerciseTab,
    AppStrings.logMealTab,
    AppStrings.logMacrosTab,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(_labels.length, (int i) {
          final bool active = i == selectedIndex;
          return Semantics(
            button: true,
            selected: active,
            label: _labels[i],
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == _labels.length - 1 ? 0 : 22,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    const Spacer(),
                    Text(
                      _labels[i].toUpperCase(),
                      style: LiftText.labelLarge.copyWith(
                        color: active
                            ? LiftColors.textPrimary
                            : LiftColors.textDim,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      key: ValueKey<String>('log-tab-underline-$i'),
                      constraints: const BoxConstraints(
                        maxHeight: LiftShape.borderWidthActive,
                        minHeight: LiftShape.borderWidthActive,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? LiftColors.actionTint
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
