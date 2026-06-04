import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/session/current_user_id_resolver.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/system_clock.dart';
import '../../../domain/entities/muscle_visual_data.dart';
import '../../../domain/entities/time_period.dart';
import '../../../domain/repositories/app_session_repository.dart';
import '../../../domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';

/// Controls what the 2D human model visualises.
///
/// - [volume]: training load for the selected time period (today / week / month / all-time).
/// - [fatigue]: current accumulated fatigue based on the rolling weekly load,
///   independent of the period selector.  If the user trained heavily 4–5 days
///   in a row and then rests today, volume (today) is gray while fatigue is
///   orange/red because the muscles have not yet recovered.
enum MuscleMapMode { volume, fatigue }

// ─── Events ──────────────────────────────────────────────────────────────────

abstract class MuscleVisualEvent extends Equatable {
  const MuscleVisualEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class LoadMuscleVisualsEvent extends MuscleVisualEvent {
  const LoadMuscleVisualsEvent(this.period);

  final TimePeriod period;

  @override
  List<Object?> get props => <Object?>[period];
}

class ChangePeriodEvent extends MuscleVisualEvent {
  const ChangePeriodEvent(this.newPeriod);

  final TimePeriod newPeriod;

  @override
  List<Object?> get props => <Object?>[newPeriod];
}

class ChangeModeEvent extends MuscleVisualEvent {
  const ChangeModeEvent(this.mode);

  final MuscleMapMode mode;

  @override
  List<Object?> get props => <Object?>[mode];
}

class RefreshVisualsEvent extends MuscleVisualEvent {
  const RefreshVisualsEvent();
}

class ClearCacheEvent extends MuscleVisualEvent {
  const ClearCacheEvent();
}

// ─── States ──────────────────────────────────────────────────────────────────

abstract class MuscleVisualState extends Equatable {
  const MuscleVisualState();

  @override
  List<Object?> get props => <Object?>[];
}

class MuscleVisualInitial extends MuscleVisualState {
  const MuscleVisualInitial();
}

class MuscleVisualLoading extends MuscleVisualState {
  const MuscleVisualLoading(this.period, {this.mode = MuscleMapMode.volume});

  final TimePeriod period;
  final MuscleMapMode mode;

  @override
  List<Object?> get props => <Object?>[period, mode];
}

class MuscleVisualLoaded extends MuscleVisualState {
  const MuscleVisualLoaded({
    required this.muscleData,
    required this.currentPeriod,
    required this.loadedAt,
    this.mode = MuscleMapMode.volume,
  });

  final Map<String, MuscleVisualData> muscleData;
  final TimePeriod currentPeriod;
  final DateTime loadedAt;
  final MuscleMapMode mode;

  int get trainedMuscleCount => muscleData.values
      .where((MuscleVisualData data) => data.hasTrained)
      .length;

  bool get hasAnyTraining =>
      muscleData.values.any((MuscleVisualData data) => data.hasTrained);

  @override
  List<Object?> get props => <Object?>[
    muscleData,
    currentPeriod,
    loadedAt,
    mode,
  ];
}

class MuscleVisualError extends MuscleVisualState {
  const MuscleVisualError({
    required this.message,
    required this.period,
    this.mode = MuscleMapMode.volume,
  });

  final String message;
  final TimePeriod period;
  final MuscleMapMode mode;

  @override
  List<Object?> get props => <Object?>[message, period, mode];
}

class MuscleVisualBloc extends Bloc<MuscleVisualEvent, MuscleVisualState> {
  MuscleVisualBloc({
    required this.getMuscleVisualData,
    required this.appSessionRepository,
    Clock clock = const SystemClock(),
  }) : _userIdResolver = CurrentUserIdResolver(
         appSessionRepository: appSessionRepository,
       ),
       _clock = clock,
       super(const MuscleVisualInitial()) {
    on<LoadMuscleVisualsEvent>(_onLoadMuscleVisuals);
    on<ChangePeriodEvent>(_onChangePeriod);
    on<ChangeModeEvent>(_onChangeMode);
    on<RefreshVisualsEvent>(_onRefreshVisuals);
    on<ClearCacheEvent>(_onClearCache);
  }

  final GetMuscleVisualData getMuscleVisualData;
  final AppSessionRepository appSessionRepository;

  final CurrentUserIdResolver _userIdResolver;
  final Clock _clock;

  /// Cache key is a Dart 3 record `(TimePeriod, userId)` so that data from one
  /// authenticated user is never served to a different user after a sign-out /
  /// sign-in cycle, even when the BLoC instance is reused across sessions.
  final Map<(TimePeriod, String), Map<String, MuscleVisualData>> _periodCache =
      <(TimePeriod, String), Map<String, MuscleVisualData>>{};
  final Map<(TimePeriod, String), DateTime> _cacheTimestamps =
      <(TimePeriod, String), DateTime>{};

  // Default landing mode is Fatigue — the "right now" muscle state view.
  // _currentPeriod (month) is the fallback used when the user toggles to Volume.
  TimePeriod _currentPeriod = TimePeriod.month;
  MuscleMapMode _currentMode = MuscleMapMode.fatigue;

  /// Resolves the current user id via the shared [CurrentUserIdResolver], so
  /// readers always see the same identifier that writers used. Throws
  /// `MissingUserContextException` when the bloc is constructed above the
  /// auth gate without a resolvable session — that path should be
  /// unreachable in practice.
  Future<String> _resolveUserId() => _userIdResolver.resolve();

  Future<void> _onLoadMuscleVisuals(
    LoadMuscleVisualsEvent event,
    Emitter<MuscleVisualState> emit,
  ) async {
    _currentPeriod = event.period;

    // Resolve userId upfront — required for the userId-scoped cache key and
    // for forwarding to the use case.
    final String userId = await _resolveUserId();

    if (_isCacheValid(event.period, userId)) {
      emit(
        MuscleVisualLoaded(
          muscleData: _periodCache[(event.period, userId)]!,
          currentPeriod: event.period,
          loadedAt: _cacheTimestamps[(event.period, userId)]!,
          mode: _currentMode,
        ),
      );
      return;
    }

    emit(MuscleVisualLoading(event.period, mode: _currentMode));

    final result = await getMuscleVisualData(event.period);

    result.fold(
      (failure) => emit(
        MuscleVisualError(
          message: failure.message,
          period: event.period,
          mode: _currentMode,
        ),
      ),
      (visualData) {
        final DateTime now = _clock.now();
        final (TimePeriod, String) key = (event.period, userId);
        _periodCache[key] = visualData;
        _cacheTimestamps[key] = now;

        emit(
          MuscleVisualLoaded(
            muscleData: visualData,
            currentPeriod: event.period,
            loadedAt: now,
            mode: _currentMode,
          ),
        );
      },
    );
  }

  Future<void> _onChangePeriod(
    ChangePeriodEvent event,
    Emitter<MuscleVisualState> emit,
  ) async {
    // Selecting a period while in fatigue mode implicitly switches to volume.
    if (_currentMode == MuscleMapMode.fatigue) {
      _currentMode = MuscleMapMode.volume;
    }

    // Same period + already loaded → no-op (avoid unnecessary resolution).
    if (event.newPeriod == _currentPeriod && state is MuscleVisualLoaded) {
      return;
    }

    _currentPeriod = event.newPeriod;

    // Resolve userId upfront for the userId-scoped cache key.
    final String userId = await _resolveUserId();

    if (_isCacheValid(event.newPeriod, userId)) {
      emit(
        MuscleVisualLoaded(
          muscleData: _periodCache[(event.newPeriod, userId)]!,
          currentPeriod: event.newPeriod,
          loadedAt: _cacheTimestamps[(event.newPeriod, userId)]!,
          mode: _currentMode,
        ),
      );
      return;
    }

    emit(MuscleVisualLoading(event.newPeriod, mode: _currentMode));

    final result = await getMuscleVisualData(event.newPeriod);

    result.fold(
      (failure) => emit(
        MuscleVisualError(
          message: failure.message,
          period: event.newPeriod,
          mode: _currentMode,
        ),
      ),
      (visualData) {
        final DateTime now = _clock.now();
        final (TimePeriod, String) key = (event.newPeriod, userId);
        _periodCache[key] = visualData;
        _cacheTimestamps[key] = now;

        emit(
          MuscleVisualLoaded(
            muscleData: visualData,
            currentPeriod: event.newPeriod,
            loadedAt: now,
            mode: _currentMode,
          ),
        );
      },
    );
  }

  /// Switches between [MuscleMapMode.volume] and [MuscleMapMode.fatigue].
  ///
  /// Fatigue always reads the rolling weekly load (same underlying data as the
  /// Week period view) but frames it as "how tired are my muscles right now"
  /// rather than "how much did I train this period".
  Future<void> _onChangeMode(
    ChangeModeEvent event,
    Emitter<MuscleVisualState> emit,
  ) async {
    // Same mode + already loaded → no-op (avoid unnecessary resolution).
    if (_currentMode == event.mode && state is MuscleVisualLoaded) return;
    _currentMode = event.mode;

    // Fatigue always reads the rolling weekly load, regardless of selected period.
    final TimePeriod periodToFetch = _currentMode == MuscleMapMode.fatigue
        ? TimePeriod.week
        : _currentPeriod;

    // Resolve userId upfront for the userId-scoped cache key.
    final String userId = await _resolveUserId();

    if (_isCacheValid(periodToFetch, userId)) {
      emit(
        MuscleVisualLoaded(
          muscleData: _periodCache[(periodToFetch, userId)]!,
          currentPeriod: _currentPeriod,
          loadedAt: _cacheTimestamps[(periodToFetch, userId)]!,
          mode: _currentMode,
        ),
      );
      return;
    }

    emit(MuscleVisualLoading(_currentPeriod, mode: _currentMode));

    final result = await getMuscleVisualData(periodToFetch);

    result.fold(
      (failure) => emit(
        MuscleVisualError(
          message: failure.message,
          period: _currentPeriod,
          mode: _currentMode,
        ),
      ),
      (visualData) {
        final DateTime now = _clock.now();
        final (TimePeriod, String) key = (periodToFetch, userId);
        _periodCache[key] = visualData;
        _cacheTimestamps[key] = now;

        emit(
          MuscleVisualLoaded(
            muscleData: visualData,
            currentPeriod: _currentPeriod,
            loadedAt: now,
            mode: _currentMode,
          ),
        );
      },
    );
  }

  Future<void> _onRefreshVisuals(
    RefreshVisualsEvent event,
    Emitter<MuscleVisualState> emit,
  ) async {
    final TimePeriod periodToRefresh = _currentMode == MuscleMapMode.fatigue
        ? TimePeriod.week
        : _currentPeriod;

    // Resolve userId to correctly identify and remove the right cache entry.
    final String userId = await _resolveUserId();
    final (TimePeriod, String) cacheKey = (periodToRefresh, userId);

    _periodCache.remove(cacheKey);
    _cacheTimestamps.remove(cacheKey);

    emit(MuscleVisualLoading(_currentPeriod, mode: _currentMode));

    final result = await getMuscleVisualData(periodToRefresh);

    result.fold(
      (failure) => emit(
        MuscleVisualError(
          message: failure.message,
          period: _currentPeriod,
          mode: _currentMode,
        ),
      ),
      (visualData) {
        final DateTime now = _clock.now();
        _periodCache[cacheKey] = visualData;
        _cacheTimestamps[cacheKey] = now;

        emit(
          MuscleVisualLoaded(
            muscleData: visualData,
            currentPeriod: _currentPeriod,
            loadedAt: now,
            mode: _currentMode,
          ),
        );
      },
    );
  }

  Future<void> _onClearCache(
    ClearCacheEvent event,
    Emitter<MuscleVisualState> emit,
  ) async {
    _periodCache.clear();
    _cacheTimestamps.clear();
    // Use RefreshVisualsEvent so the reload respects _currentMode: in fatigue
    // mode it fetches TimePeriod.week; in volume mode it fetches _currentPeriod.
    // LoadMuscleVisualsEvent(_currentPeriod) would serve volume data while
    // emitting mode:fatigue, which is an incorrect pairing.
    add(const RefreshVisualsEvent());
  }

  /// Returns `true` when a cache entry exists for [period] scoped to
  /// [userId]. Freshness is purely event-driven: the cache is invalidated
  /// explicitly via [ClearCacheEvent] (dispatched on sync completion) and
  /// [RefreshVisualsEvent] (dispatched after a local log). There is no TTL —
  /// a time-based window let a background sync's rebuilt projection sit
  /// unseen for up to the TTL duration, which is exactly the staleness this
  /// removes. A separate entry per user prevents stale data from being
  /// served after a sign-out / sign-in switch.
  bool _isCacheValid(TimePeriod period, String userId) {
    final (TimePeriod, String) key = (period, userId);

    return _periodCache.containsKey(key) && _cacheTimestamps.containsKey(key);
  }

  @override
  Future<void> close() {
    _periodCache.clear();
    _cacheTimestamps.clear();
    return super.close();
  }
}
