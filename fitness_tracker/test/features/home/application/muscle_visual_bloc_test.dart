import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetMuscleVisualData extends Mock implements GetMuscleVisualData {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String _testUserId = 'user-1';
const _authenticatedSession = AppSession(
  user: AppUser(id: _testUserId, email: 'user@test.com'),
);

const _chestData = MuscleVisualData(
  muscleGroup: 'chest',
  totalStimulus: 2.0,
  threshold: 5.0,
  visualIntensity: 0.4,
  bucket: MuscleVisualBucket.light,
  coverageState: MuscleVisualCoverageState.partial,
  aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
  visibleSurfaces: {MuscleVisualSurface.front},
  overflowAmount: 0.0,
  hasTrained: true,
);

const _weekData = <String, MuscleVisualData>{'chest': _chestData};
const _dbFailure = DatabaseFailure('db error');

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Matches a [MuscleVisualLoaded] by its observable fields, ignoring [loadedAt]
/// which is set internally via [DateTime.now()].
TypeMatcher<MuscleVisualLoaded> _isLoaded({
  required TimePeriod period,
  Map<String, MuscleVisualData> data = _weekData,
  MuscleMapMode mode = MuscleMapMode.volume,
}) => isA<MuscleVisualLoaded>()
    .having((s) => s.currentPeriod, 'currentPeriod', period)
    .having((s) => s.muscleData, 'muscleData', data)
    .having((s) => s.mode, 'mode', mode);

void main() {
  late MockGetMuscleVisualData mockGet;
  late MockAppSessionRepository mockSession;

  MuscleVisualBloc buildBloc() => MuscleVisualBloc(
    getMuscleVisualData: mockGet,
    appSessionRepository: mockSession,
  );

  setUp(() {
    mockGet = MockGetMuscleVisualData();
    mockSession = MockAppSessionRepository();

    // Default: return authenticated session with testUserId
    when(
      () => mockSession.getCurrentSession(),
    ).thenAnswer((_) async => const Right(_authenticatedSession));
  });

  group('MuscleVisualBloc', () {
    group('LoadMuscleVisualsEvent', () {
      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'emits [Loading(fatigue), Loaded(fatigue)] on success — default mode is fatigue',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) => bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week)),
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.week, mode: MuscleMapMode.fatigue),
        ],
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'emits [Loading(fatigue), Error(fatigue)] on use case failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week)),
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          const MuscleVisualError(
            message: 'db error',
            period: TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
        ],
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'serves second load from cache without a second use-case call',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week));
          await Future<void>.delayed(Duration.zero);
          // Second load: cache hit emits same state, BLoC deduplicates it
          bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.week, mode: MuscleMapMode.fatigue),
        ],
        // The use case must only be called once despite two load events
        verify: (_) => verify(() => mockGet(TimePeriod.week)).called(1),
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'resolves userId from session and forwards it to use case',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) => bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week)),
        verify: (_) {
          verify(() => mockSession.getCurrentSession()).called(greaterThan(0));
          verify(() => mockGet(TimePeriod.week)).called(1);
        },
      );

      // "uses empty userId when session resolves to guest" removed:
      // guest sessions no longer exist.
    });

    group('ChangePeriodEvent', () {
      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'loads data for the new period',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.today),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) => bloc.add(const ChangePeriodEvent(TimePeriod.today)),
        expect: () => [
          const MuscleVisualLoading(TimePeriod.today),
          _isLoaded(period: TimePeriod.today),
        ],
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'is a no-op when the same period is already loaded',
        build: buildBloc,
        seed: () => MuscleVisualLoaded(
          muscleData: _weekData,
          currentPeriod: TimePeriod.month,
          loadedAt: DateTime(2026, 4, 7),
        ),
        // _currentPeriod defaults to month; state is Loaded → no-op
        act: (bloc) => bloc.add(const ChangePeriodEvent(TimePeriod.month)),
        expect: () => <MuscleVisualState>[],
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'switches to volume mode when period is changed while in fatigue mode',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
          when(
            () => mockGet(TimePeriod.today),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // Default mode is fatigue. Load week to populate cache.
          bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week));
          await Future<void>.delayed(Duration.zero);
          // Change period → must flip back to volume and load today.
          bloc.add(const ChangePeriodEvent(TimePeriod.today));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.week, mode: MuscleMapMode.fatigue),
          // after period change, volume is restored
          const MuscleVisualLoading(
            TimePeriod.today,
            mode: MuscleMapMode.volume,
          ),
          _isLoaded(period: TimePeriod.today, mode: MuscleMapMode.volume),
        ],
      );
    });

    group('ChangeModeEvent', () {
      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'from Initial, ChangeModeEvent(fatigue) fetches week data and '
        'emits Loaded(mode:fatigue, currentPeriod:month)',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        // Default mode is already fatigue, but state is Initial → not a no-op.
        act: (bloc) => bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue)),
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) => verify(() => mockGet(TimePeriod.week)).called(1),
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'toggling to volume after fatigue loads the current period (month)',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
          when(
            () => mockGet(TimePeriod.month),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // Startup path: load fatigue (week)
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
          await Future<void>.delayed(Duration.zero);
          // Toggle to volume → loads month (the fallback _currentPeriod)
          bloc.add(const ChangeModeEvent(MuscleMapMode.volume));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.volume,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.volume),
        ],
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'fatigue mode fetches week data regardless of current period',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
          when(
            () => mockGet(TimePeriod.month),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // First: switch to volume (default is fatigue) → loads month
          bloc.add(const ChangeModeEvent(MuscleMapMode.volume));
          await Future<void>.delayed(Duration.zero);
          // Switch back to fatigue → must fetch week, not month
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.volume,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.volume),
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) {
          verify(() => mockGet(TimePeriod.week)).called(1);
          verify(() => mockGet(TimePeriod.month)).called(1);
        },
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'serves from cache when week data is already cached for fatigue mode',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
          when(
            () => mockGet(TimePeriod.month),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // Load fatigue (week) → caches week data
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
          await Future<void>.delayed(Duration.zero);
          // Toggle to volume
          bloc.add(const ChangeModeEvent(MuscleMapMode.volume));
          await Future<void>.delayed(Duration.zero);
          // Back to fatigue → week cache is valid, no second fetch
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.volume,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.volume),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) {
          verify(() => mockGet(TimePeriod.week)).called(1);
          verify(() => mockGet(TimePeriod.month)).called(1);
        },
      );

      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'is a no-op when already in fatigue mode and loaded',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // First dispatch loads fatigue
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
          await Future<void>.delayed(Duration.zero);
          // Same mode + Loaded → no-op
          bloc.add(const ChangeModeEvent(MuscleMapMode.fatigue));
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) => verify(() => mockGet(TimePeriod.week)).called(1),
      );
    });

    group('RefreshVisualsEvent', () {
      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'bypasses cache and reloads — in fatigue mode fetches week',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) async {
          // Load once to populate cache (fatigue = week)
          bloc.add(const LoadMuscleVisualsEvent(TimePeriod.week));
          await Future<void>.delayed(Duration.zero);
          // Refresh clears cache and reloads
          bloc.add(const RefreshVisualsEvent());
        },
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.week, mode: MuscleMapMode.fatigue),
          const MuscleVisualLoading(
            TimePeriod.week,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.week, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) => verify(() => mockGet(TimePeriod.week)).called(2),
      );
    });

    group('ClearCacheEvent', () {
      blocTest<MuscleVisualBloc, MuscleVisualState>(
        'clears cache and reloads via RefreshVisualsEvent — '
        'in fatigue mode fetches week, not month',
        build: buildBloc,
        setUp: () {
          // ClearCacheEvent now dispatches RefreshVisualsEvent, which is
          // mode-aware: fatigue → fetches TimePeriod.week.
          when(
            () => mockGet(TimePeriod.week),
          ).thenAnswer((_) async => const Right(_weekData));
        },
        act: (bloc) => bloc.add(const ClearCacheEvent()),
        expect: () => [
          const MuscleVisualLoading(
            TimePeriod.month,
            mode: MuscleMapMode.fatigue,
          ),
          _isLoaded(period: TimePeriod.month, mode: MuscleMapMode.fatigue),
        ],
        verify: (_) => verify(() => mockGet(TimePeriod.week)).called(1),
      );
    });
  });
}
