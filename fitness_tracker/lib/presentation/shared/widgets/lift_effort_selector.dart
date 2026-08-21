import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/themes/lift_theme.dart';

/// Effort picker: a row of six numbered cells over a narrow green-to-red
/// legend strip.
///
/// This is the pre-Deep-Mist picker restored. The rebuild that replaced it
/// encoded effort as rung *height* in a single hue; that read as six unlabelled
/// bars of different sizes and lost the one thing the ramp made obvious — that
/// 0 is a warm-up and 5 is failure. Value is carried by hue here
/// ([LiftColors.effortRamp]), and the strip beneath spells the whole ramp out
/// so a level's colour means something before it is selected.
///
/// The cells keep Deep Mist's shape language — square corners, 1.5px border,
/// no radius — rather than the 8px pills the original drew, so the control
/// still belongs to this app.
///
/// It lives above the feature layer because two features pick effort with it:
/// Log's Exercise tab and History's edit-set dialog. A History import of
/// `features/log/presentation/` would be a convention rule 8 violation, not a
/// style choice — the same reason `LiftTabSelector` sits here.
///
/// `ExerciseSetRow` and History's set rows are unaffected and still encode
/// effort by **count** of same-size marks in one hue. The two encodings are
/// deliberately different: the picker is a thing you choose from, the marks
/// are a value you read back.
class LiftEffortSelector extends StatelessWidget {
  const LiftEffortSelector({
    super.key,
    required this.intensity,
    required this.onChanged,
  });

  final int intensity;
  final ValueChanged<int> onChanged;

  static const double _cellHeight = 44;
  static const double _cellGap = 5;
  static const double _legendHeight = 6;

  @override
  Widget build(BuildContext context) {
    final int level = intensity.clamp(
      MuscleStimulus.minIntensity,
      MuscleStimulus.maxIntensity,
    );
    final int levelCount =
        MuscleStimulus.maxIntensity - MuscleStimulus.minIntensity + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'EFFORT',
              style: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
            ),
            const SizedBox(width: 12),
            // Flexible, not a Spacer + fixed Text: the readout is the widest
            // thing on this line at `5 · MAX EFFORT`, and the selector is
            // narrower inside History's edit dialog than it is on the Log
            // tab. Given a fixed slot it overflowed there.
            Expanded(
              child: Text(
                '$level · ${MuscleStimulus.getIntensityLabel(level).toUpperCase()}',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: LiftText.labelLarge.copyWith(
                  color: LiftColors.effortRamp[level],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          spacing: _cellGap,
          children: List<Widget>.generate(levelCount, (int i) {
            final bool selected = i == level;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Effort $i',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Container(
                    key: ValueKey<String>('effort-cell-$i'),
                    height: _cellHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? LiftColors.effortRamp[i]
                          : Colors.transparent,
                      border: selected
                          ? null
                          : const Border.fromBorderSide(
                              BorderSide(
                                color: LiftColors.border,
                                width: LiftShape.borderWidth,
                              ),
                            ),
                    ),
                    child: Text(
                      '$i',
                      style: LiftText.dataSmall.copyWith(
                        color: selected
                            ? LiftColors.background
                            : LiftColors.textDim,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontFeatures: LiftText.dataFeatures,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 10),
        Container(
          key: const ValueKey<String>('effort-legend-strip'),
          height: _legendHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: LiftColors.effortRamp),
          ),
        ),
      ],
    );
  }
}
