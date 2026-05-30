import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:fitness_tracker/features/settings/presentation/settings_page.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSettingsCubit extends MockCubit<AppSettingsState>
    implements AppSettingsCubit {}

class MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

class MockProfileCubit extends MockCubit<ProfileState>
    implements ProfileCubit {}

ProfileState _guestProfileState() => const ProfileState(
  session: AppSession(
    user: AppUser(id: '__test_guest__', email: 'guest@test.local'),
  ),
  isLoading: false,
  hasLoaded: true,
);

ProfileState _authedProfileState({String username = 'alice'}) => ProfileState(
  session: AppSession(
    user: const AppUser(id: 'user-1', email: 'a@b.com', displayName: 'A'),
    requiresInitialCloudMigration: false,
    lastCloudSyncAt: null,
  ),
  isLoading: false,
  hasLoaded: true,
  userProfile: UserProfile(
    id: 'user-1',
    username: username,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(WeekStartDay.monday);
    registerFallbackValue(WeightUnit.kilograms);
  });

  late MockAppSettingsCubit cubit;
  late MockVoiceSettingsCubit voiceCubit;
  late MockProfileCubit profileCubit;

  AppSettingsState buildState({
    AppSettings settings = const AppSettings.defaults(),
    bool isLoading = false,
    bool isSaving = false,
    bool hasLoaded = true,
    String? errorMessage,
  }) {
    return AppSettingsState(
      settings: settings,
      isLoading: isLoading,
      isSaving: isSaving,
      hasLoaded: hasLoaded,
      errorMessage: errorMessage,
    );
  }

  Widget buildSubject() {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppSettingsCubit>.value(value: cubit),
        BlocProvider<VoiceSettingsCubit>.value(value: voiceCubit),
        BlocProvider<ProfileCubit>.value(value: profileCubit),
      ],
      child: const MaterialApp(home: SettingsPage()),
    );
  }

  setUp(() {
    cubit = MockAppSettingsCubit();
    voiceCubit = MockVoiceSettingsCubit();
    profileCubit = MockProfileCubit();

    final ProfileState guestState = _guestProfileState();
    when(() => profileCubit.state).thenReturn(guestState);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: guestState,
    );

    const VoiceSettings initialVoiceSettings = VoiceSettings.defaults();
    when(() => voiceCubit.state).thenReturn(initialVoiceSettings);
    whenListen<VoiceSettings>(
      voiceCubit,
      const Stream<VoiceSettings>.empty(),
      initialState: initialVoiceSettings,
    );
    when(
      () => voiceCubit.setSessionLoggingEnabled(any()),
    ).thenAnswer((_) async => true);
    when(() => voiceCubit.setTtsVolume(any())).thenAnswer((_) async => true);

    final AppSettingsState initialState = buildState(
      settings: const AppSettings(
        notificationsEnabled: true,
        weekStartDay: WeekStartDay.monday,
        weightUnit: WeightUnit.kilograms,
      ),
    );

    when(() => cubit.state).thenReturn(initialState);
    whenListen<AppSettingsState>(
      cubit,
      const Stream<AppSettingsState>.empty(),
      initialState: initialState,
    );

    when(() => cubit.ensureLoaded()).thenAnswer((_) async {});
    when(() => cubit.refreshSettings()).thenAnswer((_) async {});
    when(
      () => cubit.setNotificationsEnabled(any()),
    ).thenAnswer((_) async => true);
    when(() => cubit.setWeekStartDay(any())).thenAnswer((_) async => true);
    when(() => cubit.setWeightUnit(any())).thenAnswer((_) async => true);
    when(() => cubit.clearError()).thenReturn(null);
  });

  testWidgets('calls ensureLoaded when page opens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    verify(() => cubit.ensureLoaded()).called(1);
  });

  testWidgets('shows loading state with dedicated loading indicator', (
    WidgetTester tester,
  ) async {
    final AppSettingsState loadingState = buildState(
      isLoading: true,
      hasLoaded: false,
    );

    when(() => cubit.state).thenReturn(loadingState);
    whenListen<AppSettingsState>(
      cubit,
      const Stream<AppSettingsState>.empty(),
      initialState: loadingState,
    );

    await tester.pumpWidget(buildSubject());

    expect(find.byKey(SettingsPage.loadingIndicatorKey), findsOneWidget);
    expect(find.byKey(SettingsPage.refreshListKey), findsNothing);
  });

  testWidgets('renders settings content after load', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.byKey(SettingsPage.notificationsSwitchKey), findsOneWidget);
    expect(find.byKey(SettingsPage.weekStartTileKey), findsOneWidget);
    expect(find.byKey(SettingsPage.weightUnitTileKey), findsOneWidget);
    expect(find.textContaining('Week preview:'), findsOneWidget);
    expect(find.textContaining('Display preview:'), findsOneWidget);
  });

  testWidgets('toggling notifications delegates to cubit', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(SettingsPage.notificationsSwitchKey));
    await tester.pump();

    verify(() => cubit.setNotificationsEnabled(false)).called(1);
  });

  testWidgets(
    'changing week start day delegates to cubit only after selection',
    (WidgetTester tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pump();

      await tester.tap(find.byKey(SettingsPage.weekStartTileKey));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sunday'));
      await tester.pumpAndSettle();

      verify(() => cubit.setWeekStartDay(WeekStartDay.sunday)).called(1);
    },
  );

  testWidgets('selecting current week start day does not delegate again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(SettingsPage.weekStartTileKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.setWeekStartDay(any()));
  });

  testWidgets('changing weight unit delegates to cubit only after selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(SettingsPage.weightUnitTileKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pounds (lb)'));
    await tester.pumpAndSettle();

    verify(() => cubit.setWeightUnit(WeightUnit.pounds)).called(1);
  });

  testWidgets('selecting current weight unit does not delegate again', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.tap(find.byKey(SettingsPage.weightUnitTileKey));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kilograms (kg)'));
    await tester.pumpAndSettle();

    verifyNever(() => cubit.setWeightUnit(any()));
  });

  testWidgets('pull to refresh delegates to refreshSettings', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.drag(
      find.byKey(SettingsPage.refreshListKey),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => cubit.refreshSettings()).called(1);
  });

  testWidgets(
    'saving state disables selection tiles and shows saving indicator',
    (WidgetTester tester) async {
      // Use a tall viewport so that the saving indicator (rendered at the bottom
      // of the list, after the voice section added in C-2) is within Flutter's
      // build cache extent and findable in the widget tree.
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final AppSettingsState savingState = buildState(
        isSaving: true,
        settings: const AppSettings(
          notificationsEnabled: true,
          weekStartDay: WeekStartDay.monday,
          weightUnit: WeightUnit.kilograms,
        ),
      );

      when(() => cubit.state).thenReturn(savingState);
      whenListen<AppSettingsState>(
        cubit,
        const Stream<AppSettingsState>.empty(),
        initialState: savingState,
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      expect(find.byKey(SettingsPage.savingIndicatorKey), findsOneWidget);

      await tester.tap(find.byKey(SettingsPage.weekStartTileKey));
      // pump() instead of pumpAndSettle() — the saving CircularProgressIndicator
      // animates indefinitely, so pumpAndSettle would never resolve. A single
      // pump is enough to flush any tap response; we just need to assert that
      // no bottom sheet opened.
      await tester.pump();

      expect(find.text('Sunday'), findsNothing);
      verifyNever(() => cubit.setWeekStartDay(any()));
    },
  );

  testWidgets('error state shows feature error banner and clears error', (
    WidgetTester tester,
  ) async {
    final AppSettingsState noErrorState = buildState();
    final AppSettingsState errorState = buildState(errorMessage: 'save failed');

    when(() => cubit.state).thenReturn(errorState);
    whenListen<AppSettingsState>(
      cubit,
      Stream<AppSettingsState>.fromIterable(<AppSettingsState>[errorState]),
      initialState: noErrorState,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(SettingsPage.errorBannerKey), findsOneWidget);
    expect(find.text('save failed'), findsWidgets);
    verify(() => cubit.clearError()).called(1);
  });

  testWidgets('hides the username tile for a guest session', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(SettingsPage.usernameTileKey), findsNothing);
  });

  testWidgets('shows the current handle for an authenticated user', (
    WidgetTester tester,
  ) async {
    final ProfileState authed = _authedProfileState();
    when(() => profileCubit.state).thenReturn(authed);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: authed,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.byKey(SettingsPage.usernameTileKey), findsOneWidget);
    expect(find.textContaining('@alice'), findsOneWidget);
  });

  testWidgets('editing to a valid username delegates to ProfileCubit', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProfileState authed = _authedProfileState();
    when(() => profileCubit.state).thenReturn(authed);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: authed,
    );
    when(
      () => profileCubit.updateUsername(any()),
    ).thenAnswer((_) async => true);

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.ensureVisible(find.byKey(SettingsPage.usernameTileKey));
    await tester.tap(find.byKey(SettingsPage.usernameTileKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsPage.usernameDialogFieldKey),
      'alice_2',
    );
    await tester.tap(find.byKey(SettingsPage.usernameDialogSaveKey));
    await tester.pumpAndSettle();

    verify(() => profileCubit.updateUsername('alice_2')).called(1);
    expect(find.text('Username updated.'), findsOneWidget);
  });

  testWidgets('invalid username shows inline error and does not delegate', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ProfileState authed = _authedProfileState();
    when(() => profileCubit.state).thenReturn(authed);
    whenListen<ProfileState>(
      profileCubit,
      const Stream<ProfileState>.empty(),
      initialState: authed,
    );

    await tester.pumpWidget(buildSubject());
    await tester.pump();

    await tester.ensureVisible(find.byKey(SettingsPage.usernameTileKey));
    await tester.tap(find.byKey(SettingsPage.usernameTileKey));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(SettingsPage.usernameDialogFieldKey),
      'ab!',
    );
    await tester.tap(find.byKey(SettingsPage.usernameDialogSaveKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Username may only contain letters, numbers, and underscores.'),
      findsOneWidget,
    );
    verifyNever(() => profileCubit.updateUsername(any()));
  });
}
