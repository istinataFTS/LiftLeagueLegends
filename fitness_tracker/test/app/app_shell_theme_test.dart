import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';

void main() {
  testWidgets('AppShell uses LiftTheme and paints LiftGround', (tester) async {
    await tester.pumpWidget(const AppShell(home: Scaffold(body: Text('hi'))));

    final MaterialApp app = tester.widget<MaterialApp>(
      find.byType(MaterialApp),
    );
    expect(app.theme!.scaffoldBackgroundColor, Colors.transparent);
    expect(app.theme!.colorScheme.primary, LiftColors.actionFill);
    expect(app.themeMode, ThemeMode.dark);

    expect(find.byType(LiftGround), findsOneWidget);
  });
}
