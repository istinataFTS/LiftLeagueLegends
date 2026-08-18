import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/exercise_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

class FakeExerciseState extends Fake implements ExerciseState {}

void main() {
  late MockExerciseBloc bloc;

  final Exercise exercise = Exercise(
    id: 'ex-1',
    name: 'Bench Press',
    muscleGroups: const <String>['chest'],
    createdAt: DateTime(2026),
  );

  setUpAll(() {
    registerFallbackValue(FakeExerciseEvent());
    registerFallbackValue(FakeExerciseState());
  });

  setUp(() {
    bloc = MockExerciseBloc();
    when(() => bloc.state).thenReturn(ExercisesLoaded(<Exercise>[exercise]));
    whenListen<ExerciseState>(
      bloc,
      const Stream<ExerciseState>.empty(),
      initialState: ExercisesLoaded(<Exercise>[exercise]),
    );
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    Exercise? initial,
    VoidCallback? onDelete,
  }) async {
    tester.view.physicalSize = const Size(1176, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: LiftTheme.dark(),
        home: BlocProvider<ExerciseBloc>.value(
          value: bloc,
          child: Scaffold(
            body: ExerciseDialog(exercise: initial, onDelete: onDelete),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('create mode', () {
    testWidgets('titles the panel New exercise and offers no delete', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester);

      expect(find.text('New exercise'), findsOneWidget);
      expect(find.text('SAVE EXERCISE'), findsOneWidget);
      expect(find.byKey(ExerciseDialog.deleteButtonKey), findsNothing);
    });

    testWidgets('the panel is square, bordered and sits on panelTop', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester);

      final Container panel = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Container),
            )
            .first,
      );
      final BoxDecoration decoration = panel.decoration! as BoxDecoration;

      expect(decoration.color, LiftColors.panelTop);
      expect(decoration.borderRadius, isNull);
      expect(decoration.border!.top.color, LiftColors.borderStrong);
      expect(decoration.border!.top.width, LiftShape.borderWidth);
      expect(decoration.boxShadow, LiftElevation.elevated);
    });

    testWidgets('save stays disabled until a name and a muscle are given', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester);

      ElevatedButton save() => tester.widget<ElevatedButton>(
        find.byKey(ExerciseDialog.saveButtonKey),
      );
      expect(save().onPressed, isNull);

      await tester.enterText(
        find.byKey(ExerciseDialog.nameFieldKey),
        'Incline Cable Fly',
      );
      await tester.pumpAndSettle();
      expect(save().onPressed, isNull, reason: 'no muscle picked yet');

      await tester.tap(find.byKey(ExerciseDialog.muscleChipKey('chest')));
      await tester.pumpAndSettle();
      expect(save().onPressed, isNotNull);
    });

    testWidgets('the activation slider is a tint track with a square handle', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(ExerciseDialog.muscleChipKey('chest')));
      await tester.pumpAndSettle();

      final SliderThemeData sliderTheme = tester
          .widget<SliderTheme>(find.byType(SliderTheme).first)
          .data;

      expect(sliderTheme.activeTrackColor, LiftColors.actionTint);
      expect(sliderTheme.inactiveTrackColor, LiftColors.effortOff);
      expect(sliderTheme.thumbShape, isA<SquareSliderThumb>());
      expect(sliderTheme.trackHeight, 3);
    });

    testWidgets('the multiplier renders through LiftNumber with an x unit', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester);

      await tester.tap(find.byKey(ExerciseDialog.muscleChipKey('chest')));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.00'), findsOneWidget);
      final Text value = tester.widget<Text>(find.textContaining('1.00'));
      expect(value.textSpan!.toPlainText(), '1.00x');
    });
  });

  group('edit mode', () {
    testWidgets('titles the panel Edit exercise and pre-fills the name', (
      WidgetTester tester,
    ) async {
      await pumpDialog(tester, initial: exercise, onDelete: () {});

      expect(find.text('Edit exercise'), findsOneWidget);
      expect(find.text('SAVE CHANGES'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(ExerciseDialog.nameFieldKey))
            .controller!
            .text,
        'Bench Press',
      );
    });

    testWidgets('delete sits below save, in error, and fires once', (
      WidgetTester tester,
    ) async {
      int deletes = 0;
      await pumpDialog(tester, initial: exercise, onDelete: () => deletes++);

      final Finder delete = find.byKey(ExerciseDialog.deleteButtonKey);
      expect(delete, findsOneWidget);
      expect(
        tester.getTopLeft(delete).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(ExerciseDialog.saveButtonKey)).dy,
        ),
      );

      final Text label = tester.widget<Text>(find.text('DELETE EXERCISE'));
      final OutlinedButton button = tester.widget<OutlinedButton>(delete);
      expect(
        button.style!.foregroundColor!.resolve(<WidgetState>{}),
        LiftColors.error,
      );
      expect(label, isNotNull);

      await tester.tap(delete);
      await tester.pumpAndSettle();
      expect(deletes, 1);
    });
  });
}
