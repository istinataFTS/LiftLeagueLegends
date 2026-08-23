import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_scope.dart';
import 'package:fitness_tracker/presentation/shared/widgets/collapsible_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSettingsCubit extends MockCubit<AppSettingsState>
    implements AppSettingsCubit {}

void main() {
  late MockAppSettingsCubit cubit;

  const AppSettings settings = AppSettings(
    notificationsEnabled: true,
    weekStartDay: WeekStartDay.monday,
    weightUnit: WeightUnit.kilograms,
  );

  setUp(() {
    cubit = MockAppSettingsCubit();
    const AppSettingsState state = AppSettingsState(
      settings: settings,
      isLoading: false,
      isSaving: false,
      hasLoaded: true,
      errorMessage: null,
    );
    when(() => cubit.state).thenReturn(state);
    whenListen<AppSettingsState>(
      cubit,
      const Stream<AppSettingsState>.empty(),
      initialState: state,
    );
    when(
      () => cubit.setSectionExpanded(any(), expanded: any(named: 'expanded')),
    ).thenAnswer((_) async => true);
  });

  Widget buildSubject({Widget? trailing}) {
    return BlocProvider<AppSettingsCubit>.value(
      value: cubit,
      child: MaterialApp(
        home: Scaffold(
          body: SettingsScope(
            child: CollapsibleSection(
              id: 'test.section',
              title: 'Workout history',
              subtitle: '3 sets',
              trailing: trailing,
              child: const Text('body'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpAt360(WidgetTester tester, Widget subject) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(subject);
    await tester.pumpAndSettle();
  }

  group('CollapsibleSection', () {
    testWidgets('the header ink target runs the full width', (
      WidgetTester tester,
    ) async {
      await pumpAt360(tester, buildSubject());

      // The press wash is the whole row, not a block clipped to the text
      // column that stops short of whatever sits on the right.
      final Rect ink = tester.getRect(find.byType(InkWell).first);
      expect(ink.left, 0);
      expect(ink.width, 360);
    });

    testWidgets('the press feedback is a wash, never a ripple', (
      WidgetTester tester,
    ) async {
      await pumpAt360(tester, buildSubject());

      final InkWell ink = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(ink.splashFactory, NoSplash.splashFactory);
      expect(ink.splashColor, Colors.transparent);
    });

    testWidgets('collapse and expand run the same animation in reverse', (
      WidgetTester tester,
    ) async {
      await pumpAt360(tester, buildSubject());
      expect(find.text('body'), findsOneWidget);

      final double open = tester.getSize(find.text('body')).height;

      // Collapsing: the body is still on screen, clipped, part way through.
      await tester.tap(find.text('Workout history'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('body'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('body'), findsNothing);

      // Expanding: same window, same clip, mirrored.
      await tester.tap(find.text('Workout history'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      expect(find.text('body'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(tester.getSize(find.text('body')).height, open);
    });

    testWidgets('a trailing control fires without collapsing the section', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await pumpAt360(
        tester,
        buildSubject(
          trailing: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const SizedBox(
              key: ValueKey<String>('trailing'),
              width: 44,
              height: 44,
              child: Icon(Icons.add),
            ),
          ),
        ),
      );

      // It sits inside the header's ink target so the wash covers it and it
      // reads as part of the section — and it still has to win the tap.
      final Rect ink = tester.getRect(find.byType(InkWell).first);
      final Rect trailing = tester.getRect(
        find.byKey(const ValueKey<String>('trailing')),
      );
      expect(ink.contains(trailing.center), isTrue);

      await tester.tap(find.byKey(const ValueKey<String>('trailing')));
      await tester.pumpAndSettle();

      expect(taps, 1);
      expect(find.text('body'), findsOneWidget);
    });

    testWidgets('a persisted collapsed state applies without animating', (
      WidgetTester tester,
    ) async {
      const AppSettingsState collapsed = AppSettingsState(
        settings: AppSettings(
          notificationsEnabled: true,
          weekStartDay: WeekStartDay.monday,
          weightUnit: WeightUnit.kilograms,
          uiExpansionState: <String, bool>{'test.section': false},
        ),
        isLoading: false,
        isSaving: false,
        hasLoaded: true,
        errorMessage: null,
      );
      when(() => cubit.state).thenReturn(collapsed);
      whenListen<AppSettingsState>(
        cubit,
        const Stream<AppSettingsState>.empty(),
        initialState: collapsed,
      );

      await pumpAt360(tester, buildSubject());

      expect(find.text('body'), findsNothing);
    });

    testWidgets('a toggle is persisted under the section id', (
      WidgetTester tester,
    ) async {
      await pumpAt360(tester, buildSubject());

      await tester.tap(find.text('Workout history'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 600));

      verify(
        () => cubit.setSectionExpanded('test.section', expanded: false),
      ).called(1);
    });
  });
}
