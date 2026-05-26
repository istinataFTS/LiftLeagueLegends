import 'package:fitness_tracker/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppShell smoke test', () {
    testWidgets('boots the root app shell without production DI', (
      tester,
    ) async {
      await tester.pumpWidget(
        const AppShell(
          home: Scaffold(body: Center(child: Text('Boot OK'))),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Boot OK'), findsOneWidget);
    });
  });
}
