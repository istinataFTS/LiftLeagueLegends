import 'package:flutter/material.dart';

import '../../../../core/themes/app_theme.dart';
import '../../../../domain/muscle_visual/muscle_visual_contract.dart';
import '../../application/exercise_insight.dart';

/// Renders the per-targeted-muscle fatigue chips + a trailing verdict word for
/// the Exercise tab's selector card (design spec §3.1).
///
/// Each chip is a colored dot + muscle display name + percent. The colors come
/// straight from [MuscleFatigue] (which copies `MuscleVisualData.color`), so the
/// chip can never disagree with the Home 2D human model.
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
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Text(
            'Fatigue',
            style: TextStyle(
              color: AppTheme.textDim,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            children: muscles.map(_buildChip).toList(),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            _verdict(),
            style: const TextStyle(
              color: AppTheme.textMedium,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(MuscleFatigue m) {
    // `empty` bucket maps to a transparent color in the locked palette — fall
    // back to a visible dim dot so the chip still reads as a recovered muscle.
    final Color dot = m.color == Colors.transparent
        ? AppTheme.textDim
        : m.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          m.displayName,
          style: const TextStyle(color: AppTheme.textMedium, fontSize: 12),
        ),
        const SizedBox(width: 4),
        Text(
          '${m.percent}%',
          style: const TextStyle(
            color: AppTheme.textDim,
            fontSize: 12,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
