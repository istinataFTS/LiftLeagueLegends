import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/constants/muscle_stimulus_constants.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../presentation/widgets/intensity_slider_widget.dart'
    show IntensityInfoDialog;
import 'shared/log_ui_colors.dart';

/// 0–5 intensity cell selector + full-ramp legend strip, replacing the old
/// [IntensitySliderWidget] on the Exercise tab (design spec §3, item 5).
///
/// The info button reuses the existing [IntensityInfoDialog] verbatim.
class LogIntensitySelector extends StatelessWidget {
  const LogIntensitySelector({
    super.key,
    required this.intensity,
    required this.onChanged,
  });

  final int intensity;
  final ValueChanged<int> onChanged;

  static const Color _inactiveCell = Color(0xFF161616);

  @override
  Widget build(BuildContext context) {
    final int level = intensity.clamp(
      MuscleStimulus.minIntensity,
      MuscleStimulus.maxIntensity,
    );
    final Color activeColor = LogUiColors.intensityRamp[level];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Text(
              AppStrings.intensity,
              style: TextStyle(
                color: AppTheme.textLight,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => IntensityInfoDialog(currentIntensity: level),
                ),
                icon: const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppTheme.primaryOrange,
                ),
                tooltip: AppStrings.intensityInfo,
              ),
            ),
            const Spacer(),
            Text(
              '$level · ${MuscleStimulus.getIntensityLabel(level)}',
              style: TextStyle(
                color: activeColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List<Widget>.generate(
            MuscleStimulus.maxIntensity - MuscleStimulus.minIntensity + 1,
            (int i) {
              final bool selected = i == level;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                  child: Semantics(
                    button: true,
                    selected: selected,
                    label: 'Intensity $i',
                    child: SizedBox(
                      height: 44,
                      child: Material(
                        color: selected
                            ? LogUiColors.intensityRamp[i]
                            : _inactiveCell,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: selected
                              ? BorderSide.none
                              : const BorderSide(color: AppTheme.borderDark),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: Text(
                              '$i',
                              style: TextStyle(
                                color: selected
                                    ? AppTheme.backgroundDark
                                    : AppTheme.textDim,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const <FontFeature>[
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            gradient: const LinearGradient(
              colors: LogUiColors.intensityRamp,
              stops: <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
