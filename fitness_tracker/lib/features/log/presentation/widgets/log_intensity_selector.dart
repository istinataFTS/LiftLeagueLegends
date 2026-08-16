import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/lift_theme.dart';

/// Effort as a counted ladder (frame 02). Height encodes the value and the hue
/// never changes — deliberately distinct from the muscle map's fatigue ramp,
/// which is a white-density fill the user does not choose.
class LogIntensitySelector extends StatelessWidget {
  const LogIntensitySelector({
    super.key,
    required this.intensity,
    required this.onChanged,
  });

  final int intensity;
  final ValueChanged<int> onChanged;

  /// Rung heights, matching the ladder in the design spec.
  static const List<double> _heights = <double>[9, 15, 21, 27, 33, 38];

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
            children: List<Widget>.generate(_heights.length, (int i) {
              final bool selected = i == level;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
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
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List<Widget>.generate(_heights.length, (int i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 5),
                child: Text(
                  '$i',
                  textAlign: TextAlign.center,
                  style: LiftText.dataMeta.copyWith(
                    color: i == level
                        ? LiftColors.actionTint
                        : LiftColors.textDim,
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
