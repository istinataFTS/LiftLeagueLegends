import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/usecases/exercises/add_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/delete_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/ensure_default_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_all_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercise_by_id.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercises_for_muscle.dart';
import 'package:fitness_tracker/domain/usecases/exercises/update_exercise.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/get_muscle_factors_for_exercise.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/library/presentation/widgets/exercises_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockGetAllExercises extends Mock implements GetAllExercises {}

class MockGetExerciseById extends Mock implements GetExerciseById {}

class MockGetExercisesForMuscle extends Mock implements GetExercisesForMuscle {}

class MockAddExercise extends Mock implements AddExercise {}

class MockUpdateExercise extends Mock implements UpdateExercise {}

class MockDeleteExercise extends Mock implements DeleteExercise {}

class MockEnsureDefaultExercises extends Mock
    implements EnsureDefaultExercises {}

class MockGetMuscleFactorsForExercise extends Mock
    implements GetMuscleFactorsForExercise {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _exercise = Exercise(
  id: 'ex-1',
  name: 'Bench Press',
  muscleGroups: const <String>['chest', 'triceps'],
  createdAt: DateTime(2026),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _buildHarness(ExerciseBloc bloc) {
  return MaterialApp(
    home: Scaffold(
      body: BlocProvider<ExerciseBloc>.value(
        value: bloc,
        child: const ExercisesTab(),
      ),
    ),
  );
}

ExerciseBloc _makeBloc({
  required MockGetAllExercises mockGetAll,
  required MockAddExercise mockAdd,
  required MockUpdateExercise mockUpdate,
  required MockDeleteExercise mockDelete,
  required MockGetMuscleFactorsForExercise mockGetFactors,
}) => ExerciseBloc(
  getAllExercises: mockGetAll,
  getExerciseById: MockGetExerciseById(),
  getExercisesForMuscle: MockGetExercisesForMuscle(),
  addExercise: mockAdd,
  updateExercise: mockUpdate,
  deleteExercise: mockDelete,
  ensureDefaultExercises: MockEnsureDefaultExercises(),
  getMuscleFactorsForExercise: mockGetFactors,
);

// Opens the "Add exercise" dialog and settles the UI.
Future<void> _openAddDialog(WidgetTester tester, ExerciseBloc bloc) async {
  // The default 800×600 test surface is too short for the empty-state Column
  // that renders on the first frame (before ExercisesLoaded is emitted).
  // Give the test enough vertical room so no overflow error is thrown.
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_buildHarness(bloc));
  bloc.emit(ExercisesLoaded(<Exercise>[_exercise]));
  await tester.pump();
  await tester.tap(find.byKey(ExercisesTab.addButtonKey));
  await tester.pumpAndSettle();
}

// Opens the edit dialog for the first exercise card visible in the tab.
Future<void> _openEditDialog(WidgetTester tester, ExerciseBloc bloc) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(_buildHarness(bloc));
  bloc.emit(ExercisesLoaded(<Exercise>[_exercise]));
  await tester.pump();
  await tester.tap(find.text(_exercise.name));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockGetAllExercises mockGetAll;
  late MockAddExercise mockAdd;
  late MockUpdateExercise mockUpdate;
  late MockDeleteExercise mockDelete;
  late MockGetMuscleFactorsForExercise mockGetFactors;

  setUpAll(() {
    registerFallbackValue(_exercise);
  });

  setUp(() {
    mockGetAll = MockGetAllExercises();
    mockAdd = MockAddExercise();
    mockUpdate = MockUpdateExercise();
    mockDelete = MockDeleteExercise();
    mockGetFactors = MockGetMuscleFactorsForExercise();

    when(
      () => mockGetAll(),
    ).thenAnswer((_) async => Right(<Exercise>[_exercise]));
    when(
      () => mockGetFactors(any()),
    ).thenAnswer((_) async => Right(<MuscleFactor>[]));
  });

  group('new exercise dialog — factor editor', () {
    testWidgets('factor editor is hidden before any muscle chip is selected', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openAddDialog(tester, bloc);

      expect(find.byKey(ExercisesTab.factorEditorKey), findsNothing);
    });

    testWidgets('selecting a chip reveals a slider initialised at 1.00x', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openAddDialog(tester, bloc);

      await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
      await tester.pumpAndSettle();

      expect(find.byKey(ExercisesTab.factorEditorKey), findsOneWidget);
      expect(find.byKey(ExercisesTab.factorSliderKey('chest')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(ExercisesTab.factorValueKey('chest')))
            .data,
        '1.00x',
      );
    });

    testWidgets('deselecting a chip removes its slider row', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openAddDialog(tester, bloc);

      await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
      await tester.pumpAndSettle();
      expect(find.byKey(ExercisesTab.factorSliderKey('chest')), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
      await tester.pumpAndSettle();
      expect(find.byKey(ExercisesTab.factorSliderKey('chest')), findsNothing);
    });

    testWidgets('"Reset to defaults" button restores all sliders to 1.00x', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openAddDialog(tester, bloc);

      await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
      await tester.pumpAndSettle();

      // The Reset button lives inside the dialog's SingleChildScrollView and
      // may be just below the visible portion; scroll it into view first.
      await tester.ensureVisible(
        find.byKey(ExercisesTab.resetFactorsButtonKey),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ExercisesTab.resetFactorsButtonKey));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<Text>(find.byKey(ExercisesTab.factorValueKey('chest')))
            .data,
        '1.00x',
      );
    });

    testWidgets(
      'tapping Save dispatches AddExerciseEvent with the factor map',
      (WidgetTester tester) async {
        when(
          () => mockAdd(any(), muscleFactors: any(named: 'muscleFactors')),
        ).thenAnswer((_) async => const Right(null));

        final bloc = _makeBloc(
          mockGetAll: mockGetAll,
          mockAdd: mockAdd,
          mockUpdate: mockUpdate,
          mockDelete: mockDelete,
          mockGetFactors: mockGetFactors,
        );
        addTearDown(bloc.close);

        await _openAddDialog(tester, bloc);

        // Type a name into the dialog's name field.
        // find.byType(TextField).first would grab the background search bar
        // (still mounted behind the modal), so we scope the search to the
        // Dialog widget to get the correct field.
        await tester.enterText(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextField),
          ),
          'Squat',
        );
        await tester.pump();

        // Select Chest.
        await tester.tap(find.widgetWithText(FilterChip, 'Chest'));
        await tester.pumpAndSettle();

        // Tap the Add button.
        await tester.tap(find.text(AppStrings.add));
        await tester.pumpAndSettle();

        verify(
          () => mockAdd(any(), muscleFactors: any(named: 'muscleFactors')),
        ).called(1);
      },
    );
  });

  group('edit exercise dialog — factor loading', () {
    testWidgets('opens with existing muscles pre-selected at 1.00x default', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openEditDialog(tester, bloc);

      // chest and triceps come from _exercise.muscleGroups.
      expect(find.byKey(ExercisesTab.factorSliderKey('chest')), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(ExercisesTab.factorValueKey('chest')))
            .data,
        '1.00x',
      );
    });

    testWidgets(
      'BlocListener updates slider values when ExerciseFactorsLoaded arrives',
      (WidgetTester tester) async {
        final bloc = _makeBloc(
          mockGetAll: mockGetAll,
          mockAdd: mockAdd,
          mockUpdate: mockUpdate,
          mockDelete: mockDelete,
          mockGetFactors: mockGetFactors,
        );
        addTearDown(bloc.close);

        await _openEditDialog(tester, bloc);

        // Simulate the bloc emitting real saved factors.
        bloc.emit(
          ExerciseFactorsLoaded(
            exerciseId: _exercise.id,
            factors: const <String, double>{'chest': 0.6, 'triceps': 0.4},
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(ExercisesTab.factorValueKey('chest')))
              .data,
          '0.60x',
        );
        expect(
          tester
              .widget<Text>(find.byKey(ExercisesTab.factorValueKey('triceps')))
              .data,
          '0.40x',
        );
      },
    );

    testWidgets('factors loaded for a different exercise id are ignored', (
      WidgetTester tester,
    ) async {
      final bloc = _makeBloc(
        mockGetAll: mockGetAll,
        mockAdd: mockAdd,
        mockUpdate: mockUpdate,
        mockDelete: mockDelete,
        mockGetFactors: mockGetFactors,
      );
      addTearDown(bloc.close);

      await _openEditDialog(tester, bloc);

      // Emit factors for a DIFFERENT exercise — should be ignored.
      bloc.emit(
        const ExerciseFactorsLoaded(
          exerciseId: 'other-exercise-id',
          factors: <String, double>{'chest': 0.1},
        ),
      );
      await tester.pumpAndSettle();

      // Chest slider should still show the default 1.00x.
      expect(
        tester
            .widget<Text>(find.byKey(ExercisesTab.factorValueKey('chest')))
            .data,
        '1.00x',
      );
    });
  });
}
