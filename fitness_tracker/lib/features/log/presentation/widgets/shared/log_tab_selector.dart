import 'package:flutter/material.dart';

import '../../../../../core/constants/app_strings.dart';
import '../../../../../core/themes/app_theme.dart';

/// Slim segmented control replacing the stacked icon+label variant in [log_page.dart].
/// Icon and label are inline (horizontal), segment height is 44 px for touch compliance.
class LogTabSelector extends StatelessWidget {
  const LogTabSelector({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const List<_TabItem> _tabs = <_TabItem>[
    _TabItem(label: AppStrings.logExerciseTab, icon: Icons.fitness_center),
    _TabItem(label: AppStrings.logMealTab, icon: Icons.restaurant),
    _TabItem(label: AppStrings.logMacrosTab, icon: Icons.calculate),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: List<Widget>.generate(_tabs.length, (int i) {
          final bool active = i == selectedIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: active,
              label: _tabs[i].label,
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primaryOrange : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        _tabs[i].icon,
                        size: 18,
                        color: active ? Colors.white : AppTheme.textDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _tabs[i].label,
                        style: TextStyle(
                          color: active ? Colors.white : AppTheme.textDim,
                          fontSize: 13,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
