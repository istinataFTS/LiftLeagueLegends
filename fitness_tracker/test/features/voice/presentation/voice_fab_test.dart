import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:fitness_tracker/domain/services/voice_wake_word_service.dart';
import 'package:fitness_tracker/features/voice/presentation/widgets/voice_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

class FakeVoiceWakeWordService implements VoiceWakeWordService {
  bool _running = false;
  final _detectedController =
      StreamController<WakeWordPreset>.broadcast();
  final _errorController =
      StreamController<VoiceWakeWordException>.broadcast();

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
// Helpers
// ---------------------------------------------------------------------------

const _authSession = AppSession(
  user: null,
  authMode: AuthMode.authenticated,
);

const _guestSession = AppSession.guest();

Widget _wrap({
  required AppSession session,
  required VoiceSettingsCubit settingsCubit,
  required VoiceWakeWordService wakeWordService,
}) {
  return MaterialApp(
    home: Scaffold(
      floatingActionButton: BlocProvider<VoiceSettingsCubit>.value(
        value: settingsCubit,
        child: VoiceFab(
          session: session,
          wakeWordService: wakeWordService,
          settingsCubit: settingsCubit,
        ),
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

  final defaultSettings = const VoiceSettings.defaults();

  setUp(() {
    settingsCubit = MockVoiceSettingsCubit();
    wakeWordService = FakeVoiceWakeWordService();

    when(() => settingsCubit.state).thenReturn(defaultSettings);
    whenListen(
      settingsCubit,
      Stream<VoiceSettings>.empty(),
      initialState: defaultSettings,
    );
  });

  group('VoiceFab — authenticated user', () {
    testWidgets('renders FAB widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _authSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );
      expect(find.byType(VoiceFab), findsOneWidget);
    });

    testWidgets('FAB is enabled (has onPressed)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _authSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNotNull);
    });

    testWidgets('does not show guest tooltip text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _authSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );
      expect(find.text(AppStrings.voiceFabTooltipGuest), findsNothing);
    });
  });

  group('VoiceFab — guest user', () {
    testWidgets('renders FAB widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _guestSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );
      expect(find.byType(VoiceFab), findsOneWidget);
    });

    testWidgets('FAB is disabled for guests (onPressed is null)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _guestSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.onPressed, isNull);
    });

    testWidgets('guest tooltip text is present in widget tree', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _guestSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );

      // Long-press to reveal tooltip.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(FloatingActionButton)),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(AppStrings.voiceFabTooltipGuest), findsOneWidget);
      await gesture.up();
    });

    testWidgets('wake-word service is NOT started for guests', (tester) async {
      await tester.pumpWidget(
        _wrap(
          session: _guestSession,
          settingsCubit: settingsCubit,
          wakeWordService: wakeWordService,
        ),
      );
      await tester.pump();
      expect(wakeWordService.isRunning, isFalse);
    });
  });
}
