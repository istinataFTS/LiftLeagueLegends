import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/themes/app_theme.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';

void main() {
  test('the accent resolves to the tint role', () {
    expect(AppTheme.primaryOrange, LiftColors.actionTint);
    expect(AppTheme.primaryOrangeLight, LiftColors.actionTint);
  });

  test('text ramp resolves to Deep Mist', () {
    expect(AppTheme.textLight, LiftColors.textPrimary);
    expect(AppTheme.textMedium, LiftColors.textSecondary);
    expect(AppTheme.textDim, LiftColors.textDim);
    expect(AppTheme.textDisabled, LiftColors.textDisabled);
  });

  test('the muscle ramp is white density, not green', () {
    expect(AppTheme.intensityNone, LiftColors.fatigue[0]);
    expect(AppTheme.intensityVeryHigh, LiftColors.fatigue[4]);
  });

  test('status colours resolve to Deep Mist', () {
    expect(AppTheme.errorRed, LiftColors.error);
    expect(AppTheme.successGreen, LiftColors.success);
    expect(AppTheme.warningAmber, LiftColors.warning);
  });
}
