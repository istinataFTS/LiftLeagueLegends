import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/bloc/bloc_effects_mixin.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/constants/voice_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/network_status_service.dart';
import '../../../core/platform/wakelock_service.dart';
import '../../../domain/entities/app_session.dart';
import '../../../domain/entities/app_settings.dart' show WeightUnit;
import '../../../domain/entities/nutrition_log.dart';
import '../../../domain/entities/voice_budget.dart';
import '../../../domain/entities/voice_chat_context.dart';
import '../../../domain/entities/voice_chat_result.dart';
import '../../../domain/entities/voice_message.dart';
import '../../../domain/entities/voice_settings.dart';
import '../../../domain/entities/voice_tool_call.dart';
import '../../../domain/entities/workout_set.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/services/voice_stt_service.dart';
import '../../../domain/services/voice_tts_service.dart';
import '../../../domain/services/voice_wake_word_service.dart';
import '../../../domain/usecases/nutrition_logs/get_daily_macros.dart';
import '../../../domain/usecases/nutrition_logs/get_logs_for_date.dart';
import '../../../domain/usecases/voice/delete_voice_history.dart';
import '../../../domain/usecases/voice/get_voice_budget.dart';
import '../../../domain/usecases/voice/send_voice_message.dart';
import '../../../domain/usecases/workout_sets/get_sets_by_date_range.dart';
import '../../../domain/usecases/workout_sets/get_weekly_sets.dart';
import '../data/coordinator/offline_voice_coordinator.dart';
import '../data/lookup/exercise_lookup.dart';

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

abstract class VoiceEvent extends Equatable {
  const VoiceEvent();

  @override
  List<Object?> get props => <Object?>[];
}

/// Fired when a voice session begins (user opens the overlay or wakes
/// the bot). Carries the current auth session so guests can be
/// rejected before any network call.
class VoiceSessionStarted extends VoiceEvent {
  const VoiceSessionStarted(this.session);

  final AppSession session;

  @override
  List<Object?> get props => <Object?>[session];
}

/// Starts an STT session. Pure event — the bloc subscribes to the
/// stream emitted by the [VoiceSttService] and forwards the final
/// transcript as a [VoiceSendMessage].
class VoiceListenRequested extends VoiceEvent {
  const VoiceListenRequested();
}

/// Stops an in-progress STT session gracefully (the final partial
/// becomes the final transcript).
class VoiceListenStopRequested extends VoiceEvent {
  const VoiceListenStopRequested();
}

/// Internal: emitted by the bloc itself when STT yields a result.
/// Public so widget tests can drive the bloc directly without
/// plumbing a real STT engine.
class VoiceTranscriptReceived extends VoiceEvent {
  const VoiceTranscriptReceived({
    required this.transcript,
    required this.isFinal,
  });

  final String transcript;
  final bool isFinal;

  @override
  List<Object?> get props => <Object?>[transcript, isFinal];
}

/// Internal: emitted by the bloc when STT errors out.
class VoiceTranscriptFailed extends VoiceEvent {
  const VoiceTranscriptFailed(this.kind, [this.message]);

  final VoiceSttErrorKind kind;
  final String? message;

  @override
  List<Object?> get props => <Object?>[kind, message];
}

class VoiceSendMessage extends VoiceEvent {
  const VoiceSendMessage(this.text);

  final String text;

  @override
  List<Object?> get props => <Object?>[text];
}

class VoiceBudgetRefreshRequested extends VoiceEvent {
  const VoiceBudgetRefreshRequested();
}

class VoiceHistoryDeleteRequested extends VoiceEvent {
  const VoiceHistoryDeleteRequested();
}

class VoiceConversationCleared extends VoiceEvent {
  const VoiceConversationCleared();
}

// ---------------------------------------------------------------------------
// C-3 events — confirmation card & workout mode
// ---------------------------------------------------------------------------

/// C-5 fires this after parsing a tool call from the LLM response.
/// Passing [null] clears an in-progress confirmation card.
class VoicePendingConfirmationSet extends VoiceEvent {
  const VoicePendingConfirmationSet(this.toolCall);

  final VoiceToolCall? toolCall;

  @override
  List<Object?> get props => <Object?>[toolCall];
}

/// User tapped "Yes, do it" on the confirmation card.
class VoiceConfirmationAccepted extends VoiceEvent {
  const VoiceConfirmationAccepted();
}

/// User tapped "Cancel" on the confirmation card.
class VoiceConfirmationCancelled extends VoiceEvent {
  const VoiceConfirmationCancelled();
}

/// User toggled Workout Mode inside the overlay.
class VoiceWorkoutModeToggled extends VoiceEvent {
  const VoiceWorkoutModeToggled({required this.active});

  final bool active;

  @override
  List<Object?> get props => <Object?>[active];
}

// ---------------------------------------------------------------------------
// C-4 events — connectivity
// ---------------------------------------------------------------------------

/// Fired by [VoiceOverlayPage] when device connectivity changes.
/// The bloc announces offline status once per session via TTS and
/// tracks [VoiceState.isOnline] for downstream UI.
class VoiceConnectivityChanged extends VoiceEvent {
  const VoiceConnectivityChanged({required this.isOnline});

  final bool isOnline;

  @override
  List<Object?> get props => <Object?>[isOnline];
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

enum VoiceStatus { idle, listening, transcribing, thinking, speaking, error }

class VoiceState extends Equatable {
  const VoiceState({
    this.status = VoiceStatus.idle,
    this.messages = const <VoiceMessage>[],
    this.budget,
    this.sessionId,
    this.isGuest = false,
    this.errorMessage,
    this.liveTranscript = '',
    this.pendingConfirmation,
    this.isWorkoutModeActive = false,
    this.isOnline = true,
    this.hasAnnouncedOfflineThisSession = false,
  });

  /// Top-level state machine. Maps directly to overlay states in C-3.
  final VoiceStatus status;

  /// Conversation so far this session (user + assistant turns).
  final List<VoiceMessage> messages;

  /// Latest known budget snapshot — drives the budget meter.
  final VoiceBudget? budget;

  /// Server-side session UUID. Null until [VoiceSessionStarted] fires.
  final String? sessionId;

  /// True for unauthenticated sessions — voice features are gated
  /// behind sign-in in v1.
  final bool isGuest;

  /// Set when [status] == [VoiceStatus.error]. Already mapped to a
  /// user-facing string by the bloc; the UI never has to translate.
  final String? errorMessage;

  /// Partial transcript displayed live in the overlay while STT is
  /// running. Cleared on transition to [VoiceStatus.thinking].
  final String liveTranscript;

  /// Non-null when the LLM returned a tool call awaiting confirmation.
  /// C-3 renders [VoiceConfirmationCard] while this is set.
  final VoiceToolCall? pendingConfirmation;

  /// True when the user has activated Workout Mode in the overlay.
  /// The wakelock is applied via [WakelockService]; this flag drives
  /// the banner and the toggle switch.
  final bool isWorkoutModeActive;

  /// Whether the device has network access. Updated by
  /// [VoiceConnectivityChanged] events dispatched from [VoiceOverlayPage].
  final bool isOnline;

  /// Prevents repeating the offline announcement every command — the bot
  /// announces offline status once per session and then stays quiet about it.
  final bool hasAnnouncedOfflineThisSession;

  bool get isBusy =>
      status == VoiceStatus.listening ||
      status == VoiceStatus.transcribing ||
      status == VoiceStatus.thinking ||
      status == VoiceStatus.speaking;

  VoiceState copyWith({
    VoiceStatus? status,
    List<VoiceMessage>? messages,
    VoiceBudget? budget,
    String? sessionId,
    bool? isGuest,
    String? errorMessage,
    String? liveTranscript,
    VoiceToolCall? pendingConfirmation,
    bool? isWorkoutModeActive,
    bool? isOnline,
    bool? hasAnnouncedOfflineThisSession,
    bool clearError = false,
    bool clearTranscript = false,
    bool clearPendingConfirmation = false,
  }) {
    return VoiceState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      budget: budget ?? this.budget,
      sessionId: sessionId ?? this.sessionId,
      isGuest: isGuest ?? this.isGuest,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      liveTranscript: clearTranscript
          ? ''
          : liveTranscript ?? this.liveTranscript,
      pendingConfirmation: clearPendingConfirmation
          ? null
          : pendingConfirmation ?? this.pendingConfirmation,
      isWorkoutModeActive: isWorkoutModeActive ?? this.isWorkoutModeActive,
      isOnline: isOnline ?? this.isOnline,
      hasAnnouncedOfflineThisSession:
          hasAnnouncedOfflineThisSession ?? this.hasAnnouncedOfflineThisSession,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    messages,
    budget,
    sessionId,
    isGuest,
    errorMessage,
    liveTranscript,
    pendingConfirmation,
    isWorkoutModeActive,
    isOnline,
    hasAnnouncedOfflineThisSession,
  ];
}

// ---------------------------------------------------------------------------
// Effects
// ---------------------------------------------------------------------------

/// Base type for all one-shot signals emitted by [VoiceBloc].
///
/// Voice never holds direct references to target BLoCs. Instead it emits
/// effects; [VoiceCommandRouter] (a widget child of the auth-session shell)
/// listens to [VoiceBloc.effects] and dispatches each command via
/// `context.read<X>().add(...)`. The widget tree mediates so all target
/// BLoCs can remain `registerFactory` per convention.
sealed class VoiceEffect {
  const VoiceEffect();
}

/// Family of mutation commands voice issues after a confirmed tool call.
/// Each subclass carries only domain entities or scalar identifiers —
/// never target-feature event objects. This keeps cross-feature imports
/// out of [VoiceBloc] entirely.
sealed class VoiceMutationCommand extends VoiceEffect {
  const VoiceMutationCommand();
}

class VoiceAddWorkoutSetCommand extends VoiceMutationCommand {
  const VoiceAddWorkoutSetCommand(this.set);
  final WorkoutSet set;
}

class VoiceUpdateWorkoutSetCommand extends VoiceMutationCommand {
  const VoiceUpdateWorkoutSetCommand(this.set);
  final WorkoutSet set;
}

class VoiceDeleteWorkoutSetCommand extends VoiceMutationCommand {
  const VoiceDeleteWorkoutSetCommand(this.setId);
  final String setId;
}

class VoiceAddNutritionLogCommand extends VoiceMutationCommand {
  const VoiceAddNutritionLogCommand(this.log);
  final NutritionLog log;
}

class VoiceUpdateNutritionLogCommand extends VoiceMutationCommand {
  const VoiceUpdateNutritionLogCommand(this.log);
  final NutritionLog log;
}

class VoiceDeleteNutritionLogCommand extends VoiceMutationCommand {
  const VoiceDeleteNutritionLogCommand(this.logId);
  final String logId;
}

// ---------------------------------------------------------------------------
// Bloc
// ---------------------------------------------------------------------------

/// Voice-bot state machine.
///
/// **Critical architectural rule:** this bloc does NOT depend on
/// `VoiceRepository` directly. All data access goes through use
/// cases ([SendVoiceMessage], [GetVoiceBudget], [DeleteVoiceHistory])
/// and through device service ports ([VoiceSttService], [VoiceTtsService]).
/// Plugin packages (`speech_to_text`, `flutter_tts`, `porcupine_flutter`,
/// `wakelock_plus`) are never imported here — they live only in their
/// respective service implementations.
///
/// **Mutation dispatch rule (C-5):** tool confirmation emits a
/// [VoiceMutationCommand] effect. [VoiceCommandRouter] (a widget child of
/// the auth-session shell) listens to [effects] and dispatches each command
/// via `context.read<X>().add(...)`. Voice never holds BLoC references.
class VoiceBloc extends Bloc<VoiceEvent, VoiceState>
    with BlocEffectsMixin<VoiceState, VoiceEffect> {
  VoiceBloc({
    required SendVoiceMessage sendVoiceMessage,
    required GetVoiceBudget getVoiceBudget,
    required DeleteVoiceHistory deleteVoiceHistory,
    required VoiceSttService sttService,
    required VoiceTtsService ttsService,
    required AppSettingsRepository appSettingsRepository,
    required VoiceSettings Function() currentVoiceSettings,
    required NetworkStatusService networkStatusService,
    required VoiceWakeWordService wakeWordService,
    required WakelockService wakelockService,
    // C-5: query execution use cases
    required GetSetsByDateRange getSetsByDateRange,
    required GetDailyMacros getDailyMacros,
    required GetWeeklySets getWeeklySets,
    required GetLogsForDate getLogsForDate,
    // C-6: shared lookup helpers
    required ExerciseLookup exerciseLookup,
    // C-6: offline coordinator
    required OfflineVoiceCoordinator offlineCoordinator,
  }) : _sendVoiceMessage = sendVoiceMessage,
       _getVoiceBudget = getVoiceBudget,
       _deleteVoiceHistory = deleteVoiceHistory,
       _stt = sttService,
       _tts = ttsService,
       _appSettingsRepository = appSettingsRepository,
       _currentVoiceSettings = currentVoiceSettings,
       _networkStatusService = networkStatusService,
       _wakeWordService = wakeWordService,
       _wakelock = wakelockService,
       _getSetsByDateRange = getSetsByDateRange,
       _getDailyMacros = getDailyMacros,
       // ignore: unused_field
       _getWeeklySets = getWeeklySets,
       _getLogsForDate = getLogsForDate,
       _exerciseLookup = exerciseLookup,
       _offlineCoordinator = offlineCoordinator,
       super(const VoiceState()) {
    on<VoiceSessionStarted>(_onSessionStarted);
    on<VoiceListenRequested>(_onListenRequested);
    on<VoiceListenStopRequested>(_onListenStopRequested);
    on<VoiceTranscriptReceived>(_onTranscriptReceived);
    on<VoiceTranscriptFailed>(_onTranscriptFailed);
    on<VoiceSendMessage>(_onSendMessage);
    on<VoiceBudgetRefreshRequested>(_onBudgetRefresh);
    on<VoiceHistoryDeleteRequested>(_onHistoryDelete);
    on<VoiceConversationCleared>(_onConversationCleared);
    // C-3 events
    on<VoicePendingConfirmationSet>(_onPendingConfirmationSet);
    on<VoiceConfirmationAccepted>(_onConfirmationAccepted);
    on<VoiceConfirmationCancelled>(_onConfirmationCancelled);
    on<VoiceWorkoutModeToggled>(_onWorkoutModeToggled);
    // C-4 events
    on<VoiceConnectivityChanged>(_onConnectivityChanged);
  }

  static const _uuid = Uuid();

  final SendVoiceMessage _sendVoiceMessage;
  final GetVoiceBudget _getVoiceBudget;
  final DeleteVoiceHistory _deleteVoiceHistory;
  final VoiceSttService _stt;
  final VoiceTtsService _tts;
  final AppSettingsRepository _appSettingsRepository;

  /// Injected as a callback so the bloc reads the *current* settings
  /// at each request, never a stale snapshot captured at construction.
  final VoiceSettings Function() _currentVoiceSettings;

  // Stored for dependency injection ordering / future use. Connectivity
  // event dispatch is handled by VoiceOverlayPage, not the bloc itself.
  // ignore: unused_field
  final NetworkStatusService _networkStatusService;

  // Injected so tests can verify start/stop calls are NOT made by the
  // bloc (the FAB owns lifecycle). The bloc only reads isRunning for
  // potential future "wake-word armed" indicator.
  // ignore: unused_field
  final VoiceWakeWordService _wakeWordService;

  final WakelockService _wakelock;

  // C-5: query execution use cases
  final GetSetsByDateRange _getSetsByDateRange;
  final GetDailyMacros _getDailyMacros;
  // ignore: unused_field
  final GetWeeklySets _getWeeklySets;
  final GetLogsForDate _getLogsForDate;

  // C-6: shared lookup — singleton, cache persists across voice sessions
  final ExerciseLookup _exerciseLookup;

  // C-6: offline coordinator — factory, one per VoiceBloc instance
  final OfflineVoiceCoordinator _offlineCoordinator;

  // C-5: recent-entity caches populated by _buildRecentContext; used for edit/delete lookups
  List<WorkoutSet> _cachedWorkoutSets = <WorkoutSet>[];
  List<NutritionLog> _cachedNutritionLogs = <NutritionLog>[];

  StreamSubscription<VoiceSttResult>? _sttSubscription;

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  void _onSessionStarted(VoiceSessionStarted event, Emitter<VoiceState> emit) {
    final isGuest = !event.session.isAuthenticated;
    final sessionId = isGuest ? null : _uuid.v4();
    // Reset per-session recent-entity caches on new session.
    // ExerciseLookup is a singleton whose cache persists across sessions
    // (the exercise library is static) — it is NOT reset here.
    _cachedWorkoutSets = <WorkoutSet>[];
    _cachedNutritionLogs = <NutritionLog>[];
    emit(
      state.copyWith(
        isGuest: isGuest,
        sessionId: sessionId,
        messages: const <VoiceMessage>[],
        status: VoiceStatus.idle,
        clearError: true,
        clearTranscript: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STT (device-native)
  // ---------------------------------------------------------------------------

  Future<void> _onListenRequested(
    VoiceListenRequested event,
    Emitter<VoiceState> emit,
  ) async {
    if (_rejectGuest(emit) || _rejectBusy()) return;
    _ensureSessionId(emit);

    try {
      await _stt.initialize();
    } catch (e, st) {
      AppLogger.warning(
        'VoiceBloc: STT initialize failed',
        error: e,
        stackTrace: st,
      );
      emit(
        state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Voice recognition is not available on this device.',
        ),
      );
      return;
    }

    if (!_stt.isAvailable) {
      emit(
        state.copyWith(
          status: VoiceStatus.error,
          errorMessage: 'Voice recognition is not available on this device.',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: VoiceStatus.listening,
        clearError: true,
        clearTranscript: true,
      ),
    );

    await _sttSubscription?.cancel();
    _sttSubscription = _stt
        .listen(localeId: 'en-US')
        .listen(
          (result) => add(
            VoiceTranscriptReceived(
              transcript: result.transcript,
              isFinal: result.isFinal,
            ),
          ),
          onError: (Object e) {
            if (e is VoiceSttException) {
              add(VoiceTranscriptFailed(e.kind, e.message));
            } else {
              add(
                VoiceTranscriptFailed(VoiceSttErrorKind.unknown, e.toString()),
              );
            }
          },
          cancelOnError: true,
        );
  }

  Future<void> _onListenStopRequested(
    VoiceListenStopRequested event,
    Emitter<VoiceState> emit,
  ) async {
    await _stt.stop();
  }

  void _onTranscriptReceived(
    VoiceTranscriptReceived event,
    Emitter<VoiceState> emit,
  ) {
    // Partial result — show live in the overlay but don't transition state.
    if (!event.isFinal) {
      emit(state.copyWith(liveTranscript: event.transcript));
      return;
    }

    // Final result. Cancel subscription defensively — the plugin may keep
    // the stream open for a heartbeat after emitting the final result.
    _sttSubscription?.cancel();
    _sttSubscription = null;

    final text = event.transcript.trim();
    if (text.isEmpty) {
      emit(state.copyWith(status: VoiceStatus.idle, clearTranscript: true));
      return;
    }

    emit(
      state.copyWith(status: VoiceStatus.transcribing, liveTranscript: text),
    );
    add(VoiceSendMessage(text));
  }

  void _onTranscriptFailed(
    VoiceTranscriptFailed event,
    Emitter<VoiceState> emit,
  ) {
    _sttSubscription?.cancel();
    _sttSubscription = null;

    final uiMessage = _sttErrorMessage(event.kind);
    final spokenMessage = _sttSpokenMessage(event.kind);

    emit(
      state.copyWith(
        status: VoiceStatus.error,
        errorMessage: uiMessage,
        clearTranscript: true,
      ),
    );

    // Speak asynchronously — do not await, do not block the emitter.
    if (spokenMessage != null) {
      unawaited(_speak(spokenMessage));
    }
  }

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  Future<void> _onSendMessage(
    VoiceSendMessage event,
    Emitter<VoiceState> emit,
  ) async {
    if (_rejectGuest(emit)) return;
    final sid = _ensureSessionId(emit);

    final userMsg = VoiceMessage(
      role: VoiceRole.user,
      content: event.text,
      createdAt: DateTime.now(),
    );

    final updatedMessages = <VoiceMessage>[...state.messages, userMsg];
    emit(
      state.copyWith(
        status: VoiceStatus.thinking,
        messages: updatedMessages,
        clearError: true,
        clearTranscript: true,
      ),
    );

    final weightUnit = await _readWeightUnit();

    // C-6: Offline fallback — bypass the network entirely.
    if (!state.isOnline) {
      // Warm the recent-entity caches so a confirmed offline edit/delete can
      // resolve the set/log id back to a full entity. The online path does
      // this via _buildRecentContext(); offline must do it explicitly since
      // it skips that call. The underlying use cases read local sqflite, so
      // this works without a network connection.
      await _warmRecentCaches();
      final offlineResult = await _offlineCoordinator.process(
        event.text,
        weightUnit: weightUnit,
      );
      await _dispatchVoiceResult(offlineResult, updatedMessages, emit,
          refreshBudget: false);
      return;
    }

    // Build extended context (recent sets + nutrition logs for edit/delete IDs)
    final (recentSets, recentLogs) = await _buildRecentContext();

    final history = _trimHistory(updatedMessages);
    final chatResult = await _sendVoiceMessage(
      userMessage: event.text,
      sessionId: sid,
      history: history,
      settings: _currentVoiceSettings(),
      weightUnit: weightUnit,
      recentSets: recentSets,
      recentNutritionLogs: recentLogs,
    );

    await chatResult.fold(
      (failure) async {
        final spokenMessage = _spokenMessageFor(failure);
        emit(
          state.copyWith(
            status: VoiceStatus.error,
            errorMessage: _messageFor(failure),
          ),
        );
        if (spokenMessage != null) {
          unawaited(_speak(spokenMessage));
        }
      },
      (result) async =>
          _dispatchVoiceResult(result, updatedMessages, emit),
    );
  }

  Future<void> _dispatchVoiceResult(
    VoiceChatResult result,
    List<VoiceMessage> updatedMessages,
    Emitter<VoiceState> emit, {
    bool refreshBudget = true,
  }) async {
    switch (result) {
      case VoiceChatTextResponse(:final message):
        final withReply = <VoiceMessage>[...updatedMessages, message];
        emit(
          state.copyWith(status: VoiceStatus.speaking, messages: withReply),
        );
        await _speak(message.content);
        emit(state.copyWith(status: VoiceStatus.idle));
        if (refreshBudget) _refreshBudget();

      case VoiceChatMutationCall(:final toolCall):
        // Don't add to messages yet; the confirmation card drives the next step.
        emit(
          state.copyWith(
            status: VoiceStatus.idle,
            messages: updatedMessages,
          ),
        );
        add(VoicePendingConfirmationSet(toolCall));

      case VoiceChatQueryCall(:final toolName, :final args):
        final spoken = await _executeQueryTool(toolName, args);
        final assistantMsg = VoiceMessage(
          role: VoiceRole.assistant,
          content: spoken,
          createdAt: DateTime.now(),
        );
        final withReply = <VoiceMessage>[...updatedMessages, assistantMsg];
        emit(
          state.copyWith(status: VoiceStatus.speaking, messages: withReply),
        );
        await _speak(spoken);
        emit(state.copyWith(status: VoiceStatus.idle));
        if (refreshBudget) _refreshBudget();
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    final settings = _currentVoiceSettings();
    // Idempotent — no-op if already initialised.
    await _tts.initialize(
      volume: settings.ttsVolume,
      speechRate: settings.ttsSpeechRate,
    );
    // Apply current volume/rate before each speak so mid-session settings
    // changes are honoured without restarting the TTS engine.
    await _tts.setVolume(settings.ttsVolume);
    await _tts.setSpeechRate(settings.ttsSpeechRate);
    await _tts.speak(text);
  }

  /// Trims `messages` to the last [VoiceConstants.maxHistoryTurns]
  /// entries. Bounded server-side too, but trimming on the client
  /// avoids sending oversize payloads.
  List<VoiceMessage> _trimHistory(List<VoiceMessage> messages) {
    if (messages.length <= VoiceConstants.maxHistoryTurns) return messages;
    return messages.sublist(messages.length - VoiceConstants.maxHistoryTurns);
  }

  Future<WeightUnit> _readWeightUnit() async {
    final result = await _appSettingsRepository.getSettings();
    return result.fold(
      // If settings can't be read, fall back to the safest default
      // (kg) rather than failing the chat call.
      (_) => WeightUnit.kilograms,
      (settings) => settings.weightUnit,
    );
  }

  // ---------------------------------------------------------------------------
  // C-5: Recent context builder
  // ---------------------------------------------------------------------------

  /// Populates [_cachedWorkoutSets] / [_cachedNutritionLogs] (last 5 sets from
  /// the past 7 days, last 5 logs from today) and warms the exercise lookup.
  ///
  /// Shared by the online context builder and the offline path so a confirmed
  /// edit/delete can always resolve an id back to a full entity. Errors are
  /// swallowed — an empty cache is acceptable; edit/delete simply reports it
  /// could not find the row rather than crashing.
  Future<void> _warmRecentCaches() async {
    try {
      // Warm the exercise lookup cache lazily (no-op if already populated).
      await _exerciseLookup.refreshIfEmpty();

      // Datasource orders sets newest-first; take(5) = 5 most recent.
      final setsResult = await _getSetsByDateRange(
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now(),
      );
      final rawSets = setsResult.fold((_) => <WorkoutSet>[], (s) => s);
      _cachedWorkoutSets = rawSets.take(5).toList();

      final logsResult = await _getLogsForDate(DateTime.now());
      final rawLogs = logsResult.fold((_) => <NutritionLog>[], (l) => l);
      _cachedNutritionLogs = rawLogs.take(5).toList();
    } catch (e, st) {
      AppLogger.warning(
        'VoiceBloc: _warmRecentCaches failed',
        error: e,
        stackTrace: st,
      );
      _cachedWorkoutSets = <WorkoutSet>[];
      _cachedNutritionLogs = <NutritionLog>[];
    }
  }

  /// Builds the LLM recent-entity context (online path) from the warmed
  /// caches. Errors are swallowed — empty context is acceptable; the LLM
  /// simply won't propose edit/delete for unknown rows.
  Future<(List<RecentSetContext>, List<RecentNutritionLogContext>)>
  _buildRecentContext() async {
    await _warmRecentCaches();

    final recentSets = _cachedWorkoutSets
        .map(
          (s) => RecentSetContext(
            setId: s.id,
            exerciseName: _exerciseLookup.nameForId(s.exerciseId),
            weight: s.weight,
            reps: s.reps,
            intensity: s.intensity,
            date: s.date,
          ),
        )
        .toList();

    final recentLogs = _cachedNutritionLogs
        .map(
          (l) => RecentNutritionLogContext(
            logId: l.id,
            mealName: l.mealName,
            calories: l.calories,
            date: l.loggedAt,
          ),
        )
        .toList();

    return (recentSets, recentLogs);
  }

  // ---------------------------------------------------------------------------
  // C-5: Confirmation accepted — real implementation
  // ---------------------------------------------------------------------------

  Future<void> _onConfirmationAccepted(
    VoiceConfirmationAccepted event,
    Emitter<VoiceState> emit,
  ) async {
    final toolCall = state.pendingConfirmation;
    if (toolCall == null) return;

    emit(state.copyWith(clearPendingConfirmation: true));

    final now = DateTime.now();
    final spokenSuccess = await _dispatchMutationTool(toolCall, now);

    if (spokenSuccess != null) {
      final confirmMsg = VoiceMessage(
        role: VoiceRole.assistant,
        content: spokenSuccess,
        createdAt: now,
      );
      emit(
        state.copyWith(
          status: VoiceStatus.speaking,
          messages: <VoiceMessage>[...state.messages, confirmMsg],
        ),
      );
      await _speak(spokenSuccess);
      emit(state.copyWith(status: VoiceStatus.idle));
    } else {
      emit(state.copyWith(status: VoiceStatus.idle));
    }
  }

  // ---------------------------------------------------------------------------
  // C-5: Mutation tool dispatcher
  // ---------------------------------------------------------------------------

  /// Dispatches the confirmed tool call as a [VoiceMutationCommand] effect.
  /// [VoiceCommandRouter] in the widget tree converts each effect into a
  /// target-BLoC event via `context.read<X>().add(...)`.
  /// Returns the spoken success string, or null if dispatch failed.
  Future<String?> _dispatchMutationTool(VoiceToolCall tc, DateTime now) async {
    try {
      switch (tc.toolName) {
        case 'logWorkoutSet':
          final set = _buildWorkoutSet(tc.args, now);
          if (set == null) return AppStrings.voiceSpokenExerciseNotFound;
          emitEffect(VoiceAddWorkoutSetCommand(set));
          return AppStrings.voiceSpokenSetLogged;

        case 'editWorkoutSet':
          final setId = tc.args['setId'] as String? ?? '';
          final existing = _fetchSetById(setId);
          if (existing == null) return AppStrings.voiceSpokenToolFailed;
          final updated = _applyWorkoutSetEdits(existing, tc.args);
          emitEffect(VoiceUpdateWorkoutSetCommand(updated));
          return AppStrings.voiceSpokenSetUpdated;

        case 'deleteWorkoutSet':
          final setId = tc.args['setId'] as String? ?? '';
          if (setId.isEmpty) return AppStrings.voiceSpokenToolFailed;
          emitEffect(VoiceDeleteWorkoutSetCommand(setId));
          return AppStrings.voiceSpokenSetDeleted;

        case 'logNutrition':
          final log = _buildNutritionLog(tc.args, now);
          if (log == null) return AppStrings.voiceSpokenToolFailed;
          emitEffect(VoiceAddNutritionLogCommand(log));
          return AppStrings.voiceSpokenNutritionLogged;

        case 'editNutritionLog':
          final logId = tc.args['logId'] as String? ?? '';
          final existing = _fetchNutritionLogById(logId);
          if (existing == null) return AppStrings.voiceSpokenToolFailed;
          final updated = _applyNutritionLogEdits(existing, tc.args);
          emitEffect(VoiceUpdateNutritionLogCommand(updated));
          return AppStrings.voiceSpokenNutritionUpdated;

        case 'deleteNutritionLog':
          final logId = tc.args['logId'] as String? ?? '';
          if (logId.isEmpty) return AppStrings.voiceSpokenToolFailed;
          emitEffect(VoiceDeleteNutritionLogCommand(logId));
          return AppStrings.voiceSpokenNutritionDeleted;

        default:
          AppLogger.warning('VoiceBloc: unknown mutation tool: ${tc.toolName}');
          return AppStrings.voiceSpokenToolFailed;
      }
    } catch (e, st) {
      AppLogger.warning(
        'VoiceBloc: tool dispatch failed',
        error: e,
        stackTrace: st,
      );
      return AppStrings.voiceSpokenToolFailed;
    }
  }

  // ---------------------------------------------------------------------------
  // C-5: Entity builders
  // ---------------------------------------------------------------------------

  WorkoutSet? _buildWorkoutSet(Map<String, dynamic> args, DateTime now) {
    final exerciseName = args['exerciseName'] as String?;
    final exerciseId = args['exerciseId'] as String?;
    final reps = (args['reps'] as num?)?.toInt();
    final weight = (args['weight'] as num?)?.toDouble();

    if (exerciseName == null || reps == null || weight == null) {
      AppLogger.warning('VoiceBloc: logWorkoutSet missing required args');
      return null;
    }

    final resolvedExerciseId =
        exerciseId ?? _resolveExerciseIdFromCache(exerciseName);
    if (resolvedExerciseId == null) {
      AppLogger.warning(
        'VoiceBloc: cannot resolve exerciseId for "$exerciseName"',
      );
      return null;
    }

    final intensityRaw =
        (args['intensity'] as num?)?.toInt() ?? MuscleStimulus.defaultIntensity;
    final intensity = intensityRaw.clamp(
      MuscleStimulus.minIntensity,
      MuscleStimulus.maxIntensity,
    );

    final dateStr = args['date'] as String?;
    final date = dateStr != null ? _parseIsoDate(dateStr) ?? now : now;

    return WorkoutSet(
      id: const Uuid().v4(),
      exerciseId: resolvedExerciseId,
      reps: reps,
      weight: weight,
      intensity: intensity,
      date: date,
      createdAt: now,
    );
  }

  NutritionLog? _buildNutritionLog(Map<String, dynamic> args, DateTime now) {
    final mealName = args['mealName'] as String?;
    if (mealName == null) return null;

    final mealId = args['mealId'] as String?;
    final gramsConsumed = (args['gramsConsumed'] as num?)?.toDouble();
    final proteinGrams = (args['proteinGrams'] as num?)?.toDouble() ?? 0.0;
    final carbsGrams = (args['carbsGrams'] as num?)?.toDouble() ?? 0.0;
    final fatGrams = (args['fatGrams'] as num?)?.toDouble() ?? 0.0;
    final calories = (args['calories'] as num?)?.toDouble() ?? 0.0;

    final dateStr = args['loggedAt'] as String?;
    final loggedAt = dateStr != null ? _parseIsoDate(dateStr) ?? now : now;

    return NutritionLog(
      id: const Uuid().v4(),
      mealId: mealId,
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: now,
    );
  }

  WorkoutSet _applyWorkoutSetEdits(
    WorkoutSet existing,
    Map<String, dynamic> args,
  ) {
    final newIntensity = (args['intensity'] as num?)?.toInt();
    return existing.copyWith(
      reps: (args['reps'] as num?)?.toInt() ?? existing.reps,
      weight: (args['weight'] as num?)?.toDouble() ?? existing.weight,
      intensity: newIntensity != null
          ? newIntensity.clamp(
              MuscleStimulus.minIntensity,
              MuscleStimulus.maxIntensity,
            )
          : existing.intensity,
    );
  }

  NutritionLog _applyNutritionLogEdits(
    NutritionLog existing,
    Map<String, dynamic> args,
  ) {
    return existing.copyWith(
      gramsConsumed:
          (args['gramsConsumed'] as num?)?.toDouble() ?? existing.gramsConsumed,
      proteinGrams:
          (args['proteinGrams'] as num?)?.toDouble() ?? existing.proteinGrams,
      carbsGrams:
          (args['carbsGrams'] as num?)?.toDouble() ?? existing.carbsGrams,
      fatGrams: (args['fatGrams'] as num?)?.toDouble() ?? existing.fatGrams,
      calories: (args['calories'] as num?)?.toDouble() ?? existing.calories,
    );
  }

  // ---------------------------------------------------------------------------
  // C-5: Cache lookups
  // ---------------------------------------------------------------------------

  WorkoutSet? _fetchSetById(String setId) {
    if (setId.isEmpty) return null;
    for (final s in _cachedWorkoutSets) {
      if (s.id == setId) return s;
    }
    AppLogger.warning('VoiceBloc: setId "$setId" not found in recent cache');
    return null;
  }

  NutritionLog? _fetchNutritionLogById(String logId) {
    if (logId.isEmpty) return null;
    for (final l in _cachedNutritionLogs) {
      if (l.id == logId) return l;
    }
    AppLogger.warning('VoiceBloc: logId "$logId" not found in recent cache');
    return null;
  }

  /// Resolves an exercise name to its ID via the shared [ExerciseLookup] cache.
  /// Returns null if no match is found (exact or starts-with prefix).
  String? _resolveExerciseIdFromCache(String exerciseName) =>
      _exerciseLookup.resolveId(exerciseName);

  // ---------------------------------------------------------------------------
  // C-5: Query tool runner
  // ---------------------------------------------------------------------------

  Future<String> _executeQueryTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    try {
      switch (toolName) {
        case 'getWeeklyVolume':
          return await _queryWeeklyVolume(args);
        case 'getDailyMacros':
          return await _queryDailyMacros(args);
        case 'getRecentSets':
          return await _queryRecentSets(args);
        default:
          AppLogger.warning('VoiceBloc: unknown query tool: $toolName');
          return AppStrings.voiceSpokenGenericError;
      }
    } catch (e, st) {
      AppLogger.warning(
        'VoiceBloc: query tool failed',
        error: e,
        stackTrace: st,
      );
      return AppStrings.voiceSpokenGenericError;
    }
  }

  Future<String> _queryWeeklyVolume(Map<String, dynamic> args) async {
    final muscleGroup = args['muscleGroup'] as String?;
    final exerciseName = args['exerciseName'] as String?;
    final startDateStr = args['startDate'] as String?;
    final endDateStr = args['endDate'] as String?;

    final start = startDateStr != null
        ? _parseIsoDate(startDateStr) ?? _startOfCurrentWeek()
        : _startOfCurrentWeek();
    final end = endDateStr != null
        ? _parseIsoDate(endDateStr) ?? DateTime.now()
        : DateTime.now();

    final result = await _getSetsByDateRange(
      startDate: start,
      endDate: end,
      muscleGroup: muscleGroup,
    );

    return result.fold((_) => AppStrings.voiceQueryWorkoutUnavailable, (sets) {
      var filtered = sets;
      if (exerciseName != null) {
        final lower = exerciseName.toLowerCase();
        filtered = sets.where((s) {
          final name = _exerciseNameForId(s.exerciseId).toLowerCase();
          return name.contains(lower);
        }).toList();
      }

      if (filtered.isEmpty) {
        final period = muscleGroup != null ? '$muscleGroup sets' : 'sets';
        return AppStrings.voiceQueryNoSetsInPeriod(period);
      }

      // Group by exercise name
      final counts = <String, int>{};
      for (final s in filtered) {
        final name = _exerciseNameForId(s.exerciseId);
        counts[name] = (counts[name] ?? 0) + 1;
      }

      final total = filtered.length;
      final breakdown = counts.entries
          .map((e) => '${e.value} ${e.key}')
          .join(', ');
      final groupLabel = muscleGroup != null ? '$muscleGroup sets' : 'sets';
      return AppStrings.voiceQueryVolumeResult(total, groupLabel, breakdown);
    });
  }

  Future<String> _queryDailyMacros(Map<String, dynamic> args) async {
    final dateStr = args['date'] as String?;
    final date = dateStr != null
        ? _parseIsoDate(dateStr) ?? DateTime.now()
        : DateTime.now();

    final result = await _getDailyMacros(date);

    return result.fold((_) => AppStrings.voiceQueryNutritionUnavailable, (
      macros,
    ) {
      final protein = (macros['protein'] ?? 0.0).round();
      final carbs = (macros['carbs'] ?? 0.0).round();
      final fats = (macros['fats'] ?? 0.0).round();
      final calories = (macros['calories'] ?? 0.0).round();

      if (calories == 0) return AppStrings.voiceQueryNothingLogged;
      return AppStrings.voiceQueryMacroResult(calories, protein, carbs, fats);
    });
  }

  Future<String> _queryRecentSets(Map<String, dynamic> args) async {
    final exerciseName = args['exerciseName'] as String?;
    final limit = (args['limit'] as num?)?.toInt() ?? 5;

    final start = DateTime.now().subtract(const Duration(days: 30));
    final result = await _getSetsByDateRange(
      startDate: start,
      endDate: DateTime.now(),
    );

    return result.fold((_) => AppStrings.voiceQueryRecentSetsUnavailable, (
      sets,
    ) {
      var filtered = sets;
      if (exerciseName != null) {
        final lower = exerciseName.toLowerCase();
        filtered = sets.where((s) {
          final name = _exerciseNameForId(s.exerciseId).toLowerCase();
          return name.contains(lower);
        }).toList();
      }

      final limited = filtered.take(limit).toList();
      if (limited.isEmpty) {
        return exerciseName != null
            ? AppStrings.voiceQueryNoRecentSetsFor(exerciseName)
            : AppStrings.voiceQueryNoRecentSets;
      }

      final lines = limited
          .map((s) {
            final name = _exerciseNameForId(s.exerciseId);
            return '$name: ${s.weight} × ${s.reps} reps';
          })
          .join('. ');

      return AppStrings.voiceQueryRecentSetsResult(lines);
    });
  }

  // ---------------------------------------------------------------------------
  // Budget / history
  // ---------------------------------------------------------------------------

  void _refreshBudget() => add(const VoiceBudgetRefreshRequested());

  Future<void> _onBudgetRefresh(
    VoiceBudgetRefreshRequested event,
    Emitter<VoiceState> emit,
  ) async {
    if (state.isGuest) return;
    final result = await _getVoiceBudget();
    result.fold((_) {}, (budget) => emit(state.copyWith(budget: budget)));
  }

  Future<void> _onHistoryDelete(
    VoiceHistoryDeleteRequested event,
    Emitter<VoiceState> emit,
  ) async {
    if (state.isGuest) return;
    final result = await _deleteVoiceHistory();
    result.fold(
      (failure) => emit(state.copyWith(errorMessage: _messageFor(failure))),
      (_) => emit(
        state.copyWith(
          messages: const <VoiceMessage>[],
          sessionId: _uuid.v4(),
          clearError: true,
        ),
      ),
    );
  }

  void _onConversationCleared(
    VoiceConversationCleared event,
    Emitter<VoiceState> emit,
  ) {
    emit(
      state.copyWith(
        messages: const <VoiceMessage>[],
        sessionId: _uuid.v4(),
        status: VoiceStatus.idle,
        clearError: true,
        clearTranscript: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // C-3 handlers — confirmation & workout mode
  // ---------------------------------------------------------------------------

  void _onPendingConfirmationSet(
    VoicePendingConfirmationSet event,
    Emitter<VoiceState> emit,
  ) {
    emit(
      state.copyWith(
        pendingConfirmation: event.toolCall,
        clearPendingConfirmation: event.toolCall == null,
      ),
    );
  }

  void _onConfirmationCancelled(
    VoiceConfirmationCancelled event,
    Emitter<VoiceState> emit,
  ) {
    emit(state.copyWith(clearPendingConfirmation: true));
  }

  Future<void> _onWorkoutModeToggled(
    VoiceWorkoutModeToggled event,
    Emitter<VoiceState> emit,
  ) async {
    if (event.active) {
      await _wakelock.enable();
    } else {
      await _wakelock.disable();
    }
    emit(state.copyWith(isWorkoutModeActive: event.active));
  }

  // ---------------------------------------------------------------------------
  // C-4 handlers — connectivity
  // ---------------------------------------------------------------------------

  Future<void> _onConnectivityChanged(
    VoiceConnectivityChanged event,
    Emitter<VoiceState> emit,
  ) async {
    if (state.isOnline == event.isOnline) return;
    emit(state.copyWith(isOnline: event.isOnline));

    if (!event.isOnline && !state.hasAnnouncedOfflineThisSession) {
      emit(state.copyWith(hasAnnouncedOfflineThisSession: true));
      await _speak(AppStrings.voiceSpokenOfflineAnnouncement);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _rejectGuest(Emitter<VoiceState> emit) {
    if (!state.isGuest) return false;
    emit(
      state.copyWith(
        status: VoiceStatus.error,
        errorMessage: 'Sign in to use the voice assistant.',
      ),
    );
    return true;
  }

  /// Returns true if the bloc is already mid-operation. Caller should
  /// silently drop the event — re-entering a state would corrupt the
  /// state machine.
  bool _rejectBusy() => state.isBusy;

  String _ensureSessionId(Emitter<VoiceState> emit) {
    final sid = state.sessionId ?? _uuid.v4();
    if (state.sessionId == null) {
      emit(state.copyWith(sessionId: sid));
    }
    return sid;
  }

  String _messageFor(Failure failure) {
    if (failure.message.isNotEmpty) return failure.message;
    return 'Something went wrong.';
  }

  /// Returns the human-readable exercise name for [exerciseId] via the shared
  /// [ExerciseLookup] cache, or the raw ID string as a fallback.
  String _exerciseNameForId(String exerciseId) =>
      _exerciseLookup.nameForId(exerciseId);

  /// Parses an ISO `yyyy-MM-dd` date string into a [DateTime].
  /// Returns null if the string is malformed.
  DateTime? _parseIsoDate(String s) {
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  /// Returns midnight on Monday of the current week.
  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final daysFromMonday = (now.weekday - 1) % 7;
    return DateTime(now.year, now.month, now.day - daysFromMonday);
  }

  /// Maps STT error kinds to user-visible strings.
  String _sttErrorMessage(VoiceSttErrorKind kind) {
    switch (kind) {
      case VoiceSttErrorKind.permissionDenied:
        return AppStrings.voiceSttErrorPermission;
      case VoiceSttErrorKind.permissionPermanentlyDenied:
        return AppStrings.voiceSttErrorPermissionPermanent;
      case VoiceSttErrorKind.unavailable:
        return AppStrings.voiceSttErrorUnavailable;
      case VoiceSttErrorKind.noSpeech:
        return AppStrings.voiceSttErrorNoSpeech;
      case VoiceSttErrorKind.network:
        return AppStrings.voiceSttErrorNetwork;
      case VoiceSttErrorKind.unknown:
        return AppStrings.voiceSttErrorUnknown;
    }
  }

  /// Maps STT error kinds to spoken strings played via device TTS.
  String? _sttSpokenMessage(VoiceSttErrorKind kind) {
    switch (kind) {
      case VoiceSttErrorKind.noSpeech:
        return AppStrings.voiceSpokenNoSpeech;
      case VoiceSttErrorKind.network:
        return AppStrings.voiceSpokenNetworkDown;
      default:
        return AppStrings.voiceSpokenGenericError;
    }
  }

  /// Maps a [Failure] from the chat use case to a spoken string.
  String? _spokenMessageFor(Failure failure) {
    final msg = failure.message;
    if (msg.contains('BUDGET_EXCEEDED')) {
      return AppStrings.voiceSpokenBudgetExceeded;
    }
    if (msg.contains('TIMEOUT') || msg.contains('timeout')) {
      return AppStrings.voiceSpokenTimeout;
    }
    return AppStrings.voiceSpokenGenericError;
  }

  @override
  Future<void> close() async {
    await _sttSubscription?.cancel();
    _sttSubscription = null;
    await _tts.stop();
    // Always release wakelock on close — never leak it regardless of how
    // the overlay was dismissed.
    await _wakelock.disable();
    await super.close();
  }
}
