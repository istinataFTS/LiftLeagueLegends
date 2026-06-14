import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
import 'shared/log_ui_colors.dart';

/// One row in the Exercise tab's "today's sets" feed (design spec §3.2):
/// `Set n` + a solid intensity pill + `<weight> × <reps>`, with an
/// intensity-sliced gradient bar beneath (fill = level/5).
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

  @override
  Widget build(BuildContext context) {
    final int level = intensity.clamp(0, 5);
    final Color rampColor = LogUiColors.intensityRamp[level];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: LogUiColors.rowSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Set $setNumber',
                style: const TextStyle(
                  color: AppTheme.textMedium,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _IntensityPill(level: level, color: rampColor),
              const Spacer(),
              Text(
                '$weightText × $reps',
                style: const TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IntensityBar(level: level),
        ],
      ),
    );
  }
}

class _IntensityPill extends StatelessWidget {
  const _IntensityPill({required this.level, required this.color});

  final int level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$level',
        style: const TextStyle(
          color: AppTheme.backgroundDark,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Track + fill where the fill reveals only the leftmost `level/5` slice of the
/// full 6-stop ramp gradient, with the gradient anchored to the *track* width
/// (not stretched into the fill). See design spec §3.2.
class _IntensityBar extends StatelessWidget {
  const _IntensityBar({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    final double fraction = level / 5.0;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double fullWidth = constraints.maxWidth;
        return SizedBox(
          height: 6,
          width: fullWidth,
          child: Stack(
            children: <Widget>[
              // Track
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.borderDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Fill: clip the full-width gradient to its leftmost `fraction`.
              ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction,
                  child: Container(
                    width: fullWidth,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      gradient: const LinearGradient(
                        colors: LogUiColors.intensityRamp,
                        stops: <double>[0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
