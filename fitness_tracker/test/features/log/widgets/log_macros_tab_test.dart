import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/ui/keypad_visibility_controller.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/macro_composition_bar.dart';
import 'package:fitness_tracker/injection/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

class FakeNutritionLogEvent extends Fake implements NutritionLogEvent {}

class FakeNutritionLogState extends Fake implements NutritionLogState {}

void main() {
  late MockNutritionLogBloc nutritionBloc;
  late KeypadVisibilityController keypadVisibility;

  setUpAll(() {
    registerFallbackValue(FakeNutritionLogEvent());
    registerFallbackValue(FakeNutritionLogState());
  });

  setUp(() {
    nutritionBloc = MockNutritionLogBloc();
    keypadVisibility = KeypadVisibilityController();
    if (sl.isRegistered<KeypadVisibilityController>()) {
      sl.unregister<KeypadVisibilityController>();
    }
    sl.registerSingleton<KeypadVisibilityController>(keypadVisibility);

    when(
      () => nutritionBloc.effects,
    ).thenAnswer((_) => const Stream<NutritionLogUiEffect>.empty());
    when(() => nutritionBloc.add(any())).thenReturn(null);

    when(() => nutritionBloc.state).thenReturn(NutritionLogInitial());
    whenListen(
      nutritionBloc,
      const Stream<NutritionLogState>.empty(),
      initialState: NutritionLogInitial(),
    );
  });

  tearDown(() {
    if (sl.isRegistered<KeypadVisibilityController>()) {
      sl.unregister<KeypadVisibilityController>();
    }
  });

  Widget buildSubject({
    NutritionLogState? blocState,
    DateTime? initialDate,
    MediaQueryData? mediaQuery,
  }) {
    final NutritionLogState seed = blocState ?? NutritionLogInitial();
    when(() => nutritionBloc.state).thenReturn(seed);
    whenListen(
      nutritionBloc,
      const Stream<NutritionLogState>.empty(),
      initialState: seed,
    );

    Widget child = Scaffold(body: LogMacrosTab(initialDate: initialDate));

    if (mediaQuery != null) {
      child = MediaQuery(data: mediaQuery, child: child);
    }

    return AppShell(
      home: BlocProvider<NutritionLogBloc>.value(
        value: nutritionBloc,
        child: child,
      ),
    );
  }

  group('LogMacrosTab', () {
    testWidgets(
      'renders three dense steppers (no top label, − value + visible) '
      'and no info line',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(initialDate: DateTime(2026, 6, 14)),
        );
        await tester.pumpAndSettle();

        // Info line removed.
        expect(
          find.text('No meal in your library? Enter macros directly.'),
          findsNothing,
        );
        expect(find.byIcon(Icons.info_outline), findsNothing);

        // Dense flag drops the top 'grams' label inside each stepper.
        expect(find.text('grams'), findsNothing);

        // Each macro row keeps its name label + −/value/+ trio.
        for (final String label in <String>['Protein', 'Carbs', 'Fats']) {
          expect(find.text(label), findsOneWidget);
          final Finder stepper = find.byKey(Key('macrosStepper-$label'));
          expect(stepper, findsOneWidget);
          expect(
            find.descendant(of: stepper, matching: find.text('−')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: stepper, matching: find.text('+')),
            findsOneWidget,
          );
          expect(
            find.descendant(of: stepper, matching: find.text('0.0')),
            findsOneWidget,
          );
        }
      },
    );

    testWidgets('on first build dispatches LoadDailyLogsEvent for the date', (
      tester,
    ) async {
      final DateTime date = DateTime(2026, 6, 14);
      await tester.pumpWidget(buildSubject(initialDate: date));
      await tester.pump();

      verify(
        () => nutritionBloc.add(
          any(
            that: isA<LoadDailyLogsEvent>().having(
              (LoadDailyLogsEvent e) => e.date,
              'date',
              date,
            ),
          ),
        ),
      ).called(1);
    });

    testWidgets(
      'does not re-dispatch LoadDailyLogsEvent when state already loaded for date',
      (tester) async {
        final DateTime date = DateTime(2026, 6, 14);
        await tester.pumpWidget(
          buildSubject(
            initialDate: date,
            blocState: DailyLogsLoaded(
              date: date,
              logs: const <NutritionLog>[],
              dailyMacros: const <String, double>{
                'protein': 0,
                'carbs': 0,
                'fats': 0,
                'calories': 0,
              },
            ),
          ),
        );
        await tester.pump();

        verifyNever(
          () => nutritionBloc.add(any(that: isA<LoadDailyLogsEvent>())),
        );
      },
    );

    testWidgets(
      'stepper + button updates a macro; preview calories reflect new value',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(initialDate: DateTime(2026, 6, 14)),
        );
        await tester.pumpAndSettle();

        // Tap protein stepper "+" — step 5 → 5g protein → 20 kcal.
        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('macrosStepper-Protein')),
            matching: find.text('+'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('20'), findsOneWidget); // kcal hero number.
      },
    );

    testWidgets(
      'Log macros dispatches AddNutritionLogEvent with entered macros',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(initialDate: DateTime(2026, 6, 14)),
        );
        await tester.pumpAndSettle();

        // Bump each macro once: P=5, C=5, F=5 (step = 5).
        for (final String label in <String>['Protein', 'Carbs', 'Fats']) {
          await tester.tap(
            find.descendant(
              of: find.byKey(Key('macrosStepper-$label')),
              matching: find.text('+'),
            ),
          );
        }
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.logMacrosButton));
        await tester.pump();

        verify(
          () => nutritionBloc.add(
            any(
              that: isA<AddNutritionLogEvent>()
                  .having(
                    (AddNutritionLogEvent e) => e.log.mealId,
                    'mealId',
                    null,
                  )
                  .having(
                    (AddNutritionLogEvent e) => e.log.mealName,
                    'mealName',
                    'Direct Macro Entry',
                  )
                  .having(
                    (AddNutritionLogEvent e) => e.log.proteinGrams,
                    'protein',
                    5.0,
                  )
                  .having(
                    (AddNutritionLogEvent e) => e.log.carbsGrams,
                    'carbs',
                    5.0,
                  )
                  .having(
                    (AddNutritionLogEvent e) => e.log.fatGrams,
                    'fats',
                    5.0,
                  )
                  .having(
                    (AddNutritionLogEvent e) => e.log.calories,
                    'calories',
                    closeTo(5 * 4 + 5 * 4 + 5 * 9, 0.0001),
                  ),
            ),
          ),
        ).called(1);
      },
    );

    testWidgets('Today so far renders when date matches and label is "Today"', (
      tester,
    ) async {
      final DateTime today = DateTime.now();
      final DateTime dateOnly = DateTime(today.year, today.month, today.day);
      await tester.pumpWidget(
        buildSubject(
          initialDate: dateOnly,
          blocState: DailyLogsLoaded(
            date: dateOnly,
            logs: <NutritionLog>[
              NutritionLog(
                id: 'a',
                mealId: null,
                mealName: 'x',
                gramsConsumed: null,
                proteinGrams: 30,
                carbsGrams: 40,
                fatGrams: 10,
                calories: 30 * 4 + 40 * 4 + 10 * 9,
                loggedAt: dateOnly,
                createdAt: dateOnly,
              ),
            ],
            dailyMacros: const <String, double>{
              'protein': 30,
              'carbs': 40,
              'fats': 10,
              'calories': 370,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Today so far'), findsOneWidget);
      expect(find.text('370 kcal · 1 log'), findsOneWidget);
      expect(find.text('30g'), findsOneWidget);
      expect(find.text('40g'), findsOneWidget);
      expect(find.text('10g'), findsOneWidget);
    });

    testWidgets(
      'Today so far hides when loaded date does not match selected date',
      (tester) async {
        final DateTime selected = DateTime(2026, 6, 14);
        final DateTime other = DateTime(2026, 6, 13);
        await tester.pumpWidget(
          buildSubject(
            initialDate: selected,
            blocState: DailyLogsLoaded(
              date: other,
              logs: const <NutritionLog>[],
              dailyMacros: const <String, double>{
                'protein': 99,
                'carbs': 99,
                'fats': 99,
                'calories': 1234,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Today so far'), findsNothing);
        expect(find.textContaining('so far'), findsNothing);
        expect(find.text('1234 kcal · 0 logs'), findsNothing);
      },
    );

    testWidgets(
      'Today so far renders with date label when selected date is not today',
      (tester) async {
        // Pick a fixed past date — guaranteed not to be "today".
        final DateTime past = DateTime(2024, 1, 5);
        await tester.pumpWidget(
          buildSubject(
            initialDate: past,
            blocState: DailyLogsLoaded(
              date: past,
              logs: const <NutritionLog>[],
              dailyMacros: const <String, double>{
                'protein': 0,
                'carbs': 0,
                'fats': 0,
                'calories': 0,
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Jan 5 so far'), findsOneWidget);
        expect(find.text('Today so far'), findsNothing);
      },
    );

    testWidgets('keypad opens on stepper value tap and submits via Done', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(initialDate: DateTime(2026, 6, 14)));
      await tester.pumpAndSettle();

      // Tap the protein stepper value (initial '0.0').
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('macrosStepper-Protein')),
          matching: find.text('0.0'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enter protein'), findsOneWidget);

      // Enter 25, confirm via decimal-grid Done.
      await tester.tap(find.text('2'));
      await tester.tap(find.text('5'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Stepper now shows 25.0; calories hero = 25 * 4 = 100.
      expect(
        find.descendant(
          of: find.byKey(const Key('macrosStepper-Protein')),
          matching: find.text('25.0'),
        ),
        findsOneWidget,
      );
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('reduced-motion: composition bar still renders (no jank)', (
      tester,
    ) async {
      final DateTime today = DateTime.now();
      final DateTime dateOnly = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        buildSubject(
          initialDate: dateOnly,
          mediaQuery: const MediaQueryData(disableAnimations: true),
          blocState: DailyLogsLoaded(
            date: dateOnly,
            logs: const <NutritionLog>[],
            dailyMacros: const <String, double>{
              'protein': 10,
              'carbs': 10,
              'fats': 10,
              'calories': 170,
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both composition bars present (today + this entry, even though
      // "this entry" is 0/0/0 → renders empty track).
      expect(find.byType(LogMacrosTab), findsOneWidget);
      // Two composition bars (today + this entry).
      expect(find.byType(MacroCompositionBar), findsNWidgets(2));
    });

    testWidgets(
      'opening the keypad flips KeypadVisibilityController.isOpen to true; '
      'cancel restores it',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(initialDate: DateTime(2026, 6, 14)),
        );
        await tester.pumpAndSettle();

        expect(keypadVisibility.isOpen.value, isFalse);

        await tester.tap(
          find.descendant(
            of: find.byKey(const Key('macrosStepper-Protein')),
            matching: find.text('0.0'),
          ),
        );
        await tester.pumpAndSettle();

        expect(keypadVisibility.isOpen.value, isTrue);

        // Macros keypad allows decimals → confirms via Done.
        await tester.tap(find.text('2'));
        await tester.tap(find.text('5'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(keypadVisibility.isOpen.value, isFalse);
      },
    );
  });
}
