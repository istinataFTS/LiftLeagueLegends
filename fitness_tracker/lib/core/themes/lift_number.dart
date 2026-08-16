import 'package:flutter/material.dart';

import 'lift_theme.dart';

/// A quantity rendered in tabular mono with its unit riding small and dim.
///
/// Use this when the unit is glued to the value (`155g`, `15kg`, `1.00x`).
/// When the unit is a spaced word (`2792 KCAL`, `1134 KG TOTAL`) it is a
/// separate [LiftText.labelMedium] caps label instead — not this widget.
///
/// ### Colour
///
/// [color] overrides the value span's colour; it defaults to `null`, which
/// renders exactly as before ([LiftColors.textPrimary] on the value,
/// [LiftColors.textDim] on the unit).
///
/// When [color] is supplied, the unit span takes that **same colour at 60%
/// of its own alpha** — a multiplier on the value's alpha, not an absolute
/// alpha — rather than staying pinned to [LiftColors.textDim] or fully
/// inheriting the value's colour. Multiplying, instead of setting an
/// absolute alpha, is what makes the default path byte-identical: `textDim`
/// (`0x99EEF2F6`) *is* `textPrimary` (`0xFFEEF2F6`) at 60% opacity, so
/// `null` still resolves to `textPrimary.withValues(alpha: 1.0 * 0.6)` ==
/// `textDim`. It also guarantees the unit is strictly more transparent than
/// its value for every input, including colours that already carry alpha
/// below 1.0 — an absolute `withValues(alpha: 0.6)` would fail that for any
/// caller colour with alpha <= 0.6. Two colour-locked alternatives were
/// considered and rejected: pinning the unit to `textDim` regardless of
/// [color] reads as "a different datum" next to a saturated
/// `error`/`actionTint` value (the unit visually detaches from the number
/// it qualifies), and letting the unit inherit [color] at full strength
/// defeats the "small and dim" subordination this widget exists to
/// express.
///
/// The cost of multiplying is at the low end, and it is not clamped away.
/// `textPrimary` (α 1.00) yields a unit at α 0.60, exactly `textDim`;
/// `textSecondary` (α 0.70) yields α 0.42, about `textDisabled`; `textDim`
/// (α 0.60) yields α 0.36, below every text token in the palette. At
/// [LiftText.dataMeta] the unit renders at roughly `12 * 0.42 ≈ 5px`, and
/// 5px at 36% alpha on this app's ground is not readable. So scope [color]
/// to full-alpha status and accent colours; passing an already-translucent
/// colour compounds the two reductions and the unit disappears. There is
/// deliberately no silent floor — clamping would hand a caller back a
/// colour it did not ask for, which is its own trap.
///
/// [color] takes the **tint** role, never `LiftColors.actionFill` —
/// `actionFill` is a fill for surfaces carrying a white label and measures
/// 1.98:1 as a foreground on this ground.
class LiftNumber extends StatelessWidget {
  const LiftNumber(
    this.value,
    this.unit,
    this.style, {
    this.color,
    this.textAlign,
    super.key,
  }) : _numeric = null,
       _decimals = 0;

  /// Formats [numeric] to [decimals] places, then renders it.
  const LiftNumber.of(
    num numeric,
    this.unit,
    this.style, {
    int decimals = 0,
    this.color,
    this.textAlign,
    super.key,
  }) : value = '',
       _numeric = numeric,
       _decimals = decimals;

  final String value;
  final String unit;
  final TextStyle style;

  /// Overrides the value span's colour. Defaults to [LiftColors.textPrimary]
  /// when `null`. See the class doc comment for the unit-span rule this
  /// drives.
  final Color? color;
  final TextAlign? textAlign;

  final num? _numeric;
  final int _decimals;

  String get _text =>
      _numeric == null ? value : _numeric.toStringAsFixed(_decimals);

  @override
  Widget build(BuildContext context) {
    final Color valueColor = color ?? LiftColors.textPrimary;
    return Text.rich(
      TextSpan(
        text: _text,
        style: style.copyWith(
          color: valueColor,
          fontFeatures: LiftText.dataFeatures,
        ),
        children: unit.isEmpty
            ? null
            : <InlineSpan>[
                TextSpan(
                  text: unit,
                  style: style.copyWith(
                    fontSize: style.fontSize! * 0.42,
                    fontWeight: FontWeight.w500,
                    color: valueColor.withValues(alpha: valueColor.a * 0.6),
                  ),
                ),
              ],
      ),
      textAlign: textAlign,
    );
  }
}
