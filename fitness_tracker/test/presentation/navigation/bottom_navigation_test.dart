import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:fitness_tracker/features/home/application/home_bloc.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:fitness_tracker/features/library/application/meal_bloc.dart';
import 'package:fitness_tracker/features/log/log.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_scope.dart';
import 'package:fitness_tracker/domain/services/voice_media_button_service.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:fitness_tracker/injection/injection_container.dart';
import 'package:fitness_tracker/presentation/navigation/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAppSettingsCubit extends MockCubit<AppSettingsState>
    implements AppSettingsCubit {}

class MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockMuscleVisualBloc
    extends MockBloc<MuscleVisualEvent, MuscleVisualState>
    implements MuscleVisualBloc {}

class MockExerciseBloc extends MockBloc<ExerciseEvent, ExerciseState>
    implements ExerciseBloc {}

class MockMealBloc extends MockBloc<MealEvent, MealState> implements MealBloc {}

class MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

// ---------------------------------------------------------------------------
// Fakes (for registerFallbackValue)
// ---------------------------------------------------------------------------

class FakeHomeEvent extends Fake implements HomeEvent {}

class FakeHomeState extends Fake implements HomeState {}

class FakeMuscleVisualEvent extends Fake implements MuscleVisualEvent {}

class FakeMuscleVisualState extends Fake implements MuscleVisualState {}

class FakeExerciseEvent extends Fake implements ExerciseEvent {}

class FakeExerciseState extends Fake implements ExerciseState {}

class FakeMealEvent extends Fake implements MealEvent {}

class FakeMealState extends Fake implements MealState {}

class FakeWorkoutEvent extends Fake implements WorkoutEvent {}

class FakeWorkoutState extends Fake implements WorkoutState {}

class FakeHistoryEvent extends Fake implements HistoryEvent {}

class FakeHistoryState extends Fake implements HistoryState {}

class FakeNutritionLogEvent extends Fake implements NutritionLogEvent {}

class FakeNutritionLogState extends Fake implements NutritionLogState {}

// ---------------------------------------------------------------------------
// Fake service stubs — no-op, stream-safe, no native binaries.
// ---------------------------------------------------------------------------

class _FakeVoiceMediaButtonService implements VoiceMediaButtonService {
  final StreamController<void> _pressCtrl = StreamController<void>.broadcast();

  @override
  Stream<void> get onMediaButtonPressed => _pressCtrl.stream;

  @override
  bool get isRunning => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  Future<void> dispose() => _pressCtrl.close();
}

class _FakeVoiceWakeWordService implements VoiceWakeWordService {
  final StreamController<WakeWordPreset> _detectedCtrl =
      StreamController<WakeWordPreset>.broadcast();
  final StreamController<VoiceWakeWordException> _errorCtrl =
      StreamController<VoiceWakeWordException>.broadcast();

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedCtrl.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorCtrl.stream;

  @override
  bool get isRunning => false;

  @override
  Future<void> start(WakeWordPreset preset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    await _detectedCtrl.close();
    await _errorCtrl.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockAppSettingsCubit appSettingsCubit;
  late MockProfileCubit profileCubit;
  late MockVoiceSettingsCubit voiceSettingsCubit;
  late _FakeVoiceWakeWordService voiceWakeWordService;
  late _FakeVoiceMediaButtonService voiceMediaButtonService;
  late MockHomeBloc homeBloc;
  late MockMuscleVisualBloc muscleVisualBloc;
  late MockExerciseBloc exerciseBloc;
  late MockMealBloc mealBloc;
  late MockWorkoutBloc workoutBloc;
  late MockHistoryBloc historyBloc;
  late MockNutritionLogBloc nutritionLogBloc;

  setUpAll(() {
    registerFallbackValue(FakeHomeEvent());
    registerFallbackValue(FakeHomeState());
    registerFallbackValue(FakeMuscleVisualEvent());
    registerFallbackValue(FakeMuscleVisualState());
    registerFallbackValue(FakeExerciseEvent());
    registerFallbackValue(FakeExerciseState());
    registerFallbackValue(FakeMealEvent());
    registerFallbackValue(FakeMealState());
    registerFallbackValue(FakeWorkoutEvent());
    registerFallbackValue(FakeWorkoutState());
    registerFallbackValue(FakeHistoryEvent());
    registerFallbackValue(FakeHistoryState());
    registerFallbackValue(FakeNutritionLogEvent());
    registerFallbackValue(FakeNutritionLogState());
  });

  setUp(() {
    appSettingsCubit = MockAppSettingsCubit();
    profileCubit = MockProfileCubit();
    voiceSettingsCubit = MockVoiceSettingsCubit();
    voiceWakeWordService = _FakeVoiceWakeWordService();
    voiceMediaButtonService = _FakeVoiceMediaButtonService();
    homeBloc = MockHomeBloc();
    muscleVisualBloc = MockMuscleVisualBloc();
    exerciseBloc = MockExerciseBloc();
    mealBloc = MockMealBloc();
    workoutBloc = MockWorkoutBloc();
    historyBloc = MockHistoryBloc();
    nutritionLogBloc = MockNutritionLogBloc();

    when(
      () => appSettingsCubit.state,
    ).thenReturn(AppSettingsState.initial().copyWith(hasLoaded: true));
    whenListen<AppSettingsState>(
      appSettingsCubit,
      const Stream<AppSettingsState>.empty(),
      initialState: AppSettingsState.initial().copyWith(hasLoaded: true),
    );

    const authedState = ProfileState(
      session: AppSession(
        user: AppUser(id: 'user-1', email: 'user@test.com'),
      ),
      isLoading: false,
      hasLoaded: true,
    );
    when(() => profileCubit.state).thenReturn(authedState);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: authedState,
    );

    when(() => voiceSettingsCubit.state).thenReturn(const VoiceSettings());
    when(() => voiceSettingsCubit.ready).thenAnswer((_) => Future.value());
    whenListen<VoiceSettings>(
      voiceSettingsCubit,
      const Stream<VoiceSettings>.empty(),
      initialState: const VoiceSettings(),
    );

    when(() => homeBloc.state).thenReturn(const HomeInitial());
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeInitial(),
    );

    when(() => muscleVisualBloc.state).thenReturn(const MuscleVisualInitial());
    whenListen<MuscleVisualState>(
      muscleVisualBloc,
      const Stream<MuscleVisualState>.empty(),
      initialState: const MuscleVisualInitial(),
    );

    when(() => exerciseBloc.state).thenReturn(ExerciseInitial());
    whenListen<ExerciseState>(
      exerciseBloc,
      const Stream<ExerciseState>.empty(),
      initialState: ExerciseInitial(),
    );

    when(() => mealBloc.state).thenReturn(MealInitial());
    whenListen<MealState>(
      mealBloc,
      const Stream<MealState>.empty(),
      initialState: MealInitial(),
    );

    when(() => workoutBloc.state).thenReturn(WorkoutInitial());
    whenListen<WorkoutState>(
      workoutBloc,
      const Stream<WorkoutState>.empty(),
      initialState: WorkoutInitial(),
    );

    when(() => historyBloc.state).thenReturn(const HistoryInitial());
    whenListen<HistoryState>(
      historyBloc,
      const Stream<HistoryState>.empty(),
      initialState: const HistoryInitial(),
    );
    when(
      () => historyBloc.effects,
    ).thenAnswer((_) => const Stream<HistoryUiEffect>.empty());

    when(() => nutritionLogBloc.state).thenReturn(NutritionLogInitial());
    whenListen<NutritionLogState>(
      nutritionLogBloc,
      const Stream<NutritionLogState>.empty(),
      initialState: NutritionLogInitial(),
    );
    when(
      () => nutritionLogBloc.effects,
    ).thenAnswer((_) => const Stream<NutritionLogUiEffect>.empty());

    when(() => exerciseBloc.add(any())).thenReturn(null);
    when(() => mealBloc.add(any())).thenReturn(null);
    when(() => historyBloc.add(any())).thenReturn(null);

    // VoiceFab (rendered by BottomNavigation) reads VoiceWakeWordService
    // and VoiceMediaButtonService from GetIt in initState; register fakes
    // before each pump.
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    sl.registerSingleton<VoiceWakeWordService>(voiceWakeWordService);
    sl.registerSingleton<VoiceMediaButtonService>(voiceMediaButtonService);
  });

  tearDown(() async {
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    await voiceWakeWordService.dispose();
    await voiceMediaButtonService.dispose();
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppSettingsCubit>.value(value: appSettingsCubit),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<MuscleVisualBloc>.value(value: muscleVisualBloc),
        BlocProvider<ExerciseBloc>.value(value: exerciseBloc),
        BlocProvider<MealBloc>.value(value: mealBloc),
        BlocProvider<WorkoutBloc>.value(value: workoutBloc),
        BlocProvider<HistoryBloc>.value(value: historyBloc),
        BlocProvider<NutritionLogBloc>.value(value: nutritionLogBloc),
        // VoiceFab inside BottomNavigation reads this cubit from context.
        BlocProvider<VoiceSettingsCubit>.value(value: voiceSettingsCubit),
      ],
      child: SettingsScope(child: MaterialApp(home: const BottomNavigation())),
    );
  }

  testWidgets('opening History eagerly loads exercise and meal library data', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.text('History'));
    await tester.pump();

    verify(() => exerciseBloc.add(LoadExercisesEvent())).called(1);
    verify(() => mealBloc.add(LoadMealsEvent())).called(1);
  });
}
