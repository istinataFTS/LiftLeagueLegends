import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/themes/lift_theme.dart';

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
///
/// **Every keystroke commits.** [onChanged] fires on each digit, dot, and
/// backspace, so the field above already holds the typed value before the
/// keypad closes — there is nothing to confirm. The ✓ / `Done` key only
/// dismisses the keypad, which is why it is labelled as a dismissal and not
/// as a submit.
class LogNumericKeypad extends StatefulWidget {
  const LogNumericKeypad({
    super.key,
    required this.initialValue,
    required this.label,
    required this.onChanged,
    required this.onDone,
    this.unitSuffix = '',
    this.allowDecimal = false,
    this.maxIntegerDigits = 4,
  });

  final num initialValue;
  final String label;
  final String unitSuffix;
  final bool allowDecimal;
  final int maxIntegerDigits;

  /// Fired on every keystroke with the value typed so far.
  final ValueChanged<num> onChanged;

  /// Dismisses the keypad. The value is already committed.
  final VoidCallback onDone;

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

  /// Publishes the value typed so far. Called after every mutation of
  /// [_input] so the parent's field tracks the keypad live.
  ///
  /// A trailing `.` is a half-typed number, not a zero: `8.` publishes 8 and
  /// waits for the fraction. Without that, pressing the decimal point would
  /// blank the field the user is looking at.
  void _emit() {
    if (_input.isEmpty) {
      widget.onChanged(0);
      return;
    }

    final num? parsed = num.tryParse(_input);
    if (parsed != null) {
      widget.onChanged(parsed);
      return;
    }

    final num? withoutTrailingDot = num.tryParse(_input.replaceAll('.', ''));
    if (withoutTrailingDot != null) {
      widget.onChanged(withoutTrailingDot);
    }
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
    _emit();
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
    _emit();
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
    _emit();
  }

  String get _displayValue => _input.isEmpty ? '0' : _input;

  // ─── Build ──────────────────────────────────────────────────────────────────

  // The keypad is a real panel that floats over content — unlike almost
  // everything else in this restyle it keeps an opaque surface so digits
  // stay readable no matter what is behind it.
  //
  // The key fill itself, [LiftColors.surfaceRaised] (white at 12% alpha —
  // 0x1FFFFFFF), is translucent, but it is only ever painted over the
  // panel's own opaque [LiftColors.panelTop] (0xF01E262F, effectively RGB
  // 30/38/47 once its own near-total alpha is accounted for). Compositing
  // surfaceRaised over panelTop's RGB gives approximately RGB(57, 64, 72) —
  // a slightly lighter slate than the panel, which is exactly the subtle
  // "raised key" contrast this token is used for elsewhere in the palette.
  // Kept deliberately rather than swapped for an opaque literal.
  static const Color _keyBg = LiftColors.surfaceRaised;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('log-numeric-keypad-panel'),
      decoration: const BoxDecoration(
        color: LiftColors.panelTop,
        border: Border(
          top: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _buildHeader(),
          const Divider(height: 1, color: LiftColors.rule),
          Padding(
            padding: const EdgeInsets.all(8),
            child: widget.allowDecimal
                ? _buildDecimalGrid()
                : _buildIntegerGrid(),
          ),
        ],
      ),
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
            style: LiftText.bodyMedium.copyWith(color: LiftColors.textDim),
          ),
          Row(
            children: <Widget>[
              Text(
                _displayValue,
                style: LiftText.dataMedium.copyWith(
                  color: LiftColors.textPrimary,
                  fontFeatures: LiftText.dataFeatures,
                ),
              ),
              if (widget.unitSuffix.isNotEmpty) ...<Widget>[
                const SizedBox(width: 4),
                Text(
                  widget.unitSuffix,
                  style: LiftText.bodyMedium.copyWith(
                    color: LiftColors.textDim,
                  ),
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
                LiftColors.textPrimary,
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
                LiftColors.textPrimary,
                onTap: () => _onDigit('0'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '✓',
                LiftColors.actionFill,
                Colors.white,
                isSpecial: true,
                semanticLabel: 'Close keypad',
                onTap: widget.onDone,
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
                LiftColors.textPrimary,
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
                LiftColors.textPrimary,
                onTap: () => _onDigit('0'),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _keyCell(
                '⌫',
                _keyBg,
                LiftColors.textPrimary,
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
            label: 'Close keypad',
            child: ElevatedButton(
              onPressed: widget.onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: LiftColors.actionFill,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Done', style: LiftText.titleMedium),
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
              LiftColors.textPrimary,
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
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: LiftText.dataMedium.copyWith(
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
