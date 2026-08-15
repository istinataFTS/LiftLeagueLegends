import 'package:flutter/material.dart';

import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';

/// One row in the Exercise tab's set feed (frame 02): index, effort marks, and
/// the weight × reps pair right-aligned. Rows are divided by a hairline — the
/// card, the pill and the gradient bar are gone.
class ExerciseSetRow extends StatelessWidget {
  const ExerciseSetRow({
    super.key,
    required this.setNumber,
    required this.intensity,
    required this.weightText,
    required this.reps,
  });

  final int setNumber;
  final int intensity;

  /// Already formatted in the user's unit, e.g. `80 kg`.
  final String weightText;
  final int reps;

  /// Splits `80 kg` into `('80', 'kg')` so the unit can ride the value.
  /// A value with no space stays whole with an empty unit.
  static (String, String) _split(String text) {
    final int i = text.indexOf(' ');
    if (i < 0) return (text, '');
    return (text.substring(0, i), text.substring(i + 1));
  }

  @override
  Widget build(BuildContext context) {
    final int level = intensity.clamp(0, 5);
    final (String value, String unit) = _split(weightText);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: LiftColors.hairline, width: 1),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(
            setNumber.toString().padLeft(2, '0'),
            style: LiftText.dataMeta.copyWith(color: LiftColors.textDim),
          ),
          const SizedBox(width: 22),
          Row(
            children: List<Widget>.generate(5, (int i) {
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 3),
                child: Container(
                  key: ValueKey<String>('set-effort-mark-$i'),
                  width: 11,
                  height: 15,
                  decoration: BoxDecoration(
                    color: i < level
                        ? LiftColors.effortOn
                        : LiftColors.effortOff,
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          LiftNumber(value, unit, LiftText.dataSmall),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '×',
              style: LiftText.dataSmall.copyWith(color: LiftColors.textDim),
            ),
          ),
          LiftNumber('$reps', '', LiftText.dataSmall),
        ],
      ),
    );
  }
}
