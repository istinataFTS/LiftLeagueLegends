import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/app/startup/app_startup_listener.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/features/home/application/home_bloc.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockMuscleVisualBloc
    extends MockBloc<MuscleVisualEvent, MuscleVisualState>
    implements MuscleVisualBloc {}

class FakeWorkoutEvent extends Fake implements WorkoutEvent {}

class FakeWorkoutState extends Fake implements WorkoutState {}

class FakeHomeEvent extends Fake implements HomeEvent {}

class FakeHomeState extends Fake implements HomeState {}

class FakeMuscleVisualEvent extends Fake implements MuscleVisualEvent {}

class FakeMuscleVisualState extends Fake implements MuscleVisualState {}

void main() {
  late MockWorkoutBloc workoutBloc;
  late MockHomeBloc homeBloc;
  late MockMuscleVisualBloc muscleVisualBloc;

  setUpAll(() {
    registerFallbackValue(FakeWorkoutEvent());
    registerFallbackValue(FakeWorkoutState());
    registerFallbackValue(FakeHomeEvent());
    registerFallbackValue(FakeHomeState());
    registerFallbackValue(FakeMuscleVisualEvent());
    registerFallbackValue(FakeMuscleVisualState());
  });

  setUp(() {
    workoutBloc = MockWorkoutBloc();
    homeBloc = MockHomeBloc();
    muscleVisualBloc = MockMuscleVisualBloc();

    when(() => workoutBloc.state).thenReturn(WorkoutInitial());
    when(() => homeBloc.state).thenReturn(const HomeInitial());
    when(() => muscleVisualBloc.state).thenReturn(const MuscleVisualInitial());
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<WorkoutBloc>.value(value: workoutBloc),
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<MuscleVisualBloc>.value(value: muscleVisualBloc),
      ],
      child: const MaterialApp(
        home: AppStartupListener(child: SizedBox.shrink()),
      ),
    );
  }

  testWidgets(
    'dispatches LoadMuscleVisualsEvent(TimePeriod.month) on startup',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump(); // allow addPostFrameCallback to fire

      verify(
        () => muscleVisualBloc.add(
          const LoadMuscleVisualsEvent(TimePeriod.month),
        ),
      ).called(1);
    },
  );

  testWidgets(
    'dispatches LoadWeeklySetsEvent and LoadHomeDataEvent on startup',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      verify(() => workoutBloc.add(const LoadWeeklySetsEvent())).called(1);
      verify(() => homeBloc.add(LoadHomeDataEvent())).called(1);
    },
  );

  testWidgets('does not dispatch twice if rebuilt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    // Rebuild — should not fire a second dispatch.
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    verify(
      () =>
          muscleVisualBloc.add(const LoadMuscleVisualsEvent(TimePeriod.month)),
    ).called(1);
  });
}
