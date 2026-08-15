import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';

void main() {
  final ThemeData theme = LiftTheme.dark();

  test('scaffold is transparent so LiftGround shows through', () {
    expect(theme.scaffoldBackgroundColor, Colors.transparent);
  });

  test('primary is the fill role, secondary is the tint role', () {
    expect(theme.colorScheme.primary, LiftColors.actionFill);
    expect(theme.colorScheme.secondary, LiftColors.actionTint);
  });

  test('app bar is transparent, flat and untinted', () {
    expect(theme.appBarTheme.backgroundColor, Colors.transparent);
    expect(theme.appBarTheme.elevation, 0);
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
    expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'SpaceGrotesk');
  });

  test('cards are square, bordered and flat', () {
    final RoundedRectangleBorder shape =
        theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(shape.side.width, LiftShape.borderWidth);
    expect(theme.cardTheme.elevation, 0);
  });

  test('inputs are square and focus to tint', () {
    final OutlineInputBorder focused =
        theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder;
    expect(focused.borderRadius, BorderRadius.zero);
    expect(focused.borderSide.color, LiftColors.actionTint);
    expect(focused.borderSide.width, LiftShape.borderWidthActive);
    expect(theme.inputDecorationTheme.filled, isFalse);

    final OutlineInputBorder border =
        theme.inputDecorationTheme.border! as OutlineInputBorder;
    expect(border.borderRadius, BorderRadius.zero);
    expect(border.borderSide.width, LiftShape.borderWidth);

    final OutlineInputBorder enabledBorder =
        theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
    expect(enabledBorder.borderRadius, BorderRadius.zero);
    expect(enabledBorder.borderSide.width, LiftShape.borderWidth);

    final OutlineInputBorder errorBorder =
        theme.inputDecorationTheme.errorBorder! as OutlineInputBorder;
    expect(errorBorder.borderRadius, BorderRadius.zero);
    expect(errorBorder.borderSide.width, LiftShape.borderWidth);
  });

  test('chips never show a checkmark and are square', () {
    expect(theme.chipTheme.showCheckmark, isFalse);
    expect(theme.chipTheme.selectedColor, LiftColors.actionFill);

    final RoundedRectangleBorder shape =
        theme.chipTheme.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.zero);
    expect(theme.chipTheme.side!.width, LiftShape.borderWidth);
  });

  test('bottom nav selects with tint, not fill', () {
    expect(
      theme.bottomNavigationBarTheme.selectedItemColor,
      LiftColors.actionTint,
    );
    expect(
      theme.bottomNavigationBarTheme.unselectedItemColor,
      LiftColors.textDim,
    );
  });
}
