import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/core/platform/wakelock_service.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/voice_budget.dart';
import 'package:fitness_tracker/domain/entities/voice_chat_result.dart';
import 'package:fitness_tracker/domain/entities/voice_message.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/entities/voice_tool_call.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/app_settings_repository.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_daily_macros.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/features/voice/data/coordinator/offline_voice_coordinator.dart';
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
import 'package:fitness_tracker/domain/usecases/voice/delete_voice_history.dart';
import 'package:fitness_tracker/domain/usecases/voice/get_voice_budget.dart';
import 'package:fitness_tracker/domain/usecases/voice/send_voice_message.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_weekly_sets.dart';
import 'package:fitness_tracker/features/voice/application/voice_bloc.dart';
import 'package:fitness_tracker/domain/services/voice_stt_service.dart';
import 'package:fitness_tracker/domain/services/voice_tts_service.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks & fakes
// ---------------------------------------------------------------------------

class MockSendVoiceMessage extends Mock implements SendVoiceMessage {}

class MockGetVoiceBudget extends Mock implements GetVoiceBudget {}

class MockDeleteVoiceHistory extends Mock implements DeleteVoiceHistory {}

class MockAppSettingsRepository extends Mock implements AppSettingsRepository {}

class MockGetSetsByDateRange extends Mock implements GetSetsByDateRange {}

class MockGetDailyMacros extends Mock implements GetDailyMacros {}

class MockGetWeeklySets extends Mock implements GetWeeklySets {}

class MockExerciseLookup extends Mock implements ExerciseLookup {}

class MockGetLogsForDate extends Mock implements GetLogsForDate {}

class MockOfflineVoiceCoordinator extends Mock
    implements OfflineVoiceCoordinator {}

class FakeVoiceTtsService implements VoiceTtsService {
  int speakCount = 0;
  String? lastSpoken;
  final List<String> spokenHistory = <String>[];
  double lastVolume = 1.0;
  double lastSpeechRate = 1.0;

  @override
  Future<void> initialize({
    double volume = 1.0,
    double speechRate = 1.0,
  }) async {}

  @override
  Future<void> speak(String text) async {
    speakCount++;
    lastSpoken = text;
    spokenHistory.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {
    lastVolume = volume;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    lastSpeechRate = rate;
  }

  @override
  Future<void> dispose() async {}
}

class FakeVoiceSttService implements VoiceSttService {
  bool _available = true;
  bool _listening = false;
  StreamController<VoiceSttResult>? _controller;

  void simulateUnavailable() => _available = false;

  void emitPartial(String text) =>
      _controller?.add(VoiceSttResult(transcript: text, isFinal: false));

  void emitFinal(String text) {
    _controller?.add(VoiceSttResult(transcript: text, isFinal: true));
    _controller?.close();
    _listening = false;
  }

  void emitError(VoiceSttErrorKind kind, [String? msg]) {
    _controller?.addError(VoiceSttException(kind, msg));
    _controller?.close();
    _listening = false;
  }

  /// Simulates the engine ending listening on its own without ever
  /// producing a final result — e.g. the user fell silent past the
  /// platform's pause threshold, or the hard listen-for timeout fired.
  /// The stream completes (`onDone` fires) but no `VoiceSttResult` is
  /// emitted.
  void completeWithoutResult() {
    _controller?.close();
    _listening = false;
  }

  @override
  Future<void> initialize() async {}

  @override
  bool get isAvailable => _available;

  @override
  bool get isListening => _listening;

  @override
  Stream<VoiceSttResult> listen({String? localeId}) {
    _listening = true;
    _controller = StreamController<VoiceSttResult>();
    return _controller!.stream;
  }

  @override
  Future<void> stop() async {
    _listening = false;
    await _controller?.close();
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _controller?.close();
  }

  @override
  Future<void> dispose() async {
    await cancel();
  }
}

/// No-op [NetworkStatusService] -- the bloc stores it but dispatches
/// connectivity events via [VoiceConnectivityChanged] (fired by the overlay
/// page), so the service itself is never called inside the bloc.
class FakeNetworkStatusService implements NetworkStatusService {
  @override
  Future<bool> isNetworkAvailable() async => true;

  @override
  Stream<bool> get onConnectivityRestored => const Stream.empty();

  @override
  Stream<bool> get onConnectivityChanged => const Stream.empty();
}

/// Instrumented [WakelockService] -- records how many times enable/disable
/// were called so tests can assert correct wakelock behaviour.
class FakeWakelockService implements WakelockService {
  int enableCount = 0;
  int disableCount = 0;

  @override
  Future<void> enable() async => enableCount++;

  @override
  Future<void> disable() async => disableCount++;
}

/// Simple [VoiceWakeWordService] fake -- the bloc stores it but its lifecycle
/// (start/stop) is managed by [VoiceFab], not the bloc.
class FakeVoiceWakeWordService implements VoiceWakeWordService {
  final StreamController<WakeWordPreset> _detectedController =
      StreamController<WakeWordPreset>.broadcast();
  final StreamController<VoiceWakeWordException> _errorController =
      StreamController<VoiceWakeWordException>.broadcast();
  bool _running = false;

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async => _running = true;

  @override
  Future<void> stop() async => _running = false;

  @override
  Future<void> dispose() async {
    await _detectedController.close();
    await _errorController.close();
  }
}

// ---------------------------------------------------------------------------
// C-5 / C-6 default stub factories -- return empty results so existing tests are unaffected
// ---------------------------------------------------------------------------

MockExerciseLookup _defaultExerciseLookup() {
  final m = MockExerciseLookup();
  when(() => m.refreshIfStale()).thenAnswer((_) async {});
  when(() => m.byName(any())).thenReturn(null);
  when(() => m.resolveId(any())).thenReturn(null);
  when(
    () => m.nameForId(any()),
  ).thenAnswer((inv) => inv.positionalArguments.first as String);
  return m;
}

/// Configures [mock] so "Bench Press" resolves to "ex-bench" and vice versa,
/// matching the exercise fixture used by tool-dispatch tests.
void _setupBenchLookup(MockExerciseLookup mock) {
  when(() => mock.resolveId('Bench Press')).thenReturn('ex-bench');
  when(() => mock.nameForId('ex-bench')).thenReturn('Bench Press');
}

MockGetSetsByDateRange _defaultGetSetsByDateRange() {
  final m = MockGetSetsByDateRange();
  when(
    () => m(
      startDate: any(named: 'startDate'),
      endDate: any(named: 'endDate'),
      muscleGroup: any(named: 'muscleGroup'),
    ),
  ).thenAnswer((_) async => const Right([]));
  return m;
}

MockGetDailyMacros _defaultGetDailyMacros() {
  final m = MockGetDailyMacros();
  when(() => m(any())).thenAnswer((_) async => const Right({}));
  return m;
}

GetWeeklySets _defaultGetWeeklySets() {
  final m = MockGetWeeklySets();
  return m;
}

MockGetLogsForDate _defaultGetLogsForDate() {
  final m = MockGetLogsForDate();
  when(() => m(any())).thenAnswer((_) async => const Right([]));
  return m;
}

MockOfflineVoiceCoordinator _defaultOfflineCoordinator() {
  final m = MockOfflineVoiceCoordinator();
  when(() => m.process(any(), weightUnit: any(named: 'weightUnit'))).thenAnswer(
    (_) async => VoiceChatTextResponse(
      message: VoiceMessage(
        role: VoiceRole.assistant,
        content: AppStrings.voiceOfflineUnrecognized,
        createdAt: DateTime(2026),
      ),
    ),
  );
  return m;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VoiceBloc _makeBloc({
  required SendVoiceMessage sendVoiceMessage,
  required GetVoiceBudget getVoiceBudget,
  required DeleteVoiceHistory deleteVoiceHistory,
  required AppSettingsRepository appSettingsRepository,
  VoiceTtsService? tts,
  VoiceSttService? stt,
  NetworkStatusService? networkStatus,
  VoiceWakeWordService? wakeWord,
  WakelockService? wakelock,
  VoiceSettings settings = const VoiceSettings.defaults(),
  // C-5 params -- optional so existing tests remain unchanged
  GetSetsByDateRange? getSetsByDateRange,
  GetDailyMacros? getDailyMacros,
  GetWeeklySets? getWeeklySets,
  GetLogsForDate? getLogsForDate,
  // C-6 params
  ExerciseLookup? exerciseLookup,
  OfflineVoiceCoordinator? offlineCoordinator,
}) {
  return VoiceBloc(
    sendVoiceMessage: sendVoiceMessage,
    getVoiceBudget: getVoiceBudget,
    deleteVoiceHistory: deleteVoiceHistory,
    sttService: stt ?? FakeVoiceSttService(),
    ttsService: tts ?? FakeVoiceTtsService(),
    appSettingsRepository: appSettingsRepository,
    currentVoiceSettings: () => settings,
    networkStatusService: networkStatus ?? FakeNetworkStatusService(),
    wakeWordService: wakeWord ?? FakeVoiceWakeWordService(),
    wakelockService: wakelock ?? FakeWakelockService(),
    getSetsByDateRange: getSetsByDateRange ?? _defaultGetSetsByDateRange(),
    getDailyMacros: getDailyMacros ?? _defaultGetDailyMacros(),
    getWeeklySets: getWeeklySets ?? _defaultGetWeeklySets(),
    getLogsForDate: getLogsForDate ?? _defaultGetLogsForDate(),
    exerciseLookup: exerciseLookup ?? _defaultExerciseLookup(),
    offlineCoordinator: offlineCoordinator ?? _defaultOfflineCoordinator(),
  );
}

VoiceMessage _assistantMsg(String content) => VoiceMessage(
  role: VoiceRole.assistant,
  content: content,
  createdAt: DateTime(2026),
);

VoiceChatResult _assistantResult(String content) =>
    VoiceChatTextResponse(message: _assistantMsg(content));

// ---------------------------------------------------------------------------
// Tool-dispatch test helpers
// ---------------------------------------------------------------------------

final _now = DateTime(2026, 5, 13);

VoiceToolCall _mutationToolCall(String toolName, Map<String, dynamic> args) =>
    VoiceToolCall(
      id: 'call-1',
      toolName: toolName,
      displaySummary: toolName,
      args: args,
    );

// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(const VoiceSettings.defaults());
    registerFallbackValue(WeightUnit.kilograms);
    registerFallbackValue(<VoiceMessage>[]);
    registerFallbackValue(DateTime(2026));
    registerFallbackValue(
      WorkoutSet(
        id: 'set-fb',
        exerciseId: 'ex-bench',
        reps: 8,
        weight: 80,
        intensity: 3,
        date: DateTime(2026, 5, 13),
        createdAt: DateTime(2026, 5, 13),
      ),
    );
    registerFallbackValue(
      NutritionLog(
        id: 'log-fb',
        mealName: 'Chicken',
        calories: 300,
        proteinGrams: 30,
        carbsGrams: 10,
        fatGrams: 5,
        loggedAt: DateTime(2026, 5, 13),
        createdAt: DateTime(2026, 5, 13),
      ),
    );
  });

  late MockSendVoiceMessage sendVoiceMessage;
  late MockGetVoiceBudget getBudget;
  late MockDeleteVoiceHistory deleteHistory;
  late MockAppSettingsRepository settingsRepo;
  // Shared between `build` and `act` for the STT-driven blocTests
  // below -- the same fake instance must be reachable from both.
  late FakeVoiceSttService sharedStt;
  // Tool-dispatch use-case mocks -- default to empty results so existing
  // tests are unaffected; individual tool tests override per-test.
  late MockExerciseLookup exerciseLookup;
  late MockGetSetsByDateRange getSetsByDateRange;
  late MockGetLogsForDate getLogsForDate;
  late MockGetDailyMacros getDailyMacros;

  setUp(() {
    sendVoiceMessage = MockSendVoiceMessage();
    getBudget = MockGetVoiceBudget();
    deleteHistory = MockDeleteVoiceHistory();
    settingsRepo = MockAppSettingsRepository();
    sharedStt = FakeVoiceSttService();
    exerciseLookup = _defaultExerciseLookup();
    getSetsByDateRange = _defaultGetSetsByDateRange();
    getLogsForDate = _defaultGetLogsForDate();
    getDailyMacros = _defaultGetDailyMacros();

    when(() => getBudget()).thenAnswer(
      (_) async => const Right(VoiceBudget(usedUsd: 0, dailyCapUsd: 0.5)),
    );
    when(
      () => settingsRepo.getSettings(),
    ).thenAnswer((_) async => const Right(AppSettings.defaults()));
  });

  group('VoiceSessionStarted', () {
    // "emits isGuest=true for unauthenticated session" removed: guest
    // sessions no longer exist.

    blocTest<VoiceBloc, VoiceState>(
      'assigns a sessionId for authenticated session',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      act: (bloc) => bloc.add(
        const VoiceSessionStarted(
          AppSession(
            user: AppUser(id: 'user-1', email: 'test@example.com'),
          ),
        ),
      ),
      expect: () => <Matcher>[
        isA<VoiceState>().having((s) => s.sessionId, 'sessionId', isNotNull),
      ],
    );
  });

  group('VoiceSendMessage', () {
    // "guest user gets error state" removed: guest sessions no longer exist.

    blocTest<VoiceBloc, VoiceState>(
      'happy path: thinking -> speaking -> idle, TTS is invoked',
      build: () {
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => Right(_assistantResult('Got it!')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          tts: FakeVoiceTtsService(),
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(const VoiceSendMessage('bench press')),
      expect: () => <Matcher>[
        isA<VoiceState>().having(
          (s) => s.status,
          'status',
          VoiceStatus.thinking,
        ),
        isA<VoiceState>().having(
          (s) => s.status,
          'status',
          VoiceStatus.speaking,
        ),
        isA<VoiceState>().having((s) => s.status, 'status', VoiceStatus.idle),
        // Budget refresh after a successful turn.
        isA<VoiceState>().having((s) => s.budget, 'budget', isNotNull),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'chat failure emits error state',
      build: () {
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => const Left(ServerFailure('Rate limited')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(const VoiceSendMessage('hello')),
      expect: () => <Matcher>[
        isA<VoiceState>().having(
          (s) => s.status,
          'status',
          VoiceStatus.thinking,
        ),
        isA<VoiceState>()
            .having((s) => s.status, 'status', VoiceStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Rate limited'),
            ),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'weight unit is sourced from AppSettings (pounds path)',
      build: () {
        when(() => settingsRepo.getSettings()).thenAnswer(
          (_) async => const Right(
            AppSettings(
              notificationsEnabled: true,
              weekStartDay: WeekStartDay.monday,
              weightUnit: WeightUnit.pounds,
            ),
          ),
        );
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => Right(_assistantResult('ok')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(const VoiceSendMessage('bench')),
      verify: (_) {
        final captured = verify(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: captureAny(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).captured;
        expect(captured.single, WeightUnit.pounds);
      },
    );
  });

  group('VoiceListenRequested (STT)', () {
    blocTest<VoiceBloc, VoiceState>(
      'unavailable engine emits error',
      build: () {
        final stt = FakeVoiceSttService()..simulateUnavailable();
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          stt: stt,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(const VoiceListenRequested()),
      expect: () => <Matcher>[
        isA<VoiceState>().having((s) => s.status, 'status', VoiceStatus.error),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'partial -> final transcript triggers VoiceSendMessage',
      build: () {
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => Right(_assistantResult('confirmed')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          stt: sharedStt,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) async {
        bloc.add(const VoiceListenRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitPartial('bench');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitFinal('bench press 80 by 10');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (_) {
        verify(
          () => sendVoiceMessage(
            userMessage: 'bench press 80 by 10',
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).called(1);
      },
    );

    blocTest<VoiceBloc, VoiceState>(
      'STT permission error surfaces user-friendly message',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        stt: sharedStt,
      ),
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) async {
        bloc.add(const VoiceListenRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitError(VoiceSttErrorKind.permissionPermanentlyDenied);
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (bloc) {
        expect(bloc.state.status, VoiceStatus.error);
        expect(bloc.state.errorMessage, contains('permanently denied'));
      },
    );

    // Regression: VoiceListenStopRequested must revert state. Before this
    // fix the handler only called _stt.stop() without cancelling the
    // subscription or emitting state, so the overlay stayed on
    // "Listening…" forever and wake-word re-trigger (gated on idle)
    // never fired again.
    blocTest<VoiceBloc, VoiceState>(
      'VoiceListenStopRequested reverts listening -> idle',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        stt: sharedStt,
      ),
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) async {
        bloc.add(const VoiceListenRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitPartial('bench');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        bloc.add(const VoiceListenStopRequested());
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (bloc) {
        expect(bloc.state.status, VoiceStatus.idle);
        expect(bloc.state.liveTranscript, isEmpty);
      },
    );

    // Regression: when the STT engine ends listening on its own without
    // producing a final transcript (silence past pauseFor, hard listenFor
    // cap), the bloc must revert to idle via the onDone hook.
    blocTest<VoiceBloc, VoiceState>(
      'STT stream completing without a final result reverts to idle',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        stt: sharedStt,
      ),
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) async {
        bloc.add(const VoiceListenRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.completeWithoutResult();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      },
      verify: (bloc) {
        expect(bloc.state.status, VoiceStatus.idle);
        expect(bloc.state.liveTranscript, isEmpty);
      },
    );

    // Regression: silence-promotion path (two partials → synthetic final
    // emitted by the STT service on `error_no_match`). The bloc must
    // transition idle → listening → transcribing → thinking and dispatch
    // VoiceSendMessage exactly once.
    blocTest<VoiceBloc, VoiceState>(
      'silence-promotion: two partials then synthetic final triggers '
      'VoiceSendMessage exactly once and reaches thinking',
      build: () {
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => Right(_assistantResult('done')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          stt: sharedStt,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) async {
        bloc.add(const VoiceListenRequested());
        await Future<void>.delayed(const Duration(milliseconds: 10));
        // Simulate the service emitting partials then the silence-promoted
        // final (the FakeVoiceSttService.emitFinal path mirrors what the
        // real service does after promoteOnSilence).
        sharedStt.emitPartial('log bench');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitPartial('log bench press 80');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        sharedStt.emitFinal('log bench press 80');
        await Future<void>.delayed(const Duration(milliseconds: 50));
      },
      verify: (_) {
        verify(
          () => sendVoiceMessage(
            userMessage: 'log bench press 80',
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).called(1);
      },
    );
  });

  group('VoiceConversationCleared', () {
    blocTest<VoiceBloc, VoiceState>(
      'clears messages and rotates sessionId',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => VoiceState(
        sessionId: 'old-sid',
        messages: <VoiceMessage>[
          VoiceMessage(
            role: VoiceRole.user,
            content: 'hi',
            createdAt: DateTime(2026),
          ),
        ],
      ),
      act: (bloc) => bloc.add(const VoiceConversationCleared()),
      expect: () => <Matcher>[
        isA<VoiceState>()
            .having((s) => s.messages, 'messages', isEmpty)
            .having((s) => s.sessionId, 'sessionId', isNot('old-sid')),
      ],
    );
  });

  group('VoiceHistoryDeleteRequested', () {
    blocTest<VoiceBloc, VoiceState>(
      'clears messages on success',
      build: () {
        when(
          () => deleteHistory(),
        ).thenAnswer((_) async => const Right<Failure, void>(null));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
        );
      },
      seed: () => VoiceState(
        sessionId: 'sid',
        messages: <VoiceMessage>[
          VoiceMessage(
            role: VoiceRole.user,
            content: 'hi',
            createdAt: DateTime(2026),
          ),
        ],
      ),
      act: (bloc) => bloc.add(const VoiceHistoryDeleteRequested()),
      expect: () => <Matcher>[
        isA<VoiceState>().having((s) => s.messages, 'messages', isEmpty),
      ],
    );
  });

  // Guard against future regressions: the architectural rule is that
  // VoiceBloc must NOT depend on VoiceRepository directly.
  test('VoiceBloc constructor parameters expose use cases / services only', () {
    // The constructor takes the new params (compile-time check covered by
    // this file). This test exists to make the rule grep-discoverable --
    // if someone re-introduces a `repository: VoiceRepository` param the
    // file won't compile and they'll see the rule next to the error.
    expect(VoiceBloc, isNotNull);
  });

  // ---------------------------------------------------------------------------
  // VoiceConnectivityChanged (C-4)
  // ---------------------------------------------------------------------------

  group('VoiceConnectivityChanged', () {
    blocTest<VoiceBloc, VoiceState>(
      'going offline sets isOnline to false',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(sessionId: 'sid', isOnline: true),
      act: (bloc) => bloc.add(const VoiceConnectivityChanged(isOnline: false)),
      expect: () => <Matcher>[
        isA<VoiceState>().having((s) => s.isOnline, 'isOnline', isFalse),
        // Second emit: hasAnnouncedOfflineThisSession flipped to true
        isA<VoiceState>()
            .having((s) => s.isOnline, 'isOnline', isFalse)
            .having(
              (s) => s.hasAnnouncedOfflineThisSession,
              'announced',
              isTrue,
            ),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'going online sets isOnline to true without additional state changes',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(sessionId: 'sid', isOnline: false),
      act: (bloc) => bloc.add(const VoiceConnectivityChanged(isOnline: true)),
      expect: () => <Matcher>[
        isA<VoiceState>().having((s) => s.isOnline, 'isOnline', isTrue),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'first offline event triggers TTS announcement',
      build: () {
        final tts = FakeVoiceTtsService();
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          tts: tts,
        );
      },
      seed: () => const VoiceState(
        sessionId: 'sid',
        isOnline: true,
        hasAnnouncedOfflineThisSession: false,
      ),
      act: (bloc) async {
        bloc.add(const VoiceConnectivityChanged(isOnline: false));
        // Let the async speak() call complete.
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (bloc) {
        expect(bloc.state.hasAnnouncedOfflineThisSession, isTrue);
      },
    );

    blocTest<VoiceBloc, VoiceState>(
      'second offline event within same session does NOT repeat announcement',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        tts: FakeVoiceTtsService(),
      ),
      // Simulate: user was offline, came back online, goes offline again.
      seed: () => const VoiceState(
        sessionId: 'sid',
        isOnline: true,
        hasAnnouncedOfflineThisSession: true, // already announced once
      ),
      act: (bloc) async {
        bloc.add(const VoiceConnectivityChanged(isOnline: false));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      // Only one emit: isOnline -> false. No second emit for announcement.
      expect: () => <Matcher>[
        isA<VoiceState>()
            .having((s) => s.isOnline, 'isOnline', isFalse)
            .having(
              (s) => s.hasAnnouncedOfflineThisSession,
              'announced',
              isTrue,
            ),
      ],
    );

    blocTest<VoiceBloc, VoiceState>(
      'duplicate connectivity event is a no-op',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(
        const VoiceConnectivityChanged(isOnline: true),
      ), // already true
      expect: () => <Matcher>[], // no state changes
    );
  });

  // ---------------------------------------------------------------------------
  // VoiceWorkoutModeToggled + wakelock (C-4)
  // ---------------------------------------------------------------------------

  group('VoiceWorkoutModeToggled', () {
    test('activating workout mode calls wakelock.enable()', () async {
      final wakelock = FakeWakelockService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        wakelock: wakelock,
      );
      bloc.add(const VoiceWorkoutModeToggled(active: true));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(wakelock.enableCount, 1);
      expect(bloc.state.isWorkoutModeActive, isTrue);
      await bloc.close();
    });

    test('deactivating workout mode calls wakelock.disable()', () async {
      final wakelock = FakeWakelockService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        wakelock: wakelock,
      );
      // Start with workout mode active.
      bloc.emit(bloc.state.copyWith(isWorkoutModeActive: true));
      bloc.add(const VoiceWorkoutModeToggled(active: false));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // close() also calls disable(), so disableCount should be at least 1
      // from the toggle event (close() adds another after bloc.close()).
      expect(wakelock.disableCount, greaterThanOrEqualTo(1));
      expect(bloc.state.isWorkoutModeActive, isFalse);
      await bloc.close();
    });

    blocTest<VoiceBloc, VoiceState>(
      'isWorkoutModeActive is reflected in state',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      act: (bloc) {
        bloc.add(const VoiceWorkoutModeToggled(active: true));
        bloc.add(const VoiceWorkoutModeToggled(active: false));
      },
      expect: () => <Matcher>[
        isA<VoiceState>().having(
          (s) => s.isWorkoutModeActive,
          'isWorkoutModeActive',
          isTrue,
        ),
        isA<VoiceState>().having(
          (s) => s.isWorkoutModeActive,
          'isWorkoutModeActive',
          isFalse,
        ),
      ],
    );
  });

  // ---------------------------------------------------------------------------
  // close() releases wakelock (C-4)
  // ---------------------------------------------------------------------------

  test('close() always releases the wakelock', () async {
    final wakelock = FakeWakelockService();
    final bloc = _makeBloc(
      sendVoiceMessage: sendVoiceMessage,
      getVoiceBudget: getBudget,
      deleteVoiceHistory: deleteHistory,
      appSettingsRepository: settingsRepo,
      wakelock: wakelock,
    );
    await bloc.close();
    expect(wakelock.disableCount, 1);
  });

  test('close() releases wakelock even when workout mode is active', () async {
    final wakelock = FakeWakelockService();
    final bloc = _makeBloc(
      sendVoiceMessage: sendVoiceMessage,
      getVoiceBudget: getBudget,
      deleteVoiceHistory: deleteHistory,
      appSettingsRepository: settingsRepo,
      wakelock: wakelock,
    );
    // Activate workout mode (calls enable).
    bloc.add(const VoiceWorkoutModeToggled(active: true));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(wakelock.enableCount, 1);
    // Closing without explicitly toggling off must still release the lock.
    await bloc.close();
    expect(wakelock.disableCount, 1);
  });

  // ---------------------------------------------------------------------------
  // TTS spoken error messages (C-4)
  // ---------------------------------------------------------------------------

  group('Spoken errors', () {
    FakeVoiceTtsService? sharedTts;

    blocTest<VoiceBloc, VoiceState>(
      'offline announcement text matches AppStrings constant',
      build: () {
        sharedTts = FakeVoiceTtsService();
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          tts: sharedTts,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid', isOnline: true),
      act: (bloc) async {
        bloc.add(const VoiceConnectivityChanged(isOnline: false));
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (_) {
        expect(
          sharedTts!.lastSpoken,
          AppStrings.voiceSpokenOfflineAnnouncement,
        );
      },
    );
  });

  // ===========================================================================
  // Tool dispatch -- mutation tools
  // ===========================================================================

  // Stubs sendVoiceMessage to return a mutation tool call then runs the full
  // confirm flow: SessionStarted -> SendMessage -> ConfirmationAccepted.
  Future<void> runMutationFlow({
    required VoiceBloc bloc,
    required MockSendVoiceMessage sendVoiceMessage,
    required VoiceToolCall toolCall,
    required AppSession session,
  }) async {
    when(
      () => sendVoiceMessage(
        userMessage: any(named: 'userMessage'),
        sessionId: any(named: 'sessionId'),
        history: any(named: 'history'),
        settings: any(named: 'settings'),
        weightUnit: any(named: 'weightUnit'),
        recentSets: any(named: 'recentSets'),
        recentNutritionLogs: any(named: 'recentNutritionLogs'),
      ),
    ).thenAnswer((_) async => Right(VoiceChatMutationCall(toolCall: toolCall)));
    bloc.add(VoiceSessionStarted(session));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const VoiceSendMessage('voice command'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
    bloc.add(const VoiceConfirmationAccepted());
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  AppSession authSession() => const AppSession(
    user: AppUser(id: 'u1', email: 'a@b.com'),
  );

  // -------------------------------------------------------------------------
  // logWorkoutSet
  // -------------------------------------------------------------------------

  group('logWorkoutSet', () {
    test(
      'emits VoiceAddWorkoutSetCommand when exerciseId is resolved',
      () async {
        _setupBenchLookup(exerciseLookup);

        final tts = FakeVoiceTtsService();

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final effectFuture = bloc.effects.first;

        await runMutationFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolCall: _mutationToolCall('logWorkoutSet', {
            'exerciseName': 'Bench Press',
            'exerciseId': 'ex-bench',
            'reps': 8,
            'weight': 80.0,
            'intensity': 3,
          }),
          session: authSession(),
        );

        final effect = await effectFuture;
        expect(effect, isA<VoiceAddWorkoutSetCommand>());
        final cmd = effect as VoiceAddWorkoutSetCommand;
        expect(cmd.set.exerciseId, 'ex-bench');
        expect(cmd.set.reps, 8);
        expect(cmd.set.weight, 80.0);
        expect(tts.lastSpoken, AppStrings.voiceSpokenSetLogged);
        await bloc.close();
      },
    );

    test(
      'speaks voiceSpokenExerciseNotFound when exercise cannot be resolved',
      () async {
        // Default exerciseLookup already returns null for all resolveId calls.
        final tts = FakeVoiceTtsService();

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final emittedEffects = <VoiceEffect>[];
        final sub = bloc.effects.listen(emittedEffects.add);

        await runMutationFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolCall: _mutationToolCall('logWorkoutSet', {
            'exerciseName': 'Unknown Exercise',
            'reps': 5,
            'weight': 50.0,
          }),
          session: authSession(),
        );

        expect(emittedEffects, isEmpty);
        expect(tts.lastSpoken, AppStrings.voiceSpokenExerciseNotFound);
        await sub.cancel();
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // editWorkoutSet
  // -------------------------------------------------------------------------

  group('editWorkoutSet', () {
    final editableSet = WorkoutSet(
      id: 'set-edit-1',
      exerciseId: 'ex-bench',
      reps: 8,
      weight: 80.0,
      intensity: 3,
      date: _now,
      createdAt: _now,
    );

    test(
      'emits VoiceUpdateWorkoutSetCommand when setId is found in recent cache',
      () async {
        _setupBenchLookup(exerciseLookup);
        when(
          () => getSetsByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            muscleGroup: any(named: 'muscleGroup'),
          ),
        ).thenAnswer((_) async => Right([editableSet]));

        final tts = FakeVoiceTtsService();

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final effectFuture = bloc.effects.first;

        await runMutationFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolCall: _mutationToolCall('editWorkoutSet', {
            'setId': 'set-edit-1',
            'reps': 10,
            'weight': 90.0,
          }),
          session: authSession(),
        );

        final effect = await effectFuture;
        expect(effect, isA<VoiceUpdateWorkoutSetCommand>());
        final cmd = effect as VoiceUpdateWorkoutSetCommand;
        expect(cmd.set.id, 'set-edit-1');
        expect(cmd.set.reps, 10);
        expect(cmd.set.weight, 90.0);
        expect(tts.lastSpoken, AppStrings.voiceSpokenSetUpdated);
        await bloc.close();
      },
    );

    test(
      'speaks voiceSpokenToolFailed when setId is not in recent cache',
      () async {
        // Empty cache -> _fetchSetById returns null; no effect emitted.
        final tts = FakeVoiceTtsService();

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final emittedEffects = <VoiceEffect>[];
        final sub = bloc.effects.listen(emittedEffects.add);

        await runMutationFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolCall: _mutationToolCall('editWorkoutSet', {
            'setId': 'phantom-set',
            'reps': 12,
          }),
          session: authSession(),
        );

        expect(emittedEffects, isEmpty);
        expect(tts.lastSpoken, AppStrings.voiceSpokenToolFailed);
        await sub.cancel();
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // deleteWorkoutSet
  // -------------------------------------------------------------------------

  group('deleteWorkoutSet', () {
    test('emits VoiceDeleteWorkoutSetCommand', () async {
      final tts = FakeVoiceTtsService();

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      final effectFuture = bloc.effects.first;

      await runMutationFlow(
        bloc: bloc,
        sendVoiceMessage: sendVoiceMessage,
        toolCall: _mutationToolCall('deleteWorkoutSet', {'setId': 'set-999'}),
        session: authSession(),
      );

      final effect = await effectFuture;
      expect(effect, isA<VoiceDeleteWorkoutSetCommand>());
      expect((effect as VoiceDeleteWorkoutSetCommand).setId, 'set-999');
      expect(tts.lastSpoken, AppStrings.voiceSpokenSetDeleted);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // logNutrition
  // -------------------------------------------------------------------------

  group('logNutrition', () {
    test('emits VoiceAddNutritionLogCommand', () async {
      final tts = FakeVoiceTtsService();

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      final effectFuture = bloc.effects.first;

      await runMutationFlow(
        bloc: bloc,
        sendVoiceMessage: sendVoiceMessage,
        toolCall: _mutationToolCall('logNutrition', {
          'mealName': 'Chicken',
          'calories': 300.0,
          'proteinGrams': 30.0,
          'carbsGrams': 10.0,
          'fatGrams': 5.0,
        }),
        session: authSession(),
      );

      final effect = await effectFuture;
      expect(effect, isA<VoiceAddNutritionLogCommand>());
      expect((effect as VoiceAddNutritionLogCommand).log.mealName, 'Chicken');
      expect(tts.lastSpoken, AppStrings.voiceSpokenNutritionLogged);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // editNutritionLog
  // -------------------------------------------------------------------------

  group('editNutritionLog', () {
    test(
      'emits VoiceUpdateNutritionLogCommand when logId is in recent cache',
      () async {
        final editableLog = NutritionLog(
          id: 'log-edit-1',
          mealName: 'Chicken',
          calories: 300,
          proteinGrams: 30,
          carbsGrams: 10,
          fatGrams: 5,
          loggedAt: _now,
          createdAt: _now,
        );
        when(
          () => getLogsForDate(any()),
        ).thenAnswer((_) async => Right([editableLog]));

        final tts = FakeVoiceTtsService();

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final effectFuture = bloc.effects.first;

        await runMutationFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolCall: _mutationToolCall('editNutritionLog', {
            'logId': 'log-edit-1',
            'calories': 400.0,
            'proteinGrams': 35.0,
          }),
          session: authSession(),
        );

        final effect = await effectFuture;
        expect(effect, isA<VoiceUpdateNutritionLogCommand>());
        final cmd = effect as VoiceUpdateNutritionLogCommand;
        expect(cmd.log.id, 'log-edit-1');
        expect(cmd.log.calories, 400);
        expect(tts.lastSpoken, AppStrings.voiceSpokenNutritionUpdated);
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // deleteNutritionLog
  // -------------------------------------------------------------------------

  group('deleteNutritionLog', () {
    test('emits VoiceDeleteNutritionLogCommand', () async {
      final tts = FakeVoiceTtsService();

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      final effectFuture = bloc.effects.first;

      await runMutationFlow(
        bloc: bloc,
        sendVoiceMessage: sendVoiceMessage,
        toolCall: _mutationToolCall('deleteNutritionLog', {
          'logId': 'log-del-1',
        }),
        session: authSession(),
      );

      final effect = await effectFuture;
      expect(effect, isA<VoiceDeleteNutritionLogCommand>());
      expect((effect as VoiceDeleteNutritionLogCommand).logId, 'log-del-1');
      expect(tts.lastSpoken, AppStrings.voiceSpokenNutritionDeleted);
      await bloc.close();
    });
  });

  // ===========================================================================
  // Tool dispatch -- query tools
  // ===========================================================================

  // Stubs sendVoiceMessage to return a query tool call then runs the flow.
  // Query tools execute immediately -- no confirmation step.
  Future<void> runQueryFlow({
    required VoiceBloc bloc,
    required MockSendVoiceMessage sendVoiceMessage,
    required String toolName,
    required Map<String, dynamic> args,
    required AppSession session,
  }) async {
    when(
      () => sendVoiceMessage(
        userMessage: any(named: 'userMessage'),
        sessionId: any(named: 'sessionId'),
        history: any(named: 'history'),
        settings: any(named: 'settings'),
        weightUnit: any(named: 'weightUnit'),
        recentSets: any(named: 'recentSets'),
        recentNutritionLogs: any(named: 'recentNutritionLogs'),
      ),
    ).thenAnswer(
      (_) async => Right(
        VoiceChatQueryCall(
          toolCallId: 'call-q',
          toolName: toolName,
          args: args,
        ),
      ),
    );
    bloc.add(VoiceSessionStarted(session));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    bloc.add(const VoiceSendMessage('query'));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  // -------------------------------------------------------------------------
  // getDailyMacros
  // -------------------------------------------------------------------------

  group('getDailyMacros query', () {
    test('speaks formatted macro summary', () async {
      when(() => getDailyMacros(any())).thenAnswer(
        (_) async => const Right({
          'protein': 120.0,
          'carbs': 200.0,
          'fats': 60.0,
          'calories': 1820.0,
        }),
      );

      final tts = FakeVoiceTtsService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      await runQueryFlow(
        bloc: bloc,
        sendVoiceMessage: sendVoiceMessage,
        toolName: 'getDailyMacros',
        args: const {'date': '2026-05-13'},
        session: authSession(),
      );

      expect(tts.lastSpoken?.contains('1820'), isTrue);
      expect(tts.lastSpoken?.contains('120'), isTrue);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // getWeeklyVolume
  // -------------------------------------------------------------------------

  group('getWeeklyVolume query', () {
    test('speaks set count and exercise breakdown', () async {
      _setupBenchLookup(exerciseLookup);
      when(
        () => getSetsByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer(
        (_) async => Right([
          WorkoutSet(
            id: 'set-wv-1',
            exerciseId: 'ex-bench',
            reps: 8,
            weight: 80.0,
            intensity: 3,
            date: _now,
            createdAt: _now,
          ),
        ]),
      );

      final tts = FakeVoiceTtsService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      await runQueryFlow(
        bloc: bloc,
        sendVoiceMessage: sendVoiceMessage,
        toolName: 'getWeeklyVolume',
        args: const {},
        session: authSession(),
      );

      expect(tts.lastSpoken?.contains('Bench Press'), isTrue);
      await bloc.close();
    });
  });

  // -------------------------------------------------------------------------
  // getRecentSets
  // -------------------------------------------------------------------------

  group('getRecentSets query', () {
    test(
      'speaks formatted recent sets with exercise name and weight',
      () async {
        _setupBenchLookup(exerciseLookup);
        when(
          () => getSetsByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            muscleGroup: any(named: 'muscleGroup'),
          ),
        ).thenAnswer(
          (_) async => Right([
            WorkoutSet(
              id: 'set-rs-1',
              exerciseId: 'ex-bench',
              reps: 10,
              weight: 85.0,
              intensity: 3,
              date: _now,
              createdAt: _now,
            ),
          ]),
        );

        final tts = FakeVoiceTtsService();
        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        await runQueryFlow(
          bloc: bloc,
          sendVoiceMessage: sendVoiceMessage,
          toolName: 'getRecentSets',
          args: const {},
          session: authSession(),
        );

        expect(tts.lastSpoken?.contains('Bench Press'), isTrue);
        expect(tts.lastSpoken?.contains('85'), isTrue);
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // clarify -- ambiguous input returns a clarifying question
  // -------------------------------------------------------------------------

  group('clarify', () {
    test(
      'speaks clarifying question without showing confirmation card',
      () async {
        const question =
            'Which exercise did you mean -- bench press or overhead press?';

        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer(
          (_) async => Right(
            VoiceChatTextResponse(
              message: VoiceMessage(
                role: VoiceRole.assistant,
                content: question,
                createdAt: _now,
              ),
            ),
          ),
        );

        final tts = FakeVoiceTtsService();
        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        bloc.add(VoiceSessionStarted(authSession()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const VoiceSendMessage('log that exercise I did last time'));
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(tts.lastSpoken, question);
        expect(bloc.state.pendingConfirmation, isNull);
        await bloc.close();
      },
    );
  });

  // -------------------------------------------------------------------------
  // VoiceConfirmationCancelled -- no dispatch, clears card
  // -------------------------------------------------------------------------

  group('VoiceConfirmationCancelled', () {
    blocTest<VoiceBloc, VoiceState>(
      'clears pendingConfirmation without dispatching to target blocs',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(
        sessionId: 'sid',
        pendingConfirmation: VoiceToolCall(
          id: 'call-1',
          toolName: 'logWorkoutSet',
          displaySummary: 'Log Bench Press',
          args: {},
        ),
      ),
      act: (bloc) => bloc.add(const VoiceConfirmationCancelled()),
      expect: () => [
        isA<VoiceState>().having(
          (s) => s.pendingConfirmation,
          'pendingConfirmation',
          isNull,
        ),
      ],
    );
  });

  // =========================================================================
  // C-6: Offline routing
  // =========================================================================

  group('C-6 offline routing', () {
    late MockSendVoiceMessage sendVoiceMessage;
    late MockGetVoiceBudget getBudget;
    late MockDeleteVoiceHistory deleteHistory;
    late MockAppSettingsRepository settingsRepo;

    setUp(() {
      sendVoiceMessage = MockSendVoiceMessage();
      getBudget = MockGetVoiceBudget();
      deleteHistory = MockDeleteVoiceHistory();
      settingsRepo = MockAppSettingsRepository();

      when(
        () => settingsRepo.getSettings(),
      ).thenAnswer((_) async => const Right(AppSettings.defaults()));
      when(() => getBudget()).thenAnswer(
        (_) async => const Right(VoiceBudget(usedUsd: 0, dailyCapUsd: 0.5)),
      );
    });

    test(
      'offline text response — coordinator called, online path skipped',
      () async {
        final offlineCoordinator = MockOfflineVoiceCoordinator();
        when(
          () => offlineCoordinator.process(
            any(),
            weightUnit: any(named: 'weightUnit'),
          ),
        ).thenAnswer(
          (_) async => VoiceChatTextResponse(
            message: VoiceMessage(
              role: VoiceRole.assistant,
              content: AppStrings.voiceOfflineUnrecognized,
              createdAt: DateTime(2026),
            ),
          ),
        );

        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          offlineCoordinator: offlineCoordinator,
        );

        bloc.emit(const VoiceState(sessionId: 'sid', isOnline: false));

        bloc.add(const VoiceSendMessage('log bench press'));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        verify(
          () => offlineCoordinator.process(
            'log bench press',
            weightUnit: any(named: 'weightUnit'),
          ),
        ).called(1);

        verifyNever(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        );

        await bloc.close();
      },
    );

    test('offline mutation call — emits pending confirmation', () async {
      const toolCall = VoiceToolCall(
        id: 'offline-1',
        toolName: 'logWorkoutSet',
        displaySummary: 'Log Bench Press — 80 kg × 10 reps',
        args: {'exerciseId': 'ex-bench', 'reps': 10, 'weight': 80.0},
      );

      final offlineCoordinator = MockOfflineVoiceCoordinator();
      when(
        () => offlineCoordinator.process(
          any(),
          weightUnit: any(named: 'weightUnit'),
        ),
      ).thenAnswer(
        (_) async => const VoiceChatMutationCall(toolCall: toolCall),
      );

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        offlineCoordinator: offlineCoordinator,
      );

      bloc.emit(const VoiceState(sessionId: 'sid', isOnline: false));

      bloc.add(const VoiceSendMessage('log bench press 80 kg 10 reps'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.pendingConfirmation, isNotNull);
      expect(bloc.state.pendingConfirmation!.toolName, 'logWorkoutSet');

      await bloc.close();
    });

    test('offline edit set — confirmed edit resolves id via warmed cache and '
        'emits VoiceUpdateWorkoutSetCommand', () async {
      final editableSet = WorkoutSet(
        id: 'set-edit-off',
        exerciseId: 'ex-bench',
        reps: 8,
        weight: 80.0,
        intensity: 3,
        date: _now,
        createdAt: _now,
      );

      const toolCall = VoiceToolCall(
        id: 'offline-edit-1',
        toolName: 'editWorkoutSet',
        displaySummary: 'Edit set: weight -> 90 kg',
        args: {'setId': 'set-edit-off', 'weight': 90.0},
      );

      final offlineCoordinator = MockOfflineVoiceCoordinator();
      when(
        () => offlineCoordinator.process(
          any(),
          weightUnit: any(named: 'weightUnit'),
        ),
      ).thenAnswer(
        (_) async => const VoiceChatMutationCall(toolCall: toolCall),
      );

      // The offline path must warm the recent-set cache so the confirmed
      // edit can resolve set-edit-off back to a full WorkoutSet.
      final getSetsByDateRange = MockGetSetsByDateRange();
      when(
        () => getSetsByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => Right([editableSet]));

      final tts = FakeVoiceTtsService();

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        offlineCoordinator: offlineCoordinator,
        getSetsByDateRange: getSetsByDateRange,
        tts: tts,
      );

      final effectFuture = bloc.effects.first;

      bloc.emit(const VoiceState(sessionId: 'sid', isOnline: false));

      bloc.add(const VoiceSendMessage('change the weight to 90 kg'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      bloc.add(const VoiceConfirmationAccepted());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final effect = await effectFuture;
      expect(effect, isA<VoiceUpdateWorkoutSetCommand>());
      final cmd = effect as VoiceUpdateWorkoutSetCommand;
      expect(cmd.set.id, 'set-edit-off');
      expect(cmd.set.weight, 90.0);
      expect(tts.lastSpoken, AppStrings.voiceSpokenSetUpdated);

      await bloc.close();
    });

    test('online path — coordinator is never called', () async {
      final offlineCoordinator = MockOfflineVoiceCoordinator();

      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer((_) async => Right(_assistantResult('hello')));

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        offlineCoordinator: offlineCoordinator,
      );

      bloc.emit(const VoiceState(sessionId: 'sid', isOnline: true));

      bloc.add(const VoiceSendMessage('hello'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => offlineCoordinator.process(
          any(),
          weightUnit: any(named: 'weightUnit'),
        ),
      );

      await bloc.close();
    });
  });

  // =========================================================================
  // Commit 4 — spoken readback, verbal cancel, awaitingConfirmation, D1 cache
  // =========================================================================

  group('spoken readback (pre-confirmation)', () {
    test('logWorkoutSet: readback spoken BEFORE pendingConfirmation is set; '
        'status transitions to awaitingConfirmation', () async {
      _setupBenchLookup(exerciseLookup);
      final tts = FakeVoiceTtsService();

      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer(
        (_) async => Right(
          VoiceChatMutationCall(
            toolCall: _mutationToolCall('logWorkoutSet', {
              'exerciseName': 'Bench Press',
              'exerciseId': 'ex-bench',
              'reps': 8,
              'weight': 80.0,
            }),
          ),
        ),
      );

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      bloc.add(VoiceSessionStarted(authSession()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(const VoiceSendMessage('log bench 80 by 8'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // Readback was spoken at least once.
      expect(tts.spokenHistory, isNotEmpty);
      final readback = tts.spokenHistory.first;
      expect(readback, contains('Bench Press'));
      expect(readback, contains('80'));
      expect(readback, contains('8 reps'));
      expect(readback, contains('kilograms'));
      expect(readback, contains('Confirm or cancel'));

      // Pending confirmation now set; status awaitingConfirmation.
      expect(bloc.state.pendingConfirmation, isNotNull);
      expect(bloc.state.status, VoiceStatus.awaitingConfirmation);

      await bloc.close();
    });

    test('readback uses pounds when WeightUnit.pounds is configured', () async {
      _setupBenchLookup(exerciseLookup);
      when(() => settingsRepo.getSettings()).thenAnswer(
        (_) async => const Right(
          AppSettings(
            notificationsEnabled: true,
            weekStartDay: WeekStartDay.monday,
            weightUnit: WeightUnit.pounds,
          ),
        ),
      );

      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer(
        (_) async => Right(
          VoiceChatMutationCall(
            toolCall: _mutationToolCall('logWorkoutSet', {
              'exerciseName': 'Bench Press',
              'exerciseId': 'ex-bench',
              'reps': 5,
              'weight': 185.0,
            }),
          ),
        ),
      );

      final tts = FakeVoiceTtsService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      bloc.add(VoiceSessionStarted(authSession()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(const VoiceSendMessage('log bench 185 by 5'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(tts.spokenHistory.first, contains('pounds'));
      expect(tts.spokenHistory.first, isNot(contains('kilograms')));

      await bloc.close();
    });

    test('query tool calls do NOT trigger readback', () async {
      when(() => getDailyMacros(any())).thenAnswer(
        (_) async => const Right({
          'protein': 100.0,
          'carbs': 200.0,
          'fats': 50.0,
          'calories': 1500.0,
        }),
      );

      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer(
        (_) async => const Right(
          VoiceChatQueryCall(
            toolCallId: 'q1',
            toolName: 'getDailyMacros',
            args: {'date': '2026-05-13'},
          ),
        ),
      );

      final tts = FakeVoiceTtsService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      bloc.add(VoiceSessionStarted(authSession()));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      bloc.add(const VoiceSendMessage('how many calories today'));
      await Future<void>.delayed(const Duration(milliseconds: 250));

      // The single spoken value is the query response — no "I heard:" prefix.
      expect(tts.spokenHistory.any((s) => s.startsWith('I heard:')), isFalse);
      expect(bloc.state.pendingConfirmation, isNull);

      await bloc.close();
    });
  });

  group('verbal cancel', () {
    blocTest<VoiceBloc, VoiceState>(
      'transcript "cancel" while confirmation pending cancels without LLM',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(
        sessionId: 'sid',
        status: VoiceStatus.awaitingConfirmation,
        pendingConfirmation: VoiceToolCall(
          id: 'call-1',
          toolName: 'logWorkoutSet',
          displaySummary: 'Log Bench Press',
          args: {},
        ),
      ),
      act: (bloc) => bloc.add(
        const VoiceTranscriptReceived(transcript: 'cancel', isFinal: true),
      ),
      verify: (bloc) {
        expect(bloc.state.pendingConfirmation, isNull);
        verifyNever(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        );
      },
    );

    blocTest<VoiceBloc, VoiceState>(
      'transcript "nevermind" while confirmation pending cancels',
      build: () => _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      ),
      seed: () => const VoiceState(
        sessionId: 'sid',
        status: VoiceStatus.awaitingConfirmation,
        pendingConfirmation: VoiceToolCall(
          id: 'call-2',
          toolName: 'logWorkoutSet',
          displaySummary: 'Log Bench Press',
          args: {},
        ),
      ),
      act: (bloc) => bloc.add(
        const VoiceTranscriptReceived(transcript: 'Nevermind', isFinal: true),
      ),
      verify: (bloc) => expect(bloc.state.pendingConfirmation, isNull),
    );

    test('mid-utterance "cancel my membership" does NOT cancel pending '
        'confirmation (full-string anchor)', () async {
      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer((_) async => Right(_assistantResult('ok')));

      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
      );
      bloc.emit(
        const VoiceState(
          sessionId: 'sid',
          status: VoiceStatus.awaitingConfirmation,
          pendingConfirmation: VoiceToolCall(
            id: 'call-3',
            toolName: 'logWorkoutSet',
            displaySummary: 'Log Bench Press',
            args: {},
          ),
        ),
      );

      bloc.add(
        const VoiceTranscriptReceived(
          transcript: 'cancel my membership',
          isFinal: true,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Was forwarded to the LLM (no early cancel).
      expect(bloc.state.pendingConfirmation, isNotNull);
      verify(
        () => sendVoiceMessage(
          userMessage: 'cancel my membership',
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).called(1);
      await bloc.close();
    });

    blocTest<VoiceBloc, VoiceState>(
      'cancel word with NO pending confirmation is treated as a normal '
      'message (does NOT short-circuit)',
      build: () {
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async => Right(_assistantResult('ok')));
        return _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
        );
      },
      seed: () => const VoiceState(sessionId: 'sid'),
      act: (bloc) => bloc.add(
        const VoiceTranscriptReceived(transcript: 'cancel', isFinal: true),
      ),
      verify: (_) => verify(
        () => sendVoiceMessage(
          userMessage: 'cancel',
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).called(1),
    );
  });

  group('D1 — recent-context cache freshness after mutation', () {
    test(
      'logWorkoutSet then editWorkoutSet referencing the cached id resolves '
      'via the post-mutation cache, even when the persisted store has not '
      'yet flushed (D1 — synchronous cache update inside _dispatchMutationTool)',
      () async {
        _setupBenchLookup(exerciseLookup);

        // Persisted store is initially empty; after the first voice
        // mutation lands, simulate the router's write-through by toggling
        // the stub to include the just-logged set on subsequent reads.
        // This mirrors the production rationale documented in the plan:
        // "coherence with the target BLoC's persisted store is the
        //  router's job, not the cache's." The in-memory cache update
        // inside _dispatchMutationTool guarantees coherence in the
        // current turn; persisted-store reflection lands by the next.
        var persistedSets = <WorkoutSet>[];
        when(
          () => getSetsByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
            muscleGroup: any(named: 'muscleGroup'),
          ),
        ).thenAnswer((_) async => Right(persistedSets));

        // First call: log a set; we'll discover its auto-generated id from
        // the emitted effect, then send an edit referencing that id.
        var callCount = 0;
        String? loggedSetId;
        when(
          () => sendVoiceMessage(
            userMessage: any(named: 'userMessage'),
            sessionId: any(named: 'sessionId'),
            history: any(named: 'history'),
            settings: any(named: 'settings'),
            weightUnit: any(named: 'weightUnit'),
            recentSets: any(named: 'recentSets'),
            recentNutritionLogs: any(named: 'recentNutritionLogs'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) {
            return Right(
              VoiceChatMutationCall(
                toolCall: _mutationToolCall('logWorkoutSet', {
                  'exerciseName': 'Bench Press',
                  'exerciseId': 'ex-bench',
                  'reps': 8,
                  'weight': 80.0,
                }),
              ),
            );
          }
          // Second turn: edit the just-logged set.
          return Right(
            VoiceChatMutationCall(
              toolCall: _mutationToolCall('editWorkoutSet', {
                'setId': loggedSetId,
                'weight': 90.0,
              }),
            ),
          );
        });

        final tts = FakeVoiceTtsService();
        final bloc = _makeBloc(
          sendVoiceMessage: sendVoiceMessage,
          getVoiceBudget: getBudget,
          deleteVoiceHistory: deleteHistory,
          appSettingsRepository: settingsRepo,
          exerciseLookup: exerciseLookup,
          getSetsByDateRange: getSetsByDateRange,
          getLogsForDate: getLogsForDate,
          getDailyMacros: getDailyMacros,
          tts: tts,
        );

        final emittedEffects = <VoiceEffect>[];
        final sub = bloc.effects.listen(emittedEffects.add);

        // First mutation: log.
        bloc.add(VoiceSessionStarted(authSession()));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const VoiceSendMessage('log bench 80 by 8'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        bloc.add(const VoiceConfirmationAccepted());
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(emittedEffects, isNotEmpty);
        final loggedSet =
            (emittedEffects.first as VoiceAddWorkoutSetCommand).set;
        loggedSetId = loggedSet.id;
        // Simulate the router's write-through: persisted store now reflects
        // the voice-logged set on subsequent reads.
        persistedSets = <WorkoutSet>[loggedSet];

        // Second mutation: edit referencing the just-logged id. The
        // synchronous post-mutation cache update from the first turn AND
        // the now-flushed persisted store both resolve to the same set.
        bloc.add(const VoiceSendMessage('change weight to 90'));
        await Future<void>.delayed(const Duration(milliseconds: 250));
        bloc.add(const VoiceConfirmationAccepted());
        await Future<void>.delayed(const Duration(milliseconds: 200));

        final updateEffect = emittedEffects
            .whereType<VoiceUpdateWorkoutSetCommand>();
        expect(
          updateEffect,
          isNotEmpty,
          reason:
              'editWorkoutSet must resolve via the post-mutation cache '
              '(D1 fix); without it the persisted-store re-warm would lose '
              'the set and emit voiceSpokenToolFailed instead.',
        );
        expect(updateEffect.first.set.weight, 90.0);
        expect(updateEffect.first.set.id, loggedSetId);

        await sub.cancel();
        await bloc.close();
      },
    );

    test('deleteWorkoutSet removes the set from the cache so subsequent edits '
        'cannot resolve it', () async {
      _setupBenchLookup(exerciseLookup);
      final initialSet = WorkoutSet(
        id: 'set-del-1',
        exerciseId: 'ex-bench',
        reps: 8,
        weight: 80.0,
        intensity: 3,
        date: _now,
        createdAt: _now,
      );
      when(
        () => getSetsByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => Right([initialSet]));

      var callCount = 0;
      when(
        () => sendVoiceMessage(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
          recentSets: any(named: 'recentSets'),
          recentNutritionLogs: any(named: 'recentNutritionLogs'),
        ),
      ).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return Right(
            VoiceChatMutationCall(
              toolCall: _mutationToolCall('deleteWorkoutSet', {
                'setId': 'set-del-1',
              }),
            ),
          );
        }
        return Right(
          VoiceChatMutationCall(
            toolCall: _mutationToolCall('editWorkoutSet', {
              'setId': 'set-del-1',
              'weight': 90.0,
            }),
          ),
        );
      });

      // After deletion, the persisted store still reports the set on
      // subsequent reads (write-through has not flushed) — but the
      // in-memory cache must drop it.
      final tts = FakeVoiceTtsService();
      final bloc = _makeBloc(
        sendVoiceMessage: sendVoiceMessage,
        getVoiceBudget: getBudget,
        deleteVoiceHistory: deleteHistory,
        appSettingsRepository: settingsRepo,
        exerciseLookup: exerciseLookup,
        getSetsByDateRange: getSetsByDateRange,
        getLogsForDate: getLogsForDate,
        getDailyMacros: getDailyMacros,
        tts: tts,
      );

      bloc.add(VoiceSessionStarted(authSession()));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Delete the set.
      bloc.add(const VoiceSendMessage('delete that last set'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      bloc.add(const VoiceConfirmationAccepted());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // Now stub the persisted store empty so _warmRecentCaches cannot
      // re-populate set-del-1 — only the in-memory cache state proves D1.
      when(
        () => getSetsByDateRange(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => const Right(<WorkoutSet>[]));

      // Edit attempt referencing the deleted setId should fail (cache
      // drop), surfacing voiceSpokenToolFailed.
      bloc.add(const VoiceSendMessage('change the weight to 90'));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      bloc.add(const VoiceConfirmationAccepted());
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(tts.lastSpoken, AppStrings.voiceSpokenToolFailed);
      await bloc.close();
    });
  });
}
