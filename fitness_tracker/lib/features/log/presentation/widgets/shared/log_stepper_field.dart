import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter/services.dart';

import '../../../../../core/themes/app_theme.dart';

/// Bordered stepper cell: label on top, [− value +] row below.
/// The value text is tappable (dashed underline + edit icon) and calls [onTapValue]
/// to open a [LogNumericKeypad] in the parent's dock.
///
/// All ±/value interactions emit via [onChanged]; parent owns the value.
class LogStepperField extends StatelessWidget {
  const LogStepperField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onTapValue,
    this.unitSuffix = '',
    this.step = 1,
    this.min = 0,
    this.accentColor = AppTheme.primaryOrange,
    this.allowDecimal = false,
  });

  final String label;
  final num value;
  final ValueChanged<num> onChanged;
  final VoidCallback? onTapValue;
  final String unitSuffix;
  final num step;
  final num min;
  final Color accentColor;
  final bool allowDecimal;

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
              // Value display
              Expanded(
                child: GestureDetector(
                  onTap: onTapValue,
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Text(
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
                        if (unitSuffix.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 3),
                          Text(
                            unitSuffix,
                            style: const TextStyle(
                              color: AppTheme.textDim,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        if (onTapValue != null) ...<Widget>[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit,
                            size: 12,
                            color: AppTheme.textDim,
                          ),
                        ],
                      ],
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
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
