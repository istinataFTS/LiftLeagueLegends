import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter/services.dart';

import '../../../../../core/themes/app_theme.dart';

/// Bordered stepper cell: label on top, [− value +] row below.
/// The value text is tappable (dashed underline) and calls [onTapValue]
/// to open a [LogNumericKeypad] in the parent's dock.
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
    this.accentColor = AppTheme.primaryOrange,
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

  String _formatValue() {
    if (!allowDecimal) return value.round().toString();
    final double rounded = (value * 10).round() / 10.0;
    return rounded.toStringAsFixed(1);
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
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!dense) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textDim,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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
                          color: accentColor,
                          fontSize: 24,
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
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatValue(),
                      style: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                        decoration: onTapValue != null
                            ? TextDecoration.underline
                            : null,
                        decorationStyle: TextDecorationStyle.dashed,
                        decorationColor: AppTheme.textDim,
                      ),
                    ),
                  ),
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
                          fontSize: 24,
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
      ),
    );
  }
}
