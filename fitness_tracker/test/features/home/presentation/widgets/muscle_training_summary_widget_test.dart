import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/features/home/application/home_bloc.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/features/home/presentation/home_page.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

class MockMuscleVisualBloc
    extends MockBloc<MuscleVisualEvent, MuscleVisualState>
    implements MuscleVisualBloc {}

class MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

class FakeHomeEvent extends Fake implements HomeEvent {}

class FakeHomeState extends Fake implements HomeState {}

class FakeMuscleVisualEvent extends Fake implements MuscleVisualEvent {}

class FakeMuscleVisualState extends Fake implements MuscleVisualState {}

void main() {
  late MockHomeBloc homeBloc;
  late MockMuscleVisualBloc muscleVisualBloc;
  late MockProfileCubit profileCubit;

  final DateTime now = DateTime(2026, 3, 19, 10, 0);

  const AppSettings settings = AppSettings.defaults();

  // No training targets — keeps showMuscleGroups: false so _MuscleGroupSection
  // never renders a "Chest" title that would collide with muscle summary rows.
  final HomeLoaded loadedHomeState = HomeLoaded(
    data: HomeDashboardData(
      todaysLogs: const <NutritionLog>[],
      dailyMacros: const <String, double>{},
    ),
  );

  setUpAll(() {
    registerFallbackValue(FakeHomeEvent());
    registerFallbackValue(FakeHomeState());
    registerFallbackValue(FakeMuscleVisualEvent());
    registerFallbackValue(FakeMuscleVisualState());
  });

  setUp(() {
    homeBloc = MockHomeBloc();
    muscleVisualBloc = MockMuscleVisualBloc();
    profileCubit = MockProfileCubit();

    const ProfileState guest = ProfileState(
      session: AppSession.guest(),
      isLoading: false,
      hasLoaded: true,
    );
    when(() => profileCubit.state).thenReturn(guest);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: guest,
    );

    when(() => homeBloc.state).thenReturn(loadedHomeState);
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: loadedHomeState,
    );
  });

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<HomeBloc>.value(value: homeBloc),
        BlocProvider<MuscleVisualBloc>.value(value: muscleVisualBloc),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
      ],
      child: const MaterialApp(home: HomePage(settings: settings)),
    );
  }

  group('HomePage muscle summary rendering', () {
    testWidgets(
      'shows empty summary list when no trained muscles are present',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final MuscleVisualLoaded emptyState = MuscleVisualLoaded(
          muscleData: const <String, MuscleVisualData>{},
          currentPeriod: TimePeriod.today,
          loadedAt: now,
        );

        when(() => muscleVisualBloc.state).thenReturn(emptyState);
        whenListen<MuscleVisualState>(
          muscleVisualBloc,
          const Stream<MuscleVisualState>.empty(),
          initialState: emptyState,
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.textContaining('Progress'), findsOneWidget);
        expect(find.text('Chest'), findsNothing);
        expect(find.text('Biceps'), findsNothing);
        expect(find.text('Lats'), findsNothing);
      },
    );

    testWidgets('shows ranked trained muscles in display order', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final MuscleVisualLoaded visualState = MuscleVisualLoaded(
        muscleData: <String, MuscleVisualData>{
          'lats': const MuscleVisualData(
            muscleGroup: 'lats',
            totalStimulus: 20,
            threshold: 20,
            visualIntensity: 0.85,
            bucket: MuscleVisualBucket.maximum,
            coverageState: MuscleVisualCoverageState.full,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: const <MuscleVisualSurface>{
              MuscleVisualSurface.back,
            },
            overflowAmount: 0,
            hasTrained: true,
          ),
          'chest': const MuscleVisualData(
            muscleGroup: 'chest',
            totalStimulus: 12,
            threshold: 20,
            visualIntensity: 0.55,
            bucket: MuscleVisualBucket.heavy,
            coverageState: MuscleVisualCoverageState.partial,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: const <MuscleVisualSurface>{
              MuscleVisualSurface.front,
            },
            overflowAmount: 0,
            hasTrained: true,
          ),
          'biceps': const MuscleVisualData(
            muscleGroup: 'biceps',
            totalStimulus: 7,
            threshold: 20,
            visualIntensity: 0.18,
            bucket: MuscleVisualBucket.light,
            coverageState: MuscleVisualCoverageState.partial,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: const <MuscleVisualSurface>{
              MuscleVisualSurface.front,
            },
            overflowAmount: 0,
            hasTrained: true,
          ),
        },
        currentPeriod: TimePeriod.today,
        loadedAt: now,
      );

      when(() => muscleVisualBloc.state).thenReturn(visualState);
      whenListen<MuscleVisualState>(
        muscleVisualBloc,
        const Stream<MuscleVisualState>.empty(),
        initialState: visualState,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      final Finder latsFinder = find.text('Lats');
      final Finder chestFinder = find.text('Chest');
      final Finder bicepsFinder = find.text('Biceps');

      expect(latsFinder, findsOneWidget);
      expect(chestFinder, findsOneWidget);
      expect(bicepsFinder, findsOneWidget);

      expect(
        tester.getTopLeft(latsFinder).dy,
        lessThan(tester.getTopLeft(chestFinder).dy),
      );
      expect(
        tester.getTopLeft(chestFinder).dy,
        lessThan(tester.getTopLeft(bicepsFinder).dy),
      );

      expect(find.text('20 • Maximum'), findsOneWidget);
      expect(find.text('12 • Heavy'), findsOneWidget);
      expect(find.text('7 • Light'), findsOneWidget);
    });

    testWidgets('shows muscle summary rows only for trained muscles', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final MuscleVisualLoaded visualState = MuscleVisualLoaded(
        muscleData: <String, MuscleVisualData>{
          'chest': const MuscleVisualData(
            muscleGroup: 'chest',
            totalStimulus: 14,
            threshold: 20,
            visualIntensity: 0.55,
            bucket: MuscleVisualBucket.heavy,
            coverageState: MuscleVisualCoverageState.partial,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: const <MuscleVisualSurface>{
              MuscleVisualSurface.front,
            },
            overflowAmount: 0,
            hasTrained: true,
          ),
          'back': const MuscleVisualData(
            muscleGroup: 'back',
            totalStimulus: 0,
            threshold: 20,
            visualIntensity: 0,
            bucket: MuscleVisualBucket.empty,
            coverageState: MuscleVisualCoverageState.empty,
            aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
            visibleSurfaces: const <MuscleVisualSurface>{
              MuscleVisualSurface.back,
            },
            overflowAmount: 0,
            hasTrained: false,
          ),
        },
        currentPeriod: TimePeriod.today,
        loadedAt: now,
      );

      when(() => muscleVisualBloc.state).thenReturn(visualState);
      whenListen<MuscleVisualState>(
        muscleVisualBloc,
        const Stream<MuscleVisualState>.empty(),
        initialState: visualState,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('14 • Heavy'), findsOneWidget);
      // 'Back' may appear as the BodyVisualWidget figure label when that side
      // is shown, so we assert on the summary-row stat text instead — it only
      // appears in summary rows and unambiguously proves no row was rendered
      // for the back muscle.
      expect(find.text('0 • Untrained'), findsNothing);
    });
  });
}
