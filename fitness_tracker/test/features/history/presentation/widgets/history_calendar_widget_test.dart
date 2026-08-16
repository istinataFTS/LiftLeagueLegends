import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/features/history/presentation/models/day_activity.dart';
import 'package:fitness_tracker/features/history/presentation/widgets/history_calendar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/phone_viewport.dart';

void main() {
  final DateTime month = DateTime(2026, 8, 1);
  final DateTime today = DateTime(2026, 8, 8);

  final Map<DateTime, DayActivity> activity = <DateTime, DayActivity>{
    DateTime(2026, 8, 3): const DayActivity(exerciseSets: 3, nutritionLogs: 0),
    DateTime(2026, 8, 5): const DayActivity(exerciseSets: 1, nutritionLogs: 0),
    DateTime(2026, 8, 6): const DayActivity(exerciseSets: 0, nutritionLogs: 2),
    DateTime(2026, 8, 8): const DayActivity(exerciseSets: 3, nutritionLogs: 4),
  };

  Widget buildSubject({
    DateTime? selectedDate,
    void Function(DateTime)? onDateSelected,
  }) {
    return AppShell(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HistoryCalendarWidget(
            displayedMonth: month,
            selectedDate: selectedDate,
            today: today,
            dayActivity: activity,
            weekStartDay: WeekStartDay.monday,
            onDateSelected: onDateSelected ?? (_) {},
          ),
        ),
      ),
    );
  }

  Finder underlines() => find.byWidgetPredicate(
    (Widget w) => w is ColoredBox && w.color == LiftColors.actionTint,
  );

  group('HistoryCalendarWidget', () {
    testWidgets('frame 08 header: uppercase month, no chevrons, no Today', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('AUGUST 2026'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(find.text('Today'), findsNothing);
      expectNoOverflow(tester);
    });

    testWidgets('logged days carry a tint underline and nothing else does', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // Exactly one underline per logged day — August 3, 5, 6 and 8.
      expect(underlines(), findsNWidgets(activity.length));
    });

    testWidgets('the pre-restyle activity dots are gone', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // The old grid drew an amber and a green circle under each active day.
      // The frame encodes the same fact in the underline, once.
      final Iterable<BoxDecoration> circles = tester
          .widgetList<Container>(find.byType(Container))
          .map((Container c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((BoxDecoration d) => d.shape == BoxShape.circle);

      expect(circles, isEmpty);
    });

    testWidgets('today takes a tint outline over a wash fill', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final BoxDecoration decoration = _cellDecoration(tester, '8');

      expect(decoration.color, LiftColors.actionWash);
      expect((decoration.border! as Border).top.width, LiftShape.borderWidth);
      expect((decoration.border! as Border).top.color, LiftColors.actionTint);
    });

    testWidgets('the selected day takes the heavier active border', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(selectedDate: DateTime(2026, 8, 5)),
      );

      expect(
        (_cellDecoration(tester, '5').border! as Border).top.width,
        LiftShape.borderWidthActive,
      );
    });

    testWidgets('future days do not report a tap', (WidgetTester tester) async {
      final List<DateTime> tapped = <DateTime>[];

      await pumpAtPhoneWidth(tester, buildSubject(onDateSelected: tapped.add));

      await tester.tap(find.text('20'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isEmpty);

      await tester.tap(find.text('4'));
      await tester.pump();
      expect(tapped, <DateTime>[DateTime(2026, 8, 4)]);
    });
  });
}

/// Reads the [BoxDecoration] of the cell whose number is [day].
BoxDecoration _cellDecoration(WidgetTester tester, String day) {
  final Finder container = find.ancestor(
    of: find.text(day),
    matching: find.byType(Container),
  );

  return tester.widget<Container>(container.first).decoration! as BoxDecoration;
}
