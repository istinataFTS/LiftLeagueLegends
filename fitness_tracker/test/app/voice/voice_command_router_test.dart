import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/core/platform/wakelock_service.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/voice_budget.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/app_settings_repository.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/domain/services/voice_tts_service.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_daily_macros.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/domain/usecases/voice/delete_voice_history.dart';
import 'package:fitness_tracker/domain/usecases/voice/get_voice_budget.dart';
import 'package:fitness_tracker/domain/usecases/voice/send_voice_message.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_weekly_sets.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:fitness_tracker/features/log/application/nutrition_log_bloc.dart';
import 'package:fitness_tracker/features/log/application/workout_bloc.dart';
import 'package:fitness_tracker/features/voice/application/voice_bloc.dart';
import 'package:fitness_tracker/features/voice/data/coordinator/offline_voice_coordinator.dart';
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
import 'package:fitness_tracker/app/voice/voice_command_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Target BLoC mocks — live here because VoiceCommandRouter is the seam
// where VoiceBloc effects meet the target BLoCs.
// ---------------------------------------------------------------------------

class _MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class _MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class _MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

// ---------------------------------------------------------------------------
// Minimal mocks for VoiceBloc construction.
// These dependencies are NEVER invoked in router tests because we call
// voiceBloc.emitEffect() directly rather than driving event handlers.
// ---------------------------------------------------------------------------

class _MockSendVoiceMessage extends Mock implements SendVoiceMessage {}

class _MockGetVoiceBudget extends Mock implements GetVoiceBudget {}

class _MockDeleteVoiceHistory extends Mock implements DeleteVoiceHistory {}

class _MockAppSettingsRepository extends Mock
    implements AppSettingsRepository {}

class _MockGetSetsByDateRange extends Mock implements GetSetsByDateRange {}

class _MockGetDailyMacros extends Mock implements GetDailyMacros {}

class _MockGetWeeklySets extends Mock implements GetWeeklySets {}

class _MockGetLogsForDate extends Mock implements GetLogsForDate {}

class _MockExerciseLookup extends Mock implements ExerciseLookup {}

class _MockOfflineVoiceCoordinator extends Mock
    implements OfflineVoiceCoordinator {}

// ---------------------------------------------------------------------------
// Fake event base types — needed for registerFallbackValue so mocktail's
// any(that: isA<XxxEvent>()) matchers work during verify() calls.
// ---------------------------------------------------------------------------

class _FakeWorkoutEvent extends Fake implements WorkoutEvent {}

class _FakeHistoryEvent extends Fake implements HistoryEvent {}

class _FakeNutritionLogEvent extends Fake implements NutritionLogEvent {}

// ---------------------------------------------------------------------------
// Minimal service stubs — zero behaviour needed since VoiceBloc handlers
// are never triggered in router tests.
// ---------------------------------------------------------------------------

class _FakeTts implements VoiceTtsService {
  @override
  Future<void> initialize({
    double volume = 1.0,
    double speechRate = 1.0,
  }) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> dispose() async {}
}

class _FakeStt implements VoiceSttService {
  @override
  Future<void> initialize() async {}

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) => const Stream.empty();

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeWakeWord implements VoiceWakeWordService {
  @override
  Stream<WakeWordPreset> get onWakeWordDetected => const Stream.empty();

  @override
  Stream<VoiceWakeWordException> get onError => const Stream.empty();

  @override
  bool get isRunning => false;

  @override
  Future<void> start(WakeWordPreset preset) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeNetworkStatus implements NetworkStatusService {
  @override
  Future<bool> isNetworkAvailable() async => true;

  @override
  Stream<bool> get onConnectivityRestored => const Stream.empty();

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

class _FakeWakelock implements WakelockService {
  @override
  Future<void> enable() async {}

  @override
  Future<void> disable() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VoiceBloc _buildVoiceBloc() {
  final budget = _MockGetVoiceBudget();
  final settings = _MockAppSettingsRepository();
  when(() => budget()).thenAnswer(
    (_) async => const Right(VoiceBudget(usedUsd: 0, dailyCapUsd: 0.5)),
  );
  when(
    () => settings.getSettings(),
  ).thenAnswer((_) async => const Right(AppSettings.defaults()));
  return VoiceBloc(
    sendVoiceMessage: _MockSendVoiceMessage(),
    getVoiceBudget: budget,
    deleteVoiceHistory: _MockDeleteVoiceHistory(),
    sttService: _FakeStt(),
    ttsService: _FakeTts(),
    appSettingsRepository: settings,
    currentVoiceSettings: () => const VoiceSettings.defaults(),
    networkStatusService: _FakeNetworkStatus(),
    wakeWordService: _FakeWakeWord(),
    wakelockService: _FakeWakelock(),
    getSetsByDateRange: _MockGetSetsByDateRange(),
    getDailyMacros: _MockGetDailyMacros(),
    getWeeklySets: _MockGetWeeklySets(),
    getLogsForDate: _MockGetLogsForDate(),
    exerciseLookup: _MockExerciseLookup(),
    offlineCoordinator: _MockOfflineVoiceCoordinator(),
  );
}

final _testSet = WorkoutSet(
  id: 'set-rt-1',
  exerciseId: 'ex-bench',
  reps: 8,
  weight: 80.0,
  intensity: 3,
  date: DateTime(2026),
  createdAt: DateTime(2026),
);

final _testLog = NutritionLog(
  id: 'log-rt-1',
  mealName: 'Chicken',
  calories: 300,
  proteinGrams: 30,
  carbsGrams: 10,
  fatGrams: 5,
  loggedAt: DateTime(2026),
  createdAt: DateTime(2026),
);

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeWorkoutEvent());
    registerFallbackValue(_FakeHistoryEvent());
    registerFallbackValue(_FakeNutritionLogEvent());
    registerFallbackValue(_testSet);
    registerFallbackValue(_testLog);
  });

  group('VoiceCommandRouter', () {
    late _MockWorkoutBloc workoutBloc;
    late _MockHistoryBloc historyBloc;
    late _MockNutritionLogBloc nutritionLogBloc;
    late VoiceBloc voiceBloc;

    setUp(() {
      workoutBloc = _MockWorkoutBloc();
      historyBloc = _MockHistoryBloc();
      nutritionLogBloc = _MockNutritionLogBloc();
      voiceBloc = _buildVoiceBloc();
    });

    tearDown(() async {
      await voiceBloc.close();
    });

    Future<void> pumpRouter(WidgetTester tester) => tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<VoiceBloc>.value(value: voiceBloc),
          BlocProvider<WorkoutBloc>.value(value: workoutBloc),
          BlocProvider<HistoryBloc>.value(value: historyBloc),
          BlocProvider<NutritionLogBloc>.value(value: nutritionLogBloc),
        ],
        child: const MaterialApp(home: VoiceCommandRouter(child: SizedBox())),
      ),
    );

    testWidgets(
      'VoiceAddWorkoutSetCommand dispatches AddWorkoutSetEvent to WorkoutBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(VoiceAddWorkoutSetCommand(_testSet));
        await tester.pump();
        verify(
          () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
        ).called(1);
        verifyNever(() => historyBloc.add(any()));
        verifyNever(() => nutritionLogBloc.add(any()));
      },
    );

    testWidgets(
      'VoiceUpdateWorkoutSetCommand dispatches UpdateSetEvent to HistoryBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(VoiceUpdateWorkoutSetCommand(_testSet));
        await tester.pump();
        verify(
          () => historyBloc.add(any(that: isA<UpdateSetEvent>())),
        ).called(1);
        verifyNever(() => workoutBloc.add(any()));
        verifyNever(() => nutritionLogBloc.add(any()));
      },
    );

    testWidgets(
      'VoiceDeleteWorkoutSetCommand dispatches DeleteSetEvent to HistoryBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(const VoiceDeleteWorkoutSetCommand('set-999'));
        await tester.pump();
        verify(
          () => historyBloc.add(any(that: isA<DeleteSetEvent>())),
        ).called(1);
        verifyNever(() => workoutBloc.add(any()));
        verifyNever(() => nutritionLogBloc.add(any()));
      },
    );

    testWidgets(
      'VoiceAddNutritionLogCommand dispatches AddNutritionLogEvent to NutritionLogBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(VoiceAddNutritionLogCommand(_testLog));
        await tester.pump();
        verify(
          () => nutritionLogBloc.add(any(that: isA<AddNutritionLogEvent>())),
        ).called(1);
        verifyNever(() => workoutBloc.add(any()));
        verifyNever(() => historyBloc.add(any()));
      },
    );

    testWidgets(
      'VoiceUpdateNutritionLogCommand dispatches UpdateNutritionHistoryLogEvent to HistoryBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(VoiceUpdateNutritionLogCommand(_testLog));
        await tester.pump();
        verify(
          () =>
              historyBloc.add(any(that: isA<UpdateNutritionHistoryLogEvent>())),
        ).called(1);
        verifyNever(() => workoutBloc.add(any()));
        verifyNever(() => nutritionLogBloc.add(any()));
      },
    );

    testWidgets(
      'VoiceDeleteNutritionLogCommand dispatches DeleteNutritionHistoryLogEvent to HistoryBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(const VoiceDeleteNutritionLogCommand('log-del-1'));
        await tester.pump();
        verify(
          () =>
              historyBloc.add(any(that: isA<DeleteNutritionHistoryLogEvent>())),
        ).called(1);
        verifyNever(() => workoutBloc.add(any()));
        verifyNever(() => nutritionLogBloc.add(any()));
      },
    );

    testWidgets(
      'didChangeDependencies idempotence — rebuilding does not create duplicate subscription',
      (tester) async {
        await pumpRouter(tester);
        // Re-pump the same widget tree; didChangeDependencies fires again.
        // The _sub ??= guard must prevent a second subscription.
        await pumpRouter(tester);
        voiceBloc.emitEffect(VoiceAddWorkoutSetCommand(_testSet));
        await tester.pump();
        // If there were two subscriptions, .called(2) would be required.
        verify(
          () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
        ).called(1);
      },
    );
  });
}
