import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/services/voice_media_button_service.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:fitness_tracker/features/history/presentation/bloc/history_effect.dart';
import 'package:fitness_tracker/features/log/application/nutrition_log_bloc.dart';
import 'package:fitness_tracker/features/log/application/workout_bloc.dart';
import 'package:fitness_tracker/features/voice/application/voice_bloc.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_overlay_keys.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_overlay_page.dart';
import 'package:fitness_tracker/injection/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockVoiceBloc extends MockBloc<VoiceEvent, VoiceState>
    implements VoiceBloc {}

class _MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

class _MockWorkoutBloc extends MockBloc<WorkoutEvent, WorkoutState>
    implements WorkoutBloc {}

class _MockNutritionLogBloc
    extends MockBloc<NutritionLogEvent, NutritionLogState>
    implements NutritionLogBloc {}

class _MockHistoryBloc extends MockBloc<HistoryEvent, HistoryState>
    implements HistoryBloc {}

// ---------------------------------------------------------------------------
// Media button service — records starts/stops and can emit presses
// ---------------------------------------------------------------------------

class _FakeVoiceMediaButtonService implements VoiceMediaButtonService {
  bool _running = false;
  final _pressCtrl = StreamController<void>.broadcast();

  @override
  Stream<void> get onMediaButtonPressed => _pressCtrl.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async => _running = true;

  @override
  Future<void> stop() async => _running = false;

  void emitPress() => _pressCtrl.add(null);

  Future<void> dispose() => _pressCtrl.close();
}

// ---------------------------------------------------------------------------
// Wake word service — records every start/stop call
// ---------------------------------------------------------------------------

class _TrackingWakeWordService implements VoiceWakeWordService {
  final List<String> calls = [];
  bool _running = false;

  final _detected = StreamController<WakeWordPreset>.broadcast();
  final _errors = StreamController<VoiceWakeWordException>.broadcast();

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detected.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errors.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async {
    _running = true;
    calls.add('start');
  }

  @override
  Future<void> stop() async {
    _running = false;
    calls.add('stop');
  }

  @override
  Future<void> dispose() async {
    await _detected.close();
    await _errors.close();
  }
}

// ---------------------------------------------------------------------------
// Fake network service
// ---------------------------------------------------------------------------

class _FakeNetworkStatus implements NetworkStatusService {
  @override
  Future<bool> isNetworkAvailable() async => true;

  @override
  Stream<bool> get onConnectivityRestored => const Stream.empty();

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _session = AppSession(
  user: AppUser(id: 'test-user', email: 'user@test.local'),
);

const _armedSettings =
    VoiceSettings.defaults(); // wakeWordArmedInForeground = true
const _disabledSettings = VoiceSettings(wakeWordArmedInForeground: false);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockVoiceBloc voiceBloc;
  late _MockVoiceSettingsCubit settingsCubit;
  late _TrackingWakeWordService wakeService;
  late _FakeVoiceMediaButtonService mediaButtonService;
  late _MockWorkoutBloc workoutBloc;
  late _MockNutritionLogBloc nutritionBloc;
  late _MockHistoryBloc historyBloc;
  late StreamController<VoiceEffect> voiceEffectsCtrl;
  late StreamController<WorkoutUiEffect> workoutEffectsCtrl;
  late StreamController<NutritionLogUiEffect> nutritionEffectsCtrl;
  late StreamController<HistoryUiEffect> historyEffectsCtrl;

  setUp(() {
    voiceBloc = _MockVoiceBloc();
    settingsCubit = _MockVoiceSettingsCubit();
    wakeService = _TrackingWakeWordService();
    mediaButtonService = _FakeVoiceMediaButtonService();
    workoutBloc = _MockWorkoutBloc();
    nutritionBloc = _MockNutritionLogBloc();
    historyBloc = _MockHistoryBloc();

    voiceEffectsCtrl = StreamController<VoiceEffect>.broadcast();
    workoutEffectsCtrl = StreamController<WorkoutUiEffect>.broadcast();
    nutritionEffectsCtrl = StreamController<NutritionLogUiEffect>.broadcast();
    historyEffectsCtrl = StreamController<HistoryUiEffect>.broadcast();

    when(() => voiceBloc.effects).thenAnswer((_) => voiceEffectsCtrl.stream);
    when(
      () => workoutBloc.effects,
    ).thenAnswer((_) => workoutEffectsCtrl.stream);
    when(
      () => nutritionBloc.effects,
    ).thenAnswer((_) => nutritionEffectsCtrl.stream);
    when(
      () => historyBloc.effects,
    ).thenAnswer((_) => historyEffectsCtrl.stream);

    when(() => settingsCubit.state).thenReturn(_armedSettings);
    whenListen(
      settingsCubit,
      Stream<VoiceSettings>.empty(),
      initialState: _armedSettings,
    );
    whenListen(
      voiceBloc,
      Stream<VoiceState>.empty(),
      initialState: const VoiceState(),
    );

    if (sl.isRegistered<VoiceBloc>()) sl.unregister<VoiceBloc>();
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    if (sl.isRegistered<NetworkStatusService>()) {
      sl.unregister<NetworkStatusService>();
    }

    sl.registerSingleton<VoiceBloc>(voiceBloc);
    sl.registerSingleton<VoiceWakeWordService>(wakeService);
    sl.registerSingleton<VoiceMediaButtonService>(mediaButtonService);
    sl.registerSingleton<NetworkStatusService>(_FakeNetworkStatus());
  });

  tearDown(() async {
    if (sl.isRegistered<VoiceBloc>()) sl.unregister<VoiceBloc>();
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    if (sl.isRegistered<NetworkStatusService>()) {
      sl.unregister<NetworkStatusService>();
    }
    await voiceEffectsCtrl.close();
    await workoutEffectsCtrl.close();
    await nutritionEffectsCtrl.close();
    await historyEffectsCtrl.close();
    await wakeService.dispose();
    await mediaButtonService.dispose();
  });

  Widget buildSubject() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<VoiceSettingsCubit>.value(value: settingsCubit),
          BlocProvider<WorkoutBloc>.value(value: workoutBloc),
          BlocProvider<NutritionLogBloc>.value(value: nutritionBloc),
          BlocProvider<HistoryBloc>.value(value: historyBloc),
        ],
        child: const Scaffold(body: VoiceOverlayPage(session: _session)),
      ),
    );
  }

  group('VoiceOverlayPage — wake engine lifecycle', () {
    testWidgets('arms engine on initial idle state when wake is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(wakeService.calls, contains('start'));
    });

    testWidgets('stops engine when status transitions to listening', (
      tester,
    ) async {
      final stateCtrl = StreamController<VoiceState>.broadcast();
      addTearDown(stateCtrl.close);
      whenListen(voiceBloc, stateCtrl.stream, initialState: const VoiceState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      stateCtrl.add(const VoiceState(status: VoiceStatus.listening));
      await tester.pumpAndSettle();

      expect(wakeService.calls, contains('stop'));
    });

    testWidgets('re-arms engine when status returns to idle', (tester) async {
      final stateCtrl = StreamController<VoiceState>.broadcast();
      addTearDown(stateCtrl.close);
      whenListen(voiceBloc, stateCtrl.stream, initialState: const VoiceState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      // Drive to listening then back to idle.
      stateCtrl.add(const VoiceState(status: VoiceStatus.listening));
      await tester.pumpAndSettle();
      stateCtrl.add(const VoiceState(status: VoiceStatus.idle));
      await tester.pumpAndSettle();

      final startCount = wakeService.calls.where((c) => c == 'start').length;
      expect(startCount, greaterThanOrEqualTo(2));
    });

    testWidgets('re-arms engine when status transitions to error', (
      tester,
    ) async {
      // After a no-speech / failed turn the bot lands at VoiceStatus.error
      // (the "Try again" card). The mic is free there, so the wake engine must
      // be armed — otherwise the user can only re-wake by tapping "Try again".
      final stateCtrl = StreamController<VoiceState>.broadcast();
      addTearDown(stateCtrl.close);
      whenListen(voiceBloc, stateCtrl.stream, initialState: const VoiceState());

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      stateCtrl.add(const VoiceState(status: VoiceStatus.listening));
      await tester.pumpAndSettle();
      stateCtrl.add(const VoiceState(status: VoiceStatus.error));
      await tester.pumpAndSettle();

      final startCount = wakeService.calls.where((c) => c == 'start').length;
      expect(startCount, greaterThanOrEqualTo(2));
    });

    testWidgets('does not arm engine when wake word is disabled', (
      tester,
    ) async {
      when(() => settingsCubit.state).thenReturn(_disabledSettings);
      whenListen(
        settingsCubit,
        Stream<VoiceSettings>.empty(),
        initialState: _disabledSettings,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(wakeService.calls.where((c) => c == 'start'), isEmpty);
    });
  });

  group('VoiceOverlayPage — media button wiring', () {
    testWidgets('press while idle dispatches VoiceListenRequested', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      mediaButtonService.emitPress();
      await tester.pump();

      // Media button uses the same wake-initiated semantics as the wake word —
      // earcon skipped, leading wake phrase stripped (Plan A commit 3).
      verify(
        () => voiceBloc.add(const VoiceListenRequested(fromWakeWord: true)),
      ).called(1);
    });

    testWidgets('press while in error state dispatches VoiceListenRequested', (
      tester,
    ) async {
      // The "Try again" state must accept a headset tap to re-wake, not only
      // the on-screen button.
      whenListen(
        voiceBloc,
        Stream<VoiceState>.empty(),
        initialState: const VoiceState(status: VoiceStatus.error),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      mediaButtonService.emitPress();
      await tester.pump();

      verify(
        () => voiceBloc.add(const VoiceListenRequested(fromWakeWord: true)),
      ).called(1);
    });

    testWidgets('press while not idle/error does not dispatch', (tester) async {
      whenListen(
        voiceBloc,
        Stream<VoiceState>.empty(),
        initialState: const VoiceState(status: VoiceStatus.listening),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      mediaButtonService.emitPress();
      await tester.pump();

      verifyNever(
        () => voiceBloc.add(const VoiceListenRequested(fromWakeWord: true)),
      );
    });
  });

  group('VoiceOverlayPage — wake word re-trigger', () {
    testWidgets(
      'detection while in error state dispatches VoiceListenRequested',
      (tester) async {
        whenListen(
          voiceBloc,
          Stream<VoiceState>.empty(),
          initialState: const VoiceState(status: VoiceStatus.error),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        wakeService._detected.add(WakeWordPreset.thomas);
        await tester.pump();

        verify(
          () => voiceBloc.add(const VoiceListenRequested(fromWakeWord: true)),
        ).called(1);
      },
    );

    testWidgets('detection while listening does not dispatch', (tester) async {
      whenListen(
        voiceBloc,
        Stream<VoiceState>.empty(),
        initialState: const VoiceState(status: VoiceStatus.listening),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      wakeService._detected.add(WakeWordPreset.thomas);
      await tester.pump();

      verifyNever(
        () => voiceBloc.add(const VoiceListenRequested(fromWakeWord: true)),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Interrupt button wiring — Issue #4
  //
  // Tapping the interrupt button in the speaking state must dispatch
  // VoiceInterruptRequested (not VoiceListenStopRequested, which was the old
  // wiring and is a no-op while the bot is speaking).
  // ---------------------------------------------------------------------------
  group('VoiceOverlayPage — interrupt button', () {
    testWidgets(
      'speaking state: tapping interrupt dispatches VoiceInterruptRequested',
      (tester) async {
        final stateCtrl = StreamController<VoiceState>.broadcast();
        addTearDown(stateCtrl.close);
        whenListen(
          voiceBloc,
          stateCtrl.stream,
          initialState: const VoiceState(status: VoiceStatus.speaking),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(VoiceOverlayKeys.interruptButtonKey));
        await tester.pump();

        verify(() => voiceBloc.add(const VoiceInterruptRequested())).called(1);
        verifyNever(() => voiceBloc.add(const VoiceListenStopRequested()));
      },
    );
  });
}
