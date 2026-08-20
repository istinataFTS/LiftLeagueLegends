import 'package:flutter/material.dart';

import '../../../core/themes/lift_theme.dart';

/// Deep Mist's tab strip: mono caps over a tint underline.
///
/// Log's three sub-tabs (frame 02) and Library's two (frame 11) are the same
/// control, so it lives above the feature layer — a Library import of Log's
/// `presentation/` would be a convention rule 8 violation, not a style choice.
///
/// Frame 11 measures the label at an 8dp cap height and a 25px glyph pitch at
/// 3x, i.e. `labelLarge` (11dp / 1.8 letter-spacing) exactly, and the gap
/// between two labels at ~23dp, which [_gap] rounds to 22.
///
/// Segment height stays 44 px for touch compliance.
class LiftTabSelector extends StatelessWidget {
  const LiftTabSelector({
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    this.keyPrefix = 'lift-tab',
    super.key,
  });

  /// Rendered verbatim in upper case, one segment each.
  final List<String> labels;

  final int selectedIndex;
  final ValueChanged<int> onChanged;

  /// Underline keys are `<keyPrefix>-underline-<index>`, so two selectors on
  /// one page (Log and Library never co-exist, but tests build both) do not
  /// collide.
  final String keyPrefix;

  static const double _gap = 22;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(labels.length, (int i) {
          final bool active = i == selectedIndex;
          return Semantics(
            button: true,
            selected: active,
            label: labels[i],
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(i),
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == labels.length - 1 ? 0 : _gap,
                ),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Spacer(),
                      Text(
                        labels[i].toUpperCase(),
                        style: LiftText.labelLarge.copyWith(
                          color: active
                              ? LiftColors.textPrimary
                              : LiftColors.textDim,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Container(
                        key: ValueKey<String>('$keyPrefix-underline-$i'),
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
            ),
          );
        }),
      ),
    );
  }
}
