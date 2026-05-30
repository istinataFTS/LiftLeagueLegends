import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/muscle_visual_data.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/time_period.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/home/application/home_bloc.dart';
import 'package:fitness_tracker/features/home/application/models/home_dashboard_data.dart';
import 'package:fitness_tracker/features/home/application/muscle_visual_bloc.dart';
import 'package:fitness_tracker/features/home/presentation/home_page.dart';
import 'package:fitness_tracker/features/home/presentation/home_page_keys.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/period_selector_widget.dart';
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

ProfileState _authedProfileState({String displayName = 'Marin'}) =>
    ProfileState(
      session: AppSession(
        user: AppUser(id: 'u1', email: 'a@b.com', displayName: displayName),
        requiresInitialCloudMigration: false,
        lastCloudSyncAt: null,
      ),
      isLoading: false,
      hasLoaded: true,
      userProfile: UserProfile(
        id: 'u1',
        username: 'marin',
        displayName: displayName,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );

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

  final HomeDashboardData loadedHomeData = HomeDashboardData(
    todaysLogs: <NutritionLog>[
      NutritionLog(
        id: 'log-1',
        mealName: 'Chicken and Rice',
        proteinGrams: 45,
        carbsGrams: 60,
        fatGrams: 12,
        calories: 528,
        loggedAt: now,
        createdAt: now,
      ),
    ],
    dailyMacros: const <String, double>{
      'protein': 120,
      'carbs': 140,
      'fats': 40,
      'calories': 1600,
    },
  );

  final HomeLoaded loadedHomeState = HomeLoaded(data: loadedHomeData);

  final MuscleVisualLoaded loadedMuscleState = MuscleVisualLoaded(
    muscleData: <String, MuscleVisualData>{
      'chest': MuscleVisualData(
        muscleGroup: 'chest',
        totalStimulus: 6,
        threshold: 6,
        visualIntensity: 1.0,
        bucket: MuscleVisualBucket.maximum,
        coverageState: MuscleVisualCoverageState.full,
        aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
        visibleSurfaces: const <MuscleVisualSurface>{MuscleVisualSurface.front},
        overflowAmount: 0,
        hasTrained: true,
      ),
    },
    currentPeriod: TimePeriod.month,
    loadedAt: now,
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

    final ProfileState profileState = _authedProfileState();
    when(() => profileCubit.state).thenReturn(profileState);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: profileState,
    );

    when(() => homeBloc.state).thenReturn(loadedHomeState);
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: loadedHomeState,
    );

    when(() => muscleVisualBloc.state).thenReturn(loadedMuscleState);
    whenListen<MuscleVisualState>(
      muscleVisualBloc,
      const Stream<MuscleVisualState>.empty(),
      initialState: loadedMuscleState,
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

  testWidgets('shows dedicated page loading indicator for HomeInitial', (
    WidgetTester tester,
  ) async {
    when(() => homeBloc.state).thenReturn(const HomeInitial());
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeInitial(),
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byKey(HomePage.pageLoadingIndicatorKey), findsOneWidget);
  });

  testWidgets('shows dedicated page loading indicator for HomeLoading', (
    WidgetTester tester,
  ) async {
    when(() => homeBloc.state).thenReturn(const HomeLoading());
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeLoading(),
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byKey(HomePage.pageLoadingIndicatorKey), findsOneWidget);
  });

  testWidgets('home-level retry dispatches LoadHomeDataEvent', (
    WidgetTester tester,
  ) async {
    when(() => homeBloc.state).thenReturn(const HomeError('load failed'));
    whenListen<HomeState>(
      homeBloc,
      const Stream<HomeState>.empty(),
      initialState: const HomeError('load failed'),
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byKey(HomePage.homeRetryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(HomePage.homeRetryButtonKey));
    await tester.pump();

    verify(() => homeBloc.add(const LoadHomeDataEvent())).called(1);
  });

  testWidgets('renders core loaded sections through stable feature keys', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(HomePage.refreshListKey), findsOneWidget);
    expect(find.byKey(HomePage.progressCardKey), findsOneWidget);
    expect(find.byKey(HomePageKeys.macroStripKey), findsOneWidget);
    expect(find.byKey(HomePageKeys.bodyVisualKey), findsOneWidget);

    // Macro strip shows four tiles.
    expect(find.text('Calories'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Carbs'), findsOneWidget);
    expect(find.text('Fats'), findsOneWidget);

    expect(find.text('Progress • Month'), findsOneWidget);
  });

  testWidgets('greeting uses the resolved session display name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Hello, Marin!'), findsOneWidget);
  });

  // "greeting falls back to Guest for an unauthenticated session" removed:
  // unauthenticated sessions are rejected by the auth gate above HomePage.

  testWidgets(
    'period selector exposes stable key and dispatches month change',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(PeriodSelectorWidget.dropdownKey), findsOneWidget);

      await tester.tap(find.byKey(PeriodSelectorWidget.dropdownKey));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(PeriodSelectorWidget.menuItemKey(TimePeriod.month)).last,
      );
      await tester.pumpAndSettle();

      verify(
        () => muscleVisualBloc.add(ChangePeriodEvent(TimePeriod.month)),
      ).called(1);
    },
  );

  testWidgets('visual retry uses progress retry button key', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(() => muscleVisualBloc.state).thenReturn(
      const MuscleVisualError(
        message: 'visual load failed',
        period: TimePeriod.today,
      ),
    );
    whenListen<MuscleVisualState>(
      muscleVisualBloc,
      const Stream<MuscleVisualState>.empty(),
      initialState: const MuscleVisualError(
        message: 'visual load failed',
        period: TimePeriod.week,
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(HomePage.progressRetryButtonKey), findsOneWidget);

    await tester.tap(find.byKey(HomePage.progressRetryButtonKey));
    await tester.pump();

    verify(() => muscleVisualBloc.add(const RefreshVisualsEvent())).called(1);
  });

  testWidgets('visual loading shows dedicated progress loading indicator', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    when(
      () => muscleVisualBloc.state,
    ).thenReturn(const MuscleVisualLoading(TimePeriod.month));
    whenListen<MuscleVisualState>(
      muscleVisualBloc,
      const Stream<MuscleVisualState>.empty(),
      initialState: const MuscleVisualLoading(TimePeriod.month),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(HomePage.progressLoadingIndicatorKey), findsOneWidget);
    expect(find.byKey(PeriodSelectorWidget.dropdownKey), findsOneWidget);
  });

  testWidgets('month period renders progress card cleanly', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final MuscleVisualLoaded monthState = MuscleVisualLoaded(
      muscleData: <String, MuscleVisualData>{
        'chest': MuscleVisualData(
          muscleGroup: 'chest',
          totalStimulus: 12,
          threshold: 6,
          visualIntensity: 1.0,
          bucket: MuscleVisualBucket.maximum,
          coverageState: MuscleVisualCoverageState.full,
          aggregationMode: MuscleVisualAggregationMode.rollingWeeklyLoad,
          visibleSurfaces: const <MuscleVisualSurface>{
            MuscleVisualSurface.front,
          },
          overflowAmount: 6,
          hasTrained: true,
        ),
      },
      currentPeriod: TimePeriod.month,
      loadedAt: now,
    );

    when(() => muscleVisualBloc.state).thenReturn(monthState);
    whenListen<MuscleVisualState>(
      muscleVisualBloc,
      const Stream<MuscleVisualState>.empty(),
      initialState: monthState,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Progress • Month'), findsOneWidget);
    expect(find.byKey(HomePage.progressCardKey), findsOneWidget);
  });

  testWidgets(
    'pull to refresh dispatches both refresh events from refresh list',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.drag(
        find.byKey(HomePage.refreshListKey),
        const Offset(0, 300),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      verify(() => homeBloc.add(const RefreshHomeDataEvent())).called(1);
      verify(() => muscleVisualBloc.add(const RefreshVisualsEvent())).called(1);
    },
  );
}
