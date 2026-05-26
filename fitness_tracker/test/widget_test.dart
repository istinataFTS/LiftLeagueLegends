import 'package:fitness_tracker/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppShell renders provided home widget', (tester) async {
    await tester.pumpWidget(
      const AppShell(
        home: Scaffold(body: Center(child: Text('Smoke Test'))),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Smoke Test'), findsOneWidget);
  });
}
