import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/muscle_stimulus_constants.dart';
import '../../core/themes/app_theme.dart';

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: enabled ? AppTheme.textLight : AppTheme.textDim,
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
                  color: enabled ? AppTheme.primaryOrange : AppTheme.textDim,
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: enabled ? AppTheme.primaryOrange : AppTheme.textDim,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: enabled ? AppTheme.textMedium : AppTheme.textDim,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: enabled
                ? AppTheme.primaryOrange
                : AppTheme.textDim,
            inactiveTrackColor: enabled
                ? AppTheme.borderDark
                : AppTheme.surfaceDark,
            thumbColor: enabled ? AppTheme.primaryOrange : AppTheme.textDim,
            overlayColor: AppTheme.primaryOrange.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 14, // Large thumb for easy grabbing
            ),
            overlayShape: const RoundSliderOverlayShape(
              overlayRadius: 28, // Large touch target
            ),
            trackHeight: 6,
            valueIndicatorColor: AppTheme.primaryOrange,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
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
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? AppTheme.primaryOrange
                        : AppTheme.textDim,
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
          Icon(Icons.info_outline, color: AppTheme.primaryOrange, size: 28),
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
                color: AppTheme.primaryOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.currentIntensity,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppTheme.primaryOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$currentIntensity - ${MuscleStimulus.getIntensityLabel(currentIntensity)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    MuscleStimulus.getIntensityDescription(currentIntensity),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // All intensity levels
            Text(
              AppStrings.allIntensityLevels,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
        color: isCurrent
            ? AppTheme.primaryOrange.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? AppTheme.primaryOrange.withValues(alpha: 0.3)
              : AppTheme.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$level',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isCurrent
                      ? AppTheme.primaryOrange
                      : AppTheme.textLight,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isCurrent
                      ? AppTheme.primaryOrange
                      : AppTheme.textMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textMedium),
          ),
        ],
      ),
    );
  }
}
