import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/themes/lift_number.dart';
import '../../../../../core/themes/lift_theme.dart';

/// Stepper cell: label on top, [− value +] row below.
/// The value text is tappable and calls [onTapValue] to open a
/// [LogNumericKeypad] in the parent's dock.
///
/// Set [dense] to drop the top label row + outer vertical paddings for a
/// compact single-line variant (used by the Macros tab P/C/F rows). The 44×44
/// ±-button hit targets stay; only the label row collapses.
///
/// All ±/value interactions emit via [onChanged]; parent owns the value.
class LogStepperField extends StatelessWidget {
  const LogStepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onTapValue,
    this.step = 1,
    this.min = 0,
    this.accentColor = LiftColors.actionTint,
    this.allowDecimal = false,
    this.dense = false,
  });

  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final VoidCallback? onTapValue;
  final num step;
  final num min;
  final Color accentColor;
  final bool allowDecimal;
  final bool dense;

  /// Splits a decimal value so the fraction rides small and dim, matching
  /// frame 02's `37.0`. Integers render with no unit slot.
  LiftNumber _value() {
    if (!allowDecimal) {
      return LiftNumber(value.round().toString(), '', LiftText.dataHero);
    }
    final double rounded = (value * 10).round() / 10.0;
    final List<String> parts = rounded.toStringAsFixed(1).split('.');
    return LiftNumber(parts[0], '.${parts[1]}', LiftText.dataHero);
  }

  num _increment() {
    final num raw = value + step;
    if (!allowDecimal) return raw.round();
    return (raw * 10).round() / 10.0;
  }

  num _decrement() {
    final num raw = value - step;
    final num clamped = raw < min ? min : raw;
    if (!allowDecimal) return clamped.round();
    return (clamped * 10).round() / 10.0;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!dense) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: <Widget>[
            // Decrease button — ≥44 dp hit target
            Semantics(
              button: true,
              label: 'Decrease $label',
              child: SizedBox(
                width: 44,
                height: 44,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(_decrement());
                  },
                  child: Center(
                    child: Text(
                      '−',
                      style: TextStyle(
                        color: LiftColors.textFaint,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Value display — FittedBox(scaleDown) guarantees the
            // number shrinks to fit its slot instead of painting a
            // RenderFlex overflow stripe, however narrow the column or
            // however many digits the value grows to.
            Expanded(
              child: GestureDetector(
                onTap: onTapValue,
                child: FittedBox(fit: BoxFit.scaleDown, child: _value()),
              ),
            ),
            // Increase button — ≥44 dp hit target
            Semantics(
              button: true,
              label: 'Increase $label',
              child: SizedBox(
                width: 44,
                height: 44,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(_increment());
                  },
                  child: Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!dense) const SizedBox(height: 8),
      ],
    );
  }
}
