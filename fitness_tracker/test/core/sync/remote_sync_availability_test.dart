import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/core/enums/sync_trigger.dart';
import 'package:fitness_tracker/core/network/network_status_service.dart';
import 'package:fitness_tracker/core/sync/remote_sync_availability.dart';
import 'package:fitness_tracker/core/sync/remote_sync_runtime_policy.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockNetworkStatusService extends Mock implements NetworkStatusService {}

void main() {
  late MockNetworkStatusService networkStatusService;

  AppSession authenticatedSession({
    bool requiresInitialCloudMigration = false,
  }) {
    return AppSession(
      authMode: AuthMode.authenticated,
      user: const AppUser(id: 'user-1', email: 'user@test.com'),
      requiresInitialCloudMigration: requiresInitialCloudMigration,
    );
  }

  setUp(() {
    networkStatusService = MockNetworkStatusService();

    when(
      () => networkStatusService.isNetworkAvailable(),
    ).thenAnswer((_) async => true);
  });

  test('denies when remote sync runtime policy is not configured', () async {
    final availability = RemoteSyncAvailability(
      runtimePolicy: RemoteSyncRuntimePolicy(
        isSupabaseEnabled: false,
        supabaseUrl: '',
        supabaseAnonKey: '',
      ),
      networkStatusService: MockNetworkStatusService(),
    );

    final result = await availability.evaluate(
      session: authenticatedSession(),
      trigger: SyncTrigger.appLaunch,
    );

    expect(result.isAllowed, isFalse);
    expect(result.reason, 'remote backend not configured');
  });

  test('denies when network is unavailable', () async {
    when(
      () => networkStatusService.isNetworkAvailable(),
    ).thenAnswer((_) async => false);

    final availability = RemoteSyncAvailability(
      runtimePolicy: const RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      networkStatusService: networkStatusService,
    );

    final result = await availability.evaluate(
      session: authenticatedSession(),
      trigger: SyncTrigger.appLaunch,
    );

    expect(result.isAllowed, isFalse);
    expect(result.reason, 'network unavailable');
  });

  test('denies when session is not authenticated', () async {
    final availability = RemoteSyncAvailability(
      runtimePolicy: const RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      networkStatusService: networkStatusService,
    );

    final result = await availability.evaluate(
      session: const AppSession.guest(),
      trigger: SyncTrigger.appLaunch,
    );

    expect(result.isAllowed, isFalse);
    expect(result.reason, 'session is not authenticated');
  });

  test(
    'denies non-initial-sign-in triggers while migration is pending',
    () async {
      final availability = RemoteSyncAvailability(
        runtimePolicy: const RemoteSyncRuntimePolicy(
          isSupabaseEnabled: true,
          supabaseUrl: 'https://example.supabase.co',
          supabaseAnonKey: 'anon-key',
        ),
        networkStatusService: networkStatusService,
      );

      final result = await availability.evaluate(
        session: authenticatedSession(requiresInitialCloudMigration: true),
        trigger: SyncTrigger.appResume,
      );

      expect(result.isAllowed, isFalse);
      expect(result.reason, 'initial cloud migration is pending');
    },
  );

  test('allows initial sign-in while migration is pending', () async {
    final availability = RemoteSyncAvailability(
      runtimePolicy: const RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      ),
      networkStatusService: networkStatusService,
    );

    final result = await availability.evaluate(
      session: authenticatedSession(requiresInitialCloudMigration: true),
      trigger: SyncTrigger.initialSignIn,
    );

    expect(result.isAllowed, isTrue);
    expect(result.reason, 'remote sync allowed');
  });

  group('RemoteSyncRuntimePolicy.isRemoteSyncConfigured', () {
    test('returns false when Supabase is disabled', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: false,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );

      expect(policy.isRemoteSyncConfigured, isFalse);
    });

    test('returns false when url is empty', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: '',
        supabaseAnonKey: 'anon-key',
      );

      expect(policy.isRemoteSyncConfigured, isFalse);
    });

    test('returns false when url is whitespace only', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: '   ',
        supabaseAnonKey: 'anon-key',
      );

      expect(policy.isRemoteSyncConfigured, isFalse);
    });

    test('returns false when anon key is empty', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
      );

      expect(policy.isRemoteSyncConfigured, isFalse);
    });

    test('returns false when anon key is whitespace only', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '   ',
      );

      expect(policy.isRemoteSyncConfigured, isFalse);
    });

    test('returns true when enabled with non-empty url and key', () {
      const policy = RemoteSyncRuntimePolicy(
        isSupabaseEnabled: true,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
      );

      expect(policy.isRemoteSyncConfigured, isTrue);
    });
  });
}
