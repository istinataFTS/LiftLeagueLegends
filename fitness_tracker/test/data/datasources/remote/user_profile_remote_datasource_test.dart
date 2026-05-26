import 'package:fitness_tracker/data/datasources/remote/noop_user_profile_remote_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_user_profile_remote_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_client_provider.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSupabaseClientProvider extends Mock
    implements SupabaseClientProvider {}

void main() {
  // ---------------------------------------------------------------------------
  // NoopUserProfileRemoteDataSource
  // ---------------------------------------------------------------------------
  group('NoopUserProfileRemoteDataSource', () {
    late NoopUserProfileRemoteDataSource sut;

    setUp(() => sut = const NoopUserProfileRemoteDataSource());

    test('isConfigured is false', () => expect(sut.isConfigured, isFalse));

    test('getProfile returns null', () async {
      expect(await sut.getProfile('any-id'), isNull);
    });

    test('upsertProfile throws UnsupportedError', () async {
      final profile = _testProfile();
      expect(() => sut.upsertProfile(profile), throwsUnsupportedError);
    });
  });

  // ---------------------------------------------------------------------------
  // SupabaseUserProfileRemoteDataSource — isConfigured propagation
  // ---------------------------------------------------------------------------
  group('SupabaseUserProfileRemoteDataSource.isConfigured', () {
    test('mirrors clientProvider.isConfigured when false', () {
      final provider = _MockSupabaseClientProvider();
      when(() => provider.isConfigured).thenReturn(false);

      final sut = SupabaseUserProfileRemoteDataSource(clientProvider: provider);

      expect(sut.isConfigured, isFalse);
    });

    test('mirrors clientProvider.isConfigured when true', () {
      final provider = _MockSupabaseClientProvider();
      when(() => provider.isConfigured).thenReturn(true);

      final sut = SupabaseUserProfileRemoteDataSource(clientProvider: provider);

      expect(sut.isConfigured, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // SupabaseUserProfileRemoteDataSource — getProfile when not configured
  // ---------------------------------------------------------------------------
  group('SupabaseUserProfileRemoteDataSource.getProfile unconfigured', () {
    test('returns null when not configured', () async {
      final provider = _MockSupabaseClientProvider();
      when(() => provider.isConfigured).thenReturn(false);

      final sut = SupabaseUserProfileRemoteDataSource(clientProvider: provider);

      expect(await sut.getProfile('any-id'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // SupabaseUserProfileRemoteDataSource — upsertProfile when not configured
  // ---------------------------------------------------------------------------
  group('SupabaseUserProfileRemoteDataSource.upsertProfile unconfigured', () {
    test('throws RemoteSyncException when not configured', () async {
      final provider = _MockSupabaseClientProvider();
      when(() => provider.isConfigured).thenReturn(false);

      final sut = SupabaseUserProfileRemoteDataSource(clientProvider: provider);

      expect(
        () => sut.upsertProfile(_testProfile()),
        throwsA(isA<RemoteSyncException>()),
      );
    });
  });
}

UserProfile _testProfile() {
  final now = DateTime(2025, 1, 1);
  return UserProfile(
    id: 'user-1',
    username: 'testuser',
    displayName: 'Test User',
    createdAt: now,
    updatedAt: now,
  );
}
