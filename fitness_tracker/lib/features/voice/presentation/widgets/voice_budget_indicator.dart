import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/themes/app_theme.dart';
import '../../application/voice_bloc.dart';

/// Compact horizontal bar showing the user's daily voice budget.
/// Renders nothing when no budget data is available.
class VoiceBudgetIndicator extends StatelessWidget {
  const VoiceBudgetIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VoiceBloc, VoiceState>(
      buildWhen: (prev, curr) => prev.budget != curr.budget,
      builder: (context, state) {
        final budget = state.budget;
        if (budget == null) return const SizedBox.shrink();

        final fraction = budget.usedFraction;
        final barColor = fraction >= 0.9
            ? AppTheme.errorRed
            : fraction >= 0.7
            ? Colors.orange
            : AppTheme.primaryOrange;

        final remainingLabel =
            '\$${budget.remainingUsd.toStringAsFixed(3)} remaining today';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  backgroundColor: AppTheme.borderDark,
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                remainingLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppTheme.textMedium),
              ),
            ],
          ),
        );
      },
    );
  }
}
