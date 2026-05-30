import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/services/voice_credential_service.dart';
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

class FakeVoiceWakeWordService implements VoiceWakeWordService {
  bool _running = false;
  final _detectedController = StreamController<WakeWordPreset>.broadcast();
  final _errorController = StreamController<VoiceWakeWordException>.broadcast();

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

/// Minimal in-memory [VoiceCredentialService] for FAB tests.
///
/// Exposes [emitKeyChange] so tests can simulate the credential change event
/// that the bootstrap seeder fires after writing the Picovoice key.
class FakeVoiceCredentialService implements VoiceCredentialService {
  FakeVoiceCredentialService();

  final _keyChangedController = StreamController<void>.broadcast(sync: true);

  @override
  Stream<void> get onPicovoiceKeyChanged => _keyChangedController.stream;

  /// Simulates the credential seeder writing a new key.
  void emitKeyChange() => _keyChangedController.add(null);

  @override
  Future<String?> getPicovoiceAccessKey() async => null;

  @override
  Future<void> setPicovoiceAccessKey(String key) async {}

  @override
  Future<void> clearPicovoiceAccessKey() async {}

  @override
  Future<bool> hasPicovoiceAccessKey() async => false;

  @override
  Future<bool> isWakeWordConfigured() async => false;

  @override
  Future<void> dispose() => _keyChangedController.close();
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
  // [VoiceFab] reads [VoiceWakeWordService] and [VoiceCredentialService] from
  // the GetIt container in initState; tests register their fakes before
  // pumping. The cubit is resolved via [BlocProvider.value].
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
  late FakeVoiceCredentialService credentialService;

  final defaultSettings = const VoiceSettings.defaults();

  setUp(() {
    settingsCubit = MockVoiceSettingsCubit();
    wakeWordService = FakeVoiceWakeWordService();
    credentialService = FakeVoiceCredentialService();

    // Reset the container and register both fakes so the widget sees them.
    if (sl.isRegistered<VoiceWakeWordService>()) {
      sl.unregister<VoiceWakeWordService>();
    }
    sl.registerSingleton<VoiceWakeWordService>(wakeWordService);

    if (sl.isRegistered<VoiceCredentialService>()) {
      sl.unregister<VoiceCredentialService>();
    }
    sl.registerSingleton<VoiceCredentialService>(credentialService);

    when(() => settingsCubit.state).thenReturn(defaultSettings);
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
    if (sl.isRegistered<VoiceCredentialService>()) {
      sl.unregister<VoiceCredentialService>();
    }
    await credentialService.dispose();
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

    testWidgets('does not show guest tooltip text', (tester) async {
      await tester.pumpWidget(
        _wrap(session: _authSession, settingsCubit: settingsCubit),
      );
      expect(find.text(AppStrings.voiceFabTooltipGuest), findsNothing);
    });

    testWidgets(
      'attempts to start wake word when credential change event fires',
      (tester) async {
        await tester.pumpWidget(
          _wrap(session: _authSession, settingsCubit: settingsCubit),
        );

        // Simulate the bootstrap seeder writing the Picovoice key.
        credentialService.emitKeyChange();
        await tester.pump();

        // _startWakeWordIfArmed was called again — service is running.
        expect(wakeWordService.isRunning, isTrue);
      },
    );
  });

  // Guest-mode coverage removed: the FAB is only reachable above the auth
  // gate, so there is no "disabled for guests" branch left in the widget.
  // See `KNOWN_ISSUES.md#guest-catalog-pk-collision-blocks-initial-sign-in`.
}
