import 'dart:ui';

import 'package:flutter/material.dart' hide FontFeature;
import 'package:flutter/services.dart';

import '../../../../../core/themes/app_theme.dart';

/// In-layout numeric keypad — never the OS keyboard.
/// Intended to be swapped in place of the dock's normal content while editing.
///
/// **Integer layout** (rows 1–9 grid + ⌫ 0 ✓):
/// ```
/// [1][2][3]
/// [4][5][6]
/// [7][8][9]
/// [⌫][0][✓]
/// ```
///
/// **Decimal layout** (same + bottom row . 0 ⌫ + full-width Done):
/// ```
/// [1][2][3]
/// [4][5][6]
/// [7][8][9]
/// [.][0][⌫]
/// [   Done  ]
/// ```
///
/// First digit **replaces** the seeded [initialValue] ('fresh' flag);
/// subsequent digits append. Decimal is capped at 1 fractional digit.
/// Integer part is capped at [maxIntegerDigits] digits.
class LogNumericKeypad extends StatefulWidget {
  const LogNumericKeypad({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onSubmit,
    required this.onCancel,
    this.unitSuffix = '',
    this.allowDecimal = false,
    this.maxIntegerDigits = 4,
  });

  final num initialValue;
  final String label;
  final String unitSuffix;
  final bool allowDecimal;
  final int maxIntegerDigits;
  final ValueChanged<num> onSubmit;
  final VoidCallback onCancel;

  @override
  State<LogNumericKeypad> createState() => _LogNumericKeypadState();
}

class _LogNumericKeypadState extends State<LogNumericKeypad> {
  late String _input;
  bool _fresh = true;

  @override
  void initState() {
    super.initState();
    _input = _formatInitial(widget.initialValue);
  }

  String _formatInitial(num v) {
    if (!widget.allowDecimal) return v.round().toString();
    return ((v * 10).round() / 10.0).toStringAsFixed(1);
  }

  void _onDigit(String digit) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_fresh) {
        _input = digit;
        _fresh = false;
        return;
      }
      final int dotIndex = _input.indexOf('.');
      if (dotIndex >= 0) {
        // Already decimal — allow only 1 fractional digit.
        if (_input.length - dotIndex - 1 >= 1) return;
        _input += digit;
      } else {
        if (_input.length >= widget.maxIntegerDigits) return;
        _input += digit;
      }
    });
  }

  void _onDot() {
    if (!widget.allowDecimal) return;
    HapticFeedback.selectionClick();
    setState(() {
      _fresh = false;
      if (_input.contains('.')) return;
      if (_input.isEmpty) _input = '0';
      _input += '.';
    });
  }

  void _onBackspace() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_fresh) {
        _input = '';
        _fresh = false;
        return;
      }
      if (_input.isNotEmpty) {
        _input = _input.substring(0, _input.length - 1);
      }
    });
  }

  void _onSubmit() {
    final num val = num.tryParse(_input) ?? 0;
    widget.onSubmit(val);
  }

  String get _displayValue => _input.isEmpty ? '0' : _input;

  // ─── Build ──────────────────────────────────────────────────────────────────

  static const Color _keyBg = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildHeader(),
        const Divider(height: 1, color: AppTheme.borderDark),
        Padding(
          padding: const EdgeInsets.all(8),
          child: widget.allowDecimal
              ? _buildDecimalGrid()
              : _buildIntegerGrid(),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            'Enter ${widget.label}',
            style: const TextStyle(color: AppTheme.textDim, fontSize: 13),
          ),
          Row(
            children: <Widget>[
              Text(
                _displayValue,
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
              if (widget.unitSuffix.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  widget.unitSuffix,
                  style: const TextStyle(color: AppTheme.textDim, fontSize: 14),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegerGrid() {
    return Column(
      children: <Widget>[
        _digitRow(<String>['1', '2', '3']),
        const SizedBox(height: 6),
        _digitRow(<String>['4', '5', '6']),
        const SizedBox(height: 6),
        _digitRow(<String>['7', '8', '9']),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _keyCell(
                '⌫',
                _keyBg,
                AppTheme.textLight,
                isSpecial: true,
                semanticLabel: 'Backspace',
                onTap: _onBackspace,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '0',
                _keyBg,
                AppTheme.textLight,
                onTap: () => _onDigit('0'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '✓',
                AppTheme.primaryOrange,
                Colors.white,
                isSpecial: true,
                semanticLabel: 'Confirm',
                onTap: _onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDecimalGrid() {
    return Column(
      children: <Widget>[
        _digitRow(<String>['1', '2', '3']),
        const SizedBox(height: 6),
        _digitRow(<String>['4', '5', '6']),
        const SizedBox(height: 6),
        _digitRow(<String>['7', '8', '9']),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            Expanded(
              child: _keyCell(
                '.',
                _keyBg,
                AppTheme.textLight,
                isSpecial: true,
                semanticLabel: 'Decimal point',
                onTap: _onDot,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '0',
                _keyBg,
                AppTheme.textLight,
                onTap: () => _onDigit('0'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '⌫',
                _keyBg,
                AppTheme.textLight,
                isSpecial: true,
                semanticLabel: 'Backspace',
                onTap: _onBackspace,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: Semantics(
            button: true,
            label: 'Done',
            child: ElevatedButton(
              onPressed: _onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryOrange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _digitRow(List<String> digits) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < digits.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: _keyCell(
              digits[i],
              _keyBg,
              AppTheme.textLight,
              onTap: () => _onDigit(digits[i]),
            ),
          ),
        ],
      ],
    );
  }

  Widget _keyCell(
    String label,
    Color bg,
    Color fg, {
    bool isSpecial = false,
    String? semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: SizedBox(
        height: 48,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: isSpecial ? 18 : 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
