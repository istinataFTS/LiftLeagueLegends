import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/data/datasources/remote/user_profile_remote_datasource.dart';
import 'package:fitness_tracker/data/repositories/user_profile_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserProfileRemoteDataSource extends Mock
    implements UserProfileRemoteDataSource {}

void main() {
  late _MockUserProfileRemoteDataSource mockRemote;
  late UserProfileRepositoryImpl sut;

  setUp(() {
    mockRemote = _MockUserProfileRemoteDataSource();
    sut = UserProfileRepositoryImpl(remoteDataSource: mockRemote);
  });

  final UserProfile profile = UserProfile(
    id: 'user-1',
    username: 'alice',
    displayName: 'Alice',
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  // ---------------------------------------------------------------------------
  // getProfile
  // ---------------------------------------------------------------------------
  group('getProfile', () {
    test('returns Right(profile) when datasource returns a profile', () async {
      when(
        () => mockRemote.getProfile('user-1'),
      ).thenAnswer((_) async => profile);

      final result = await sut.getProfile('user-1');

      expect(result, Right<dynamic, UserProfile?>(profile));
    });

    test('returns Right(null) when datasource returns null', () async {
      when(() => mockRemote.getProfile('user-1')).thenAnswer((_) async => null);

      final result = await sut.getProfile('user-1');

      expect(result, const Right<dynamic, UserProfile?>(null));
    });

    test(
      'returns Left(failure) when datasource throws a sync exception',
      () async {
        when(
          () => mockRemote.getProfile('user-1'),
        ).thenThrow(const NetworkSyncException('offline'));

        final result = await sut.getProfile('user-1');

        expect(result.isLeft(), isTrue);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // upsertProfile
  // ---------------------------------------------------------------------------
  group('upsertProfile', () {
    test(
      'returns Right(profile) when datasource upserts successfully',
      () async {
        when(
          () => mockRemote.upsertProfile(profile),
        ).thenAnswer((_) async => profile);

        final result = await sut.upsertProfile(profile);

        expect(result, Right<dynamic, UserProfile>(profile));
      },
    );

    test('returns Left(failure) on AuthSyncException', () async {
      when(
        () => mockRemote.upsertProfile(profile),
      ).thenThrow(const AuthSyncException('unauthenticated'));

      final result = await sut.upsertProfile(profile);

      expect(result.isLeft(), isTrue);
    });

    test('returns Left(failure) on RemoteSyncException', () async {
      when(
        () => mockRemote.upsertProfile(profile),
      ).thenThrow(const RemoteSyncException('server error'));

      final result = await sut.upsertProfile(profile);

      expect(result.isLeft(), isTrue);
    });
  });
}
