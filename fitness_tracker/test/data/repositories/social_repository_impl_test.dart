import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/data/datasources/remote/social_remote_datasource.dart';
import 'package:fitness_tracker/data/repositories/social_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/follow_counts.dart';
import 'package:fitness_tracker/domain/entities/user_profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSocialRemoteDataSource extends Mock
    implements SocialRemoteDataSource {}

void main() {
  late _MockSocialRemoteDataSource mockRemote;
  late SocialRepositoryImpl sut;

  const String currentUserId = 'me';
  const String targetUserId = 'them';

  final UserProfileSummary summaryA = UserProfileSummary(
    id: 'a',
    username: 'alice',
    displayName: 'Alice',
  );

  setUp(() {
    mockRemote = _MockSocialRemoteDataSource();
    sut = SocialRepositoryImpl(remoteDataSource: mockRemote);
  });

  // ---------------------------------------------------------------------------
  // follow
  // ---------------------------------------------------------------------------
  group('follow', () {
    test('returns Right(void) on success', () async {
      when(() => mockRemote.follow(targetUserId)).thenAnswer((_) async {});

      final result = await sut.follow(targetUserId);

      expect(result.isRight(), isTrue);
      verify(() => mockRemote.follow(targetUserId)).called(1);
    });

    test('returns Left(failure) on AuthSyncException', () async {
      when(
        () => mockRemote.follow(targetUserId),
      ).thenThrow(const AuthSyncException('unauthenticated'));

      final result = await sut.follow(targetUserId);

      expect(result.isLeft(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // unfollow
  // ---------------------------------------------------------------------------
  group('unfollow', () {
    test('returns Right(void) on success', () async {
      when(() => mockRemote.unfollow(targetUserId)).thenAnswer((_) async {});

      final result = await sut.unfollow(targetUserId);

      expect(result.isRight(), isTrue);
    });

    test('returns Left(failure) on NetworkSyncException', () async {
      when(
        () => mockRemote.unfollow(targetUserId),
      ).thenThrow(const NetworkSyncException('offline'));

      final result = await sut.unfollow(targetUserId);

      expect(result.isLeft(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // isFollowing
  // ---------------------------------------------------------------------------
  group('isFollowing', () {
    test('returns Right(true) when following', () async {
      when(
        () => mockRemote.isFollowing(targetUserId),
      ).thenAnswer((_) async => true);

      final result = await sut.isFollowing(targetUserId);

      expect(result, const Right<dynamic, bool>(true));
    });

    test('returns Right(false) when not following', () async {
      when(
        () => mockRemote.isFollowing(targetUserId),
      ).thenAnswer((_) async => false);

      final result = await sut.isFollowing(targetUserId);

      expect(result, const Right<dynamic, bool>(false));
    });
  });

  // ---------------------------------------------------------------------------
  // getFollowers
  // ---------------------------------------------------------------------------
  group('getFollowers', () {
    test('returns Right(list) on success', () async {
      when(
        () => mockRemote.getFollowers(currentUserId),
      ).thenAnswer((_) async => <UserProfileSummary>[summaryA]);

      final result = await sut.getFollowers(currentUserId);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (list) => expect(list, <UserProfileSummary>[summaryA]),
      );
    });

    test('returns Right(empty) when no followers', () async {
      when(
        () => mockRemote.getFollowers(currentUserId),
      ).thenAnswer((_) async => const <UserProfileSummary>[]);

      final result = await sut.getFollowers(currentUserId);

      expect(result, const Right<dynamic, List<UserProfileSummary>>([]));
    });
  });

  // ---------------------------------------------------------------------------
  // getFollowing
  // ---------------------------------------------------------------------------
  group('getFollowing', () {
    test('returns Right(list) on success', () async {
      when(
        () => mockRemote.getFollowing(currentUserId),
      ).thenAnswer((_) async => <UserProfileSummary>[summaryA]);

      final result = await sut.getFollowing(currentUserId);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (list) => expect(list, <UserProfileSummary>[summaryA]),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getFollowCounts
  // ---------------------------------------------------------------------------
  group('getFollowCounts', () {
    test('returns Right(counts) on success', () async {
      const counts = FollowCounts(followerCount: 10, followingCount: 5);
      when(
        () => mockRemote.getFollowCounts(currentUserId),
      ).thenAnswer((_) async => counts);

      final result = await sut.getFollowCounts(currentUserId);

      expect(result, const Right<dynamic, FollowCounts>(counts));
    });

    test('FollowCounts.zero has both counts at zero', () {
      const counts = FollowCounts.zero();
      expect(counts.followerCount, 0);
      expect(counts.followingCount, 0);
    });
  });
}
