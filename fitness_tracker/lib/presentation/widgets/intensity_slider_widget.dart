import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/muscle_stimulus_constants.dart';
import '../../core/themes/lift_theme.dart';

/// Intensity slider widget for workout set logging
class IntensitySliderWidget extends StatelessWidget {
  final int intensity;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const IntensitySliderWidget({
    Key? key,
    required this.intensity,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final clampedIntensity = MuscleStimulus.clampIntensity(intensity);
    final label = MuscleStimulus.getIntensityLabel(clampedIntensity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with label and info icon
        Row(
          children: [
            Text(
              AppStrings.intensity,
              style: LiftText.titleMedium.copyWith(
                color: enabled ? LiftColors.textPrimary : LiftColors.textDim,
              ),
            ),
            const SizedBox(width: 8),
            // Info icon button (44x44 touch target)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: enabled ? () => _showInfoDialog(context) : null,
                icon: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: enabled ? LiftColors.actionTint : LiftColors.textDim,
                ),
                tooltip: AppStrings.intensityInfo,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Current value display
        Row(
          children: [
            Text(
              '$clampedIntensity/${MuscleStimulus.maxIntensity}',
              style: LiftText.dataSmall.copyWith(
                color: enabled ? LiftColors.actionTint : LiftColors.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: LiftText.bodyLarge.copyWith(
                color: enabled ? LiftColors.textSecondary : LiftColors.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Slider — track and thumb come from LiftTheme.dark()'s sliderTheme;
        // the widget only supplies the disabled tint, which the theme cannot
        // express on its own.
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? null : LiftColors.textDim,
            thumbColor: enabled ? null : LiftColors.textDim,
          ),
          child: Slider(
            value: clampedIntensity.toDouble(),
            min: MuscleStimulus.minIntensity.toDouble(),
            max: MuscleStimulus.maxIntensity.toDouble(),
            divisions:
                MuscleStimulus.maxIntensity - MuscleStimulus.minIntensity,
            label: label,
            onChanged: enabled ? (value) => onChanged(value.toInt()) : null,
          ),
        ),

        // Intensity scale labels
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              MuscleStimulus.maxIntensity - MuscleStimulus.minIntensity + 1,
              (index) {
                final level = MuscleStimulus.minIntensity + index;
                final isSelected = level == clampedIntensity;
                return Text(
                  level.toString(),
                  style: LiftText.bodySmall.copyWith(
                    color: isSelected
                        ? LiftColors.actionTint
                        : LiftColors.textDim,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Show detailed intensity information dialog
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => IntensityInfoDialog(
        currentIntensity: MuscleStimulus.clampIntensity(intensity),
      ),
    );
  }
}

/// Dialog showing detailed intensity level information
class IntensityInfoDialog extends StatelessWidget {
  final int currentIntensity;

  const IntensityInfoDialog({Key? key, required this.currentIntensity})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: LiftColors.actionTint,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(AppStrings.intensityLevels),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Current intensity highlight
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LiftColors.actionWash,
                border: Border.all(color: LiftColors.actionTint),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.currentIntensity,
                    style: LiftText.titleSmall.copyWith(
                      color: LiftColors.actionTint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentIntensity - ${MuscleStimulus.getIntensityLabel(currentIntensity)}',
                    style: LiftText.titleMedium.copyWith(
                      color: LiftColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MuscleStimulus.getIntensityDescription(currentIntensity),
                    style: LiftText.bodyMedium.copyWith(
                      color: LiftColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // All intensity levels
            Text(
              AppStrings.allIntensityLevels,
              style: LiftText.titleSmall.copyWith(
                color: LiftColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // List all intensity levels
            ...List.generate(
              MuscleStimulus.maxIntensity - MuscleStimulus.minIntensity + 1,
              (index) {
                final level = MuscleStimulus.minIntensity + index;
                final isCurrent = level == currentIntensity;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildIntensityItem(
                    context,
                    level: level,
                    isCurrent: isCurrent,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(AppStrings.gotIt),
        ),
      ],
    );
  }

  Widget _buildIntensityItem(
    BuildContext context, {
    required int level,
    required bool isCurrent,
  }) {
    final label = MuscleStimulus.getIntensityLabel(level);
    final description = MuscleStimulus.getIntensityDescription(level);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? LiftColors.actionWash : Colors.transparent,
        border: Border.all(
          color: isCurrent ? LiftColors.actionTint : LiftColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$level',
                style: LiftText.titleMedium.copyWith(
                  color: isCurrent
                      ? LiftColors.actionTint
                      : LiftColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: LiftText.titleSmall.copyWith(
                  color: isCurrent
                      ? LiftColors.actionTint
                      : LiftColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: LiftText.bodySmall.copyWith(color: LiftColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
