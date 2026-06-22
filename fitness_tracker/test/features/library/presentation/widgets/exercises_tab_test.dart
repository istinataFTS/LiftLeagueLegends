import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
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
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
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

class MockExerciseLookup extends Mock implements ExerciseLookup {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _exercise = Exercise(
  id: 'ex-1',
  name: 'Bench Press',
  muscleGroups: const <String>['chest'],
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

ExerciseBloc _makeBloc({required MockGetAllExercises mockGetAll}) {
  final mockLookup = MockExerciseLookup();
  when(() => mockLookup.invalidate()).thenReturn(null);
  return ExerciseBloc(
    getAllExercises: mockGetAll,
    getExerciseById: MockGetExerciseById(),
    getExercisesForMuscle: MockGetExercisesForMuscle(),
    addExercise: MockAddExercise(),
    updateExercise: MockUpdateExercise(),
    deleteExercise: MockDeleteExercise(),
    ensureDefaultExercises: MockEnsureDefaultExercises(),
    getMuscleFactorsForExercise: MockGetMuscleFactorsForExercise(),
    exerciseLookup: mockLookup,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockGetAllExercises mockGetAll;

  setUpAll(() {
    registerFallbackValue(_exercise);
  });

  setUp(() {
    mockGetAll = MockGetAllExercises();
  });

  group('ExercisesTab', () {
    group('empty state', () {
      testWidgets('Reload button appears when exercises list is empty', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bloc = _makeBloc(mockGetAll: mockGetAll);

        await tester.pumpWidget(_buildHarness(bloc));
        bloc.emit(ExercisesLoaded(const <Exercise>[]));
        await tester.pump();

        expect(find.byKey(ExercisesTab.reloadButtonKey), findsOneWidget);
      });

      testWidgets('tapping Reload button dispatches LoadExercisesEvent', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Reload triggers getAllExercises; return data so the bloc transitions.
        when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));

        final bloc = _makeBloc(mockGetAll: mockGetAll);

        await tester.pumpWidget(_buildHarness(bloc));
        bloc.emit(ExercisesLoaded(const <Exercise>[]));
        await tester.pump();

        await tester.tap(find.byKey(ExercisesTab.reloadButtonKey));
        await tester.pumpAndSettle();

        // After reload the bloc receives data and transitions to loaded list.
        expect(find.text(_exercise.name), findsOneWidget);
        expect(find.byKey(ExercisesTab.reloadButtonKey), findsNothing);
      });

      testWidgets('Reload button absent when exercises are present', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final bloc = _makeBloc(mockGetAll: mockGetAll);

        await tester.pumpWidget(_buildHarness(bloc));
        bloc.emit(ExercisesLoaded([_exercise]));
        await tester.pump();

        expect(find.byKey(ExercisesTab.reloadButtonKey), findsNothing);
      });
    });

    group('pull-to-refresh', () {
      testWidgets('RefreshIndicator onRefresh invokes the reload path', (
        WidgetTester tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(800, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // mockGetAll resolves to the same list — onRefresh dispatches
        // LoadExercisesEvent, which calls getAllExercises on the bloc.
        when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));

        final bloc = _makeBloc(mockGetAll: mockGetAll);

        await tester.pumpWidget(_buildHarness(bloc));
        bloc.emit(ExercisesLoaded([_exercise]));
        await tester.pump();

        // The initial emit bypassed the use case; reset the call count so
        // we only count invocations from the RefreshIndicator path.
        reset(mockGetAll);
        when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));

        // Trigger pull-to-refresh on the visible list.
        await tester.drag(find.text(_exercise.name), const Offset(0, 300));
        await tester.pumpAndSettle();

        verify(() => mockGetAll()).called(greaterThanOrEqualTo(1));
        expect(find.text(_exercise.name), findsOneWidget);
      });
    });
  });
}
