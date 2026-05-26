import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/themes/app_theme.dart';
import '../voice_overlay_keys.dart';

/// Compact top banner shown when Workout Mode is active.
///
/// Signals that the screen will stay on and the wake word is armed for
/// the duration of the session. The user can dismiss or toggle via the
/// [onToggle] callback.
class VoiceWorkoutModeBanner extends StatelessWidget {
  const VoiceWorkoutModeBanner({required this.onToggle, super.key});

  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: VoiceOverlayKeys.workoutModeBannerKey,
        onTap: onToggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(color: AppTheme.primaryOrange),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.fitness_center_rounded,
                size: 14,
                color: AppTheme.textLight,
              ),
              SizedBox(width: 6),
              Text(
                AppStrings.voiceWorkoutModeBanner,
                style: TextStyle(
                  color: AppTheme.textLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.close_rounded, size: 14, color: AppTheme.textLight),
            ],
          ),
        ),
      ),
    );
  }
}
