import 'package:flutter/material.dart';

import 'lift_theme.dart';

/// A quantity rendered in tabular mono with its unit riding small and dim.
///
/// Use this when the unit is glued to the value (`155g`, `15kg`, `1.00x`).
/// When the unit is a spaced word (`2792 KCAL`, `1134 KG TOTAL`) it is a
/// separate [LiftText.labelMedium] caps label instead — not this widget.
class LiftNumber extends StatelessWidget {
  const LiftNumber(
    this.value,
    this.unit,
    this.style, {
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
    this.textAlign,
    super.key,
  }) : value = '',
       _numeric = numeric,
       _decimals = decimals;

  final String value;
  final String unit;
  final TextStyle style;
  final TextAlign? textAlign;

  final num? _numeric;
  final int _decimals;

  String get _text =>
      _numeric == null ? value : _numeric.toStringAsFixed(_decimals);

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: _text,
        style: style.copyWith(
          color: LiftColors.textPrimary,
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
                    color: LiftColors.textDim,
                  ),
                ),
              ],
      ),
      textAlign: textAlign,
    );
  }
}
