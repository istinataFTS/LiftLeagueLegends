import 'dart:async';

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
import 'package:fitness_tracker/features/voice/application/voice_mutation_outcome.dart';
import 'package:fitness_tracker/features/voice/data/coordinator/offline_voice_coordinator.dart';
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
import 'package:fitness_tracker/app/voice/voice_command_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Target BLoC mocks — extends MockBloc so state/stream is mocked, and
// implements the real BLoC so we can stub the `effects` getter separately.
// ---------------------------------------------------------------------------

class _MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class _MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

class _MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

// ---------------------------------------------------------------------------
// Minimal mocks for VoiceBloc construction — never invoked in router tests.
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
// Fake fallback values for mocktail verify calls.
// ---------------------------------------------------------------------------

class _FakeWorkoutEvent extends Fake implements WorkoutEvent {}

class _FakeHistoryEvent extends Fake implements HistoryEvent {}

class _FakeNutritionLogEvent extends Fake implements NutritionLogEvent {}

// ---------------------------------------------------------------------------
// Minimal service stubs — behaviour is irrelevant in router tests.
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
// Builder helpers
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

VoiceAddWorkoutSetCommand _addSetCmd([WorkoutSet? set]) =>
    VoiceAddWorkoutSetCommand(set ?? _testSet, completer: Completer());

VoiceUpdateWorkoutSetCommand _updateSetCmd() =>
    VoiceUpdateWorkoutSetCommand(_testSet, completer: Completer());

VoiceDeleteWorkoutSetCommand _deleteSetCmd([String id = 'set-999']) =>
    VoiceDeleteWorkoutSetCommand(id, completer: Completer());

VoiceAddNutritionLogCommand _addLogCmd([NutritionLog? log]) =>
    VoiceAddNutritionLogCommand(log ?? _testLog, completer: Completer());

VoiceUpdateNutritionLogCommand _updateLogCmd() =>
    VoiceUpdateNutritionLogCommand(_testLog, completer: Completer());

VoiceDeleteNutritionLogCommand _deleteLogCmd([String id = 'log-del-1']) =>
    VoiceDeleteNutritionLogCommand(id, completer: Completer());

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
    // Per-test StreamControllers so tests can emit effects at will.
    late StreamController<WorkoutUiEffect> workoutEffects;
    late StreamController<HistoryUiEffect> historyEffects;
    late StreamController<NutritionLogUiEffect> nutritionEffects;

    setUp(() {
      workoutEffects = StreamController<WorkoutUiEffect>.broadcast();
      historyEffects = StreamController<HistoryUiEffect>.broadcast();
      nutritionEffects = StreamController<NutritionLogUiEffect>.broadcast();

      workoutBloc = _MockWorkoutBloc();
      historyBloc = _MockHistoryBloc();
      nutritionLogBloc = _MockNutritionLogBloc();
      voiceBloc = _buildVoiceBloc();

      // Stub the effects getter on each mock so the router's subscriptions
      // receive events from the per-test controllers.
      when(() => workoutBloc.effects).thenAnswer((_) => workoutEffects.stream);
      when(() => historyBloc.effects).thenAnswer((_) => historyEffects.stream);
      when(
        () => nutritionLogBloc.effects,
      ).thenAnswer((_) => nutritionEffects.stream);
    });

    tearDown(() async {
      await voiceBloc.close();
      await workoutEffects.close();
      await historyEffects.close();
      await nutritionEffects.close();
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

    // -------------------------------------------------------------------------
    // Dispatch routing — each command reaches the right BLoC
    // -------------------------------------------------------------------------

    testWidgets(
      'VoiceAddWorkoutSetCommand dispatches AddWorkoutSetEvent to WorkoutBloc',
      (tester) async {
        await pumpRouter(tester);
        voiceBloc.emitEffect(_addSetCmd());
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
        voiceBloc.emitEffect(_updateSetCmd());
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
        voiceBloc.emitEffect(_deleteSetCmd());
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
        voiceBloc.emitEffect(_addLogCmd());
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
        voiceBloc.emitEffect(_updateLogCmd());
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
        voiceBloc.emitEffect(_deleteLogCmd());
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
        await pumpRouter(tester);
        voiceBloc.emitEffect(_addSetCmd());
        await tester.pump();
        // If there were two subscriptions, .called(2) would be required.
        verify(
          () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
        ).called(1);
      },
    );

    // -------------------------------------------------------------------------
    // Round-trip outcome — target BLoC effects complete the completer
    // -------------------------------------------------------------------------

    testWidgets(
      'WorkoutLoggedEffect completes the add-workout-set completer with Success',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _addSetCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        workoutEffects.add(
          const WorkoutLoggedEffect(
            message: 'Set logged!',
            affectedMuscles: [],
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationSuccess>());
      },
    );

    testWidgets(
      'WorkoutMutationFailedEffect completes the completer with Failure',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _addSetCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        workoutEffects.add(const WorkoutMutationFailedEffect('db error'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        final outcome = await cmd.completer.future;
        expect(outcome, isA<VoiceMutationFailure>());
        expect((outcome as VoiceMutationFailure).reason, 'db error');
      },
    );

    testWidgets(
      'HistorySuccessEffect completes the update-set completer with Success',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _updateSetCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        historyEffects.add(const HistorySuccessEffect('Set updated'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationSuccess>());
      },
    );

    testWidgets(
      'HistoryMutationFailedEffect completes the completer with Failure',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _updateSetCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        historyEffects.add(const HistoryMutationFailedEffect('history error'));
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationFailure>());
      },
    );

    testWidgets(
      'NutritionLogSuccessEffect completes the add-nutrition completer with Success',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _addLogCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        nutritionEffects.add(
          const NutritionLogSuccessEffect('Nutrition added'),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationSuccess>());
      },
    );

    testWidgets(
      'NutritionMutationFailedEffect completes the completer with Failure',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _addLogCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        nutritionEffects.add(
          const NutritionMutationFailedEffect('nutrition error'),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationFailure>());
      },
    );

    // -------------------------------------------------------------------------
    // Target-effect isolation — WorkoutBloc effects must NOT complete a
    // NutritionLogBloc-targeted completer and vice versa.
    // -------------------------------------------------------------------------

    testWidgets(
      'WorkoutLoggedEffect does not complete a nutrition-log-targeted completer',
      (tester) async {
        await pumpRouter(tester);
        // In-flight command targets NutritionLogBloc.
        final cmd = _addLogCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        // Emit a WorkoutBloc success effect — must be ignored.
        workoutEffects.add(
          const WorkoutLoggedEffect(
            message: 'Set logged!',
            affectedMuscles: [],
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(cmd.completer.isCompleted, isFalse);
      },
    );

    // -------------------------------------------------------------------------
    // Single-flight serialisation
    // -------------------------------------------------------------------------

    testWidgets('second command queues; executes only after first completes', (
      tester,
    ) async {
      await pumpRouter(tester);

      final cmd1 = _addSetCmd();
      final cmd2 = _addSetCmd();

      voiceBloc.emitEffect(cmd1); // dispatched immediately
      await tester.pump();
      voiceBloc.emitEffect(cmd2); // queued
      await tester.pump();

      // Only one dispatch reached WorkoutBloc so far (cmd1 in-flight).
      verify(
        () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
      ).called(1);

      // Resolve cmd1 — should trigger cmd2 dispatch.
      workoutEffects.add(
        const WorkoutLoggedEffect(message: 'ok', affectedMuscles: []),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(cmd1.completer.isCompleted, isTrue);
      expect(await cmd1.completer.future, isA<VoiceMutationSuccess>());
      // cmd2 was dispatched after cmd1 completed.
      verify(
        () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
      ).called(1);
    });

    // -------------------------------------------------------------------------
    // Queue overflow — 6th command dropped with Timeout
    // -------------------------------------------------------------------------

    testWidgets(
      'sixth command while queue is full completes immediately with Timeout',
      (tester) async {
        await pumpRouter(tester);

        // cmds[0] goes in-flight; cmds[1-5] fill the queue; cmds[6] overflows.
        final cmds = List.generate(7, (_) => _addSetCmd());
        for (final cmd in cmds) {
          voiceBloc.emitEffect(cmd);
          await tester.pump();
        }

        // Only cmds[0] should have been dispatched.
        verify(
          () => workoutBloc.add(any(that: isA<AddWorkoutSetEvent>())),
        ).called(1);

        // The 7th (index 6) was immediately timed out.
        expect(cmds[6].completer.isCompleted, isTrue);
        expect(await cmds[6].completer.future, isA<VoiceMutationTimeout>());

        // The first 6 are still pending (in-flight or queued).
        for (final cmd in cmds.take(6)) {
          expect(cmd.completer.isCompleted, isFalse);
        }
      },
    );

    // -------------------------------------------------------------------------
    // Cancellation on unmount
    // -------------------------------------------------------------------------

    testWidgets(
      'unmounting while a dispatch is in-flight completes the completer with Timeout',
      (tester) async {
        await pumpRouter(tester);
        final cmd = _addSetCmd();
        voiceBloc.emitEffect(cmd);
        await tester.pump();

        // Replace the widget tree to trigger dispose().
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(cmd.completer.isCompleted, isTrue);
        expect(await cmd.completer.future, isA<VoiceMutationTimeout>());
      },
    );

    testWidgets(
      'unmounting with queued commands completes all completers with Timeout',
      (tester) async {
        await pumpRouter(tester);
        final cmd1 = _addSetCmd();
        final cmd2 = _addSetCmd();
        voiceBloc.emitEffect(cmd1); // in-flight
        voiceBloc.emitEffect(cmd2); // queued
        await tester.pump();

        await tester.pumpWidget(const MaterialApp(home: SizedBox()));

        expect(cmd1.completer.isCompleted, isTrue);
        expect(cmd2.completer.isCompleted, isTrue);
        expect(await cmd1.completer.future, isA<VoiceMutationTimeout>());
        expect(await cmd2.completer.future, isA<VoiceMutationTimeout>());
      },
    );
  });
}
