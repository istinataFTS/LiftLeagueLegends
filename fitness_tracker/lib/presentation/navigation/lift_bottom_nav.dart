import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/themes/lift_theme.dart';
import '../shared/widgets/lift_tab_selector.dart';

/// The app's tab bar, in the same language as `LiftTabSelector` — the strip
/// that carries `EXERCISE / MEAL / MACROS` at the top of the Log page (see
/// [LiftTabSelector]).
///
/// It was the last Material control left in the shell: a stock
/// [BottomNavigationBar] still painted in the pre-restyle `AppTheme` greys,
/// with sentence-case proportional labels, sitting under five Deep Mist pages.
/// Everything that made it read as a different app is gone — the label is now
/// mono caps at [LiftText.labelMedium], the active tab takes
/// [LiftColors.actionTint] and a 2.5px tint marker, and the bar itself is a
/// [LiftColors.panelBottom] slab bounded by a single full-width
/// [LiftColors.rule] hairline.
///
/// The marker rides the **top** edge of the active item — the mirror of the
/// tab selector's underline, which sits under its label. Icons stay: five
/// destinations at this width leave too little room for the label to carry
/// the tab alone, and unlike the three-way Log selector these are places, not
/// modes of one page.
class LiftBottomNav extends StatelessWidget {
  const LiftBottomNav({
    required this.selectedIndex,
    required this.onTap,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const double _height = 58;
  static const double _markerHeight = LiftShape.borderWidthActive;

  static const List<_NavDestination> _destinations = <_NavDestination>[
    _NavDestination(
      label: AppStrings.navHome,
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
    ),
    _NavDestination(
      label: AppStrings.navLog,
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle,
    ),
    _NavDestination(
      label: AppStrings.navHistory,
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
    ),
    _NavDestination(
      label: AppStrings.navLibrary,
      icon: Icons.library_books_outlined,
      activeIcon: Icons.library_books,
    ),
    _NavDestination(
      label: AppStrings.navProfile,
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: LiftColors.panelBottom,
        border: Border(
          top: BorderSide(color: LiftColors.rule, width: LiftShape.borderWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _height,
          child: Row(
            children: List<Widget>.generate(_destinations.length, (int i) {
              return Expanded(child: _buildItem(i));
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(int index) {
    final _NavDestination destination = _destinations[index];
    final bool active = index == selectedIndex;
    final Color foreground = active
        ? LiftColors.actionTint
        : LiftColors.textDim;

    return Semantics(
      button: true,
      selected: active,
      label: destination.label,
      // The node needs its own `onTap`: `excludeSemantics` drops the
      // GestureDetector's semantics with the rest of the subtree, so without
      // this the tab announces as a button assistive technology cannot press.
      onTap: () => onTap(index),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              key: ValueKey<String>('nav-marker-$index'),
              height: _markerHeight,
              color: active ? LiftColors.actionTint : Colors.transparent,
            ),
            const Spacer(),
            Icon(
              active ? destination.activeIcon : destination.icon,
              size: 22,
              color: foreground,
            ),
            const SizedBox(height: 5),
            Text(
              destination.label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: LiftText.labelMedium.copyWith(
                color: foreground,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
