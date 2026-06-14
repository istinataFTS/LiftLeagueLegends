import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_date_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    required DateTime date,
    ValueChanged<DateTime>? onDateSelected,
  }) {
    return AppShell(
      home: Scaffold(
        body: LogDatePill(date: date, onDateSelected: onDateSelected ?? (_) {}),
      ),
    );
  }

  group('LogDatePill', () {
    testWidgets('shows Today when date is today', (tester) async {
      await tester.pumpWidget(buildSubject(date: DateTime.now()));
      await tester.pumpAndSettle();

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('shows formatted date for a past date', (tester) async {
      final DateTime past = DateTime(2024, 3, 15);
      await tester.pumpWidget(buildSubject(date: past));
      await tester.pumpAndSettle();

      expect(find.text('Mar 15'), findsOneWidget);
      expect(find.text('Today'), findsNothing);
    });

    testWidgets('shows calendar icon', (tester) async {
      await tester.pumpWidget(buildSubject(date: DateTime.now()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('shows chevron down icon', (tester) async {
      await tester.pumpWidget(buildSubject(date: DateTime.now()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('shows January date correctly', (tester) async {
      final DateTime jan = DateTime(2025, 1, 5);
      await tester.pumpWidget(buildSubject(date: jan));
      await tester.pumpAndSettle();

      expect(find.text('Jan 5'), findsOneWidget);
    });
  });
}
