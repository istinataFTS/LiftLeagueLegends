import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/ui/keypad_visibility_controller.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/services/voice_media_button_service.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:fitness_tracker/features/voice/presentation/widgets/voice_fab.dart';
import 'package:fitness_tracker/injection/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

class FakeVoiceMediaButtonService implements VoiceMediaButtonService {
  bool _running = false;
  final _pressController = StreamController<void>.broadcast();

  @override
  Stream<void> get onMediaButtonPressed => _pressController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start() async => _running = true;

  @override
  Future<void> stop() async => _running = false;

  void emitPress() => _pressController.add(null);

  Future<void> dispose() => _pressController.close();
}

class FakeVoiceWakeWordService implements VoiceWakeWordService {
  bool _running = false;
  final _detectedController = StreamController<WakeWordPreset>.broadcast();
  final _errorController = StreamController<VoiceWakeWordException>.broadcast();
  final List<WakeWordPreset> startedPresets = [];

  @override
  Stream<WakeWordPreset> get onWakeWordDetected => _detectedController.stream;

  @override
  Stream<VoiceWakeWordException> get onError => _errorController.stream;

  @override
  bool get isRunning => _running;

  @override
  Future<void> start(WakeWordPreset preset) async {
    _running = true;
    startedPresets.add(preset);
  }

  @override
  Future<void> stop() async => _running = false;

  @override
  Future<void> dispose() async {
    await _detectedController.close();
    await _errorController.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _authSession = AppSession(
  user: AppUser(id: 'test-user', email: 'user@test.local'),
);

Widget _wrap({
  required AppSession session,
  required VoiceSettingsCubit settingsCubit,
}) {
  // [VoiceFab] reads [VoiceWakeWordService] from the GetIt container in
  // initState; tests register their fake before pumping.
  return MaterialApp(
    home: Scaffold(
      floatingActionButton: BlocProvider<VoiceSettingsCubit>.value(
        value: settingsCubit,
        child: VoiceFab(session: session),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockVoiceSettingsCubit settingsCubit;
  late FakeVoiceWakeWordService wakeWordService;
  late FakeVoiceMediaButtonService mediaButtonService;
  late KeypadVisibilityController keypadVisibility;

  final defaultSettings = const VoiceSettings.defaults();

  setUp(() {
    settingsCubit = MockVoiceSettingsCubit();
    wakeWordService = FakeVoiceWakeWordService();
    mediaButtonService = FakeVoiceMediaButtonService();
    keypadVisibility = KeypadVisibilityController();

    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    if (sl.isRegistered<KeypadVisibilityController>()) {
      sl.unregister<KeypadVisibilityController>();
    }
    sl.registerSingleton<VoiceWakeWordService>(wakeWordService);
    sl.registerSingleton<VoiceMediaButtonService>(mediaButtonService);
    sl.registerSingleton<KeypadVisibilityController>(keypadVisibility);

    when(() => settingsCubit.state).thenReturn(defaultSettings);
    when(() => settingsCubit.ready).thenAnswer((_) => Future.value());
    whenListen(
      settingsCubit,
      Stream<VoiceSettings>.empty(),
      initialState: defaultSettings,
    );
  });

  tearDown(() async {
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    if (sl.isRegistered<VoiceMediaButtonService>()) {
      sl.unregister<VoiceMediaButtonService>();
    }
    if (sl.isRegistered<KeypadVisibilityController>()) {
      sl.unregister<KeypadVisibilityController>();
    }
    await wakeWordService.dispose();
    await mediaButtonService.dispose();
  });

  group('VoiceFab — authenticated user', () {
    testWidgets('renders FAB widget', (tester) async {
      await tester.pumpWidget(
        _wrap(session: _authSession, settingsCubit: settingsCubit),
      );
      expect(find.byType(VoiceFab), findsOneWidget);
    });

    testWidgets('FAB is enabled (has onPressed)', (tester) async {
      await tester.pumpWidget(
        _wrap(session: _authSession, settingsCubit: settingsCubit),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
    });

    testWidgets('shows open tooltip for authenticated session', (tester) async {
      await tester.pumpWidget(
        _wrap(session: _authSession, settingsCubit: settingsCubit),
      );
      expect(find.byTooltip(AppStrings.voiceFabTooltipOpen), findsOneWidget);
    });

    testWidgets(
      'start() called exactly once with persisted preset (not defaults) on mount',
      (tester) async {
        const persistedSettings = VoiceSettings(
          wakeWordPreset: WakeWordPreset.trainer,
        );
        when(() => settingsCubit.state).thenReturn(persistedSettings);
        when(() => settingsCubit.ready).thenAnswer((_) => Future.value());
        whenListen(
          settingsCubit,
          Stream<VoiceSettings>.empty(),
          initialState: persistedSettings,
        );

        await tester.pumpWidget(
          _wrap(session: _authSession, settingsCubit: settingsCubit),
        );
        // Let the unawaited _startWakeWordIfArmed future complete.
        await tester.pump();

        expect(wakeWordService.startedPresets, hasLength(1));
        expect(wakeWordService.startedPresets.single, WakeWordPreset.trainer);
      },
    );
  });

  group('VoiceFab — keypad visibility', () {
    testWidgets('FAB hides while KeypadVisibilityController.isOpen is true and '
        'reappears on hide()', (tester) async {
      await tester.pumpWidget(
        _wrap(session: _authSession, settingsCubit: settingsCubit),
      );
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      keypadVisibility.show();
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);

      keypadVisibility.hide();
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });

  // Guest-mode coverage removed: the FAB is only reachable above the auth
  // gate, so there is no "disabled for guests" branch left in the widget.
  // See `KNOWN_ISSUES.md#guest-catalog-pk-collision-blocks-initial-sign-in`.
}
