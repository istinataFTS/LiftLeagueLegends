import 'package:flutter/material.dart';

import '../../../../core/themes/lift_number.dart';
import '../../../../core/themes/lift_theme.dart';
import '../../../../domain/muscle_visual/muscle_visual_contract.dart';
import '../../application/exercise_insight.dart';

/// Renders the per-targeted-muscle fatigue indicators + a trailing verdict
/// word for the Exercise tab's selector card (design spec §3.1).
///
/// Each row is a 14x14 fatigue-ramp swatch, the muscle display name, and its
/// percent. The swatch uses the Deep Mist fatigue ramp
/// (`LiftColors.fatigue[bucket.index]`) rather than [MuscleFatigue.color].
///
/// Home's 2D human model has read the same ramp at the same index since PR
/// B3, so the two surfaces rank a muscle identically — that shared bucket
/// index and five-stop ramp is the whole of what they have in common. They
/// are not the same pixel: this chip paints the stop flat over the dark
/// ground, while Home composites it onto `LiftColors.bodyBase` and blends the
/// result through the muscle's overlay opacity over a darkened figure. And in
/// Home's volume mode the bucket encodes training stimulus against a
/// threshold rather than fatigue at all, so the same swatch tone can mean two
/// different quantities on the two screens.
class ExerciseFatigueChips extends StatelessWidget {
  const ExerciseFatigueChips({super.key, required this.muscles});

  final List<MuscleFatigue> muscles;

  /// Verdict derived from the worst (highest) bucket among displayed groups.
  String _verdict() {
    MuscleVisualBucket worst = MuscleVisualBucket.empty;
    for (final MuscleFatigue m in muscles) {
      if (m.bucket.index > worst.index) worst = m.bucket;
    }
    switch (worst) {
      case MuscleVisualBucket.empty:
      case MuscleVisualBucket.light:
        return 'fresh enough';
      case MuscleVisualBucket.moderate:
        return 'ready';
      case MuscleVisualBucket.heavy:
        return 'fatigued';
      case MuscleVisualBucket.maximum:
        return 'needs rest';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            'FATIGUE',
            style: LiftText.labelLarge.copyWith(color: LiftColors.textDim),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: muscles.map(_buildRow).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            _verdict(),
            textAlign: TextAlign.right,
            style: LiftText.bodyMedium.copyWith(
              color: LiftColors.textDim,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(MuscleFatigue m) {
    final Color swatch = LiftColors.fatigue[m.bucket.index];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(width: 14, height: 14, color: swatch),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            m.displayName.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
          ),
        ),
        const SizedBox(width: 6),
        LiftNumber('${m.percent}', '%', LiftText.dataMeta),
      ],
    );
  }
}
