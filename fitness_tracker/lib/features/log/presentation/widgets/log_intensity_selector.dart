import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/lift_theme.dart';

/// Effort picker, from frame 02 (`02-log-exercise.png`) of the design
/// export. That export lives outside this repository and is not checked in,
/// so there is no `export/` directory to look for here. Rung **height**
/// is the value's channel: the six rungs grow taller left to right, and only
/// the rung at the selected index switches to `LiftColors.effortOn` — every
/// other rung stays `LiftColors.effortOff`. Nothing here is counted; a
/// "counted ladder" would be the wrong description. `ExerciseSetRow`'s marks
/// are the counted channel instead — its five marks are all the same size,
/// so count of filled marks is the only signal available to them, and they
/// fill cumulatively. Both encodings were confirmed by sampling the exported
/// frame's pixels; they are intentionally different and must not be
/// "harmonised" into one. The hue never changes here — deliberately distinct
/// from the muscle map's fatigue ramp, which is a white-density fill the
/// user does not choose.
class LogIntensitySelector extends StatelessWidget {
  const LogIntensitySelector({
    super.key,
    required this.intensity,
    required this.onChanged,
  });

  final int intensity;
  final ValueChanged<int> onChanged;

  /// Rung heights, matching the ladder in the design frame: its rungs
  /// measure 24, 42, 60, 78, 96, 114 image px, which is 8, 14, 20, 26, 32,
  /// 38 logical at 3x — a uniform `+6` step.
  static const List<double> _heights = <double>[8, 14, 20, 26, 32, 38];

  @override
  Widget build(BuildContext context) {
    final int level = intensity.clamp(
      MuscleStimulus.minIntensity,
      MuscleStimulus.maxIntensity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'EFFORT',
              style: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
            ),
            const Spacer(),
            Text(
              '$level · ${MuscleStimulus.getIntensityLabel(level).toUpperCase()}',
              style: LiftText.labelLarge.copyWith(color: LiftColors.actionTint),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            // `spacing`, not a per-child `Padding`: inside a tight `Expanded`
            // slot a left inset shrinks the rung's own box instead of
            // separating it, which made rung 0 render wider than the rest.
            spacing: 5,
            children: List<Widget>.generate(_heights.length, (int i) {
              final bool selected = i == level;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: 'Effort $i',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(i);
                    },
                    child: SizedBox(
                      height: 44,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          key: ValueKey<String>('effort-rung-$i'),
                          constraints: BoxConstraints(
                            minHeight: _heights[i],
                            maxHeight: _heights[i],
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? LiftColors.effortOn
                                : LiftColors.effortOff,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          // Same `spacing` as the rung row above, so each digit stays
          // centred under its own rung.
          spacing: 5,
          children: List<Widget>.generate(_heights.length, (int i) {
            return Expanded(
              child: Text(
                '$i',
                textAlign: TextAlign.center,
                style: LiftText.dataMeta.copyWith(
                  color: i == level
                      ? LiftColors.actionTint
                      : LiftColors.textDim,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
