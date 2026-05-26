import '../../../core/errors/sync_exceptions.dart';
import '../../../domain/entities/follow_counts.dart';
import '../../../domain/entities/user_profile_summary.dart';
import '../../dtos/supabase/supabase_user_profile_summary_dto.dart';
import 'remote_datasource_guard.dart';
import 'social_remote_datasource.dart';
import 'supabase_client_provider.dart';

class SupabaseSocialRemoteDataSource implements SocialRemoteDataSource {
  static const String _followsTable = 'follows';
  static const String _profilesTable = 'user_profiles';

  const SupabaseSocialRemoteDataSource({required this.clientProvider});

  final SupabaseClientProvider clientProvider;

  @override
  bool get isConfigured => clientProvider.isConfigured;

  @override
  Future<void> follow(String targetUserId) {
    return RemoteDatasourceGuard.run(() async {
      final currentId = _requireCurrentUserId();

      await clientProvider.client.from(_followsTable).insert(<String, dynamic>{
        'follower_id': currentId,
        'following_id': targetUserId,
      });
    });
  }

  @override
  Future<void> unfollow(String targetUserId) {
    return RemoteDatasourceGuard.run(() async {
      final currentId = _requireCurrentUserId();

      await clientProvider.client
          .from(_followsTable)
          .delete()
          .eq('follower_id', currentId)
          .eq('following_id', targetUserId);
    });
  }

  @override
  Future<bool> isFollowing(String targetUserId) {
    return RemoteDatasourceGuard.run(() async {
      final currentId = _requireCurrentUserId();

      final dynamic data = await clientProvider.client
          .from(_followsTable)
          .select()
          .eq('follower_id', currentId)
          .eq('following_id', targetUserId)
          .maybeSingle();

      return data != null;
    });
  }

  @override
  Future<List<UserProfileSummary>> getFollowers(String userId) {
    return RemoteDatasourceGuard.run(() async {
      final dynamic followsData = await clientProvider.client
          .from(_followsTable)
          .select('follower_id')
          .eq('following_id', userId);

      final followerIds = _extractIds(followsData, 'follower_id');
      if (followerIds.isEmpty) return const <UserProfileSummary>[];

      return _fetchSummaries(followerIds);
    });
  }

  @override
  Future<List<UserProfileSummary>> getFollowing(String userId) {
    return RemoteDatasourceGuard.run(() async {
      final dynamic followsData = await clientProvider.client
          .from(_followsTable)
          .select('following_id')
          .eq('follower_id', userId);

      final followingIds = _extractIds(followsData, 'following_id');
      if (followingIds.isEmpty) return const <UserProfileSummary>[];

      return _fetchSummaries(followingIds);
    });
  }

  @override
  Future<FollowCounts> getFollowCounts(String userId) {
    return RemoteDatasourceGuard.run(() async {
      final dynamic followersData = await clientProvider.client
          .from(_followsTable)
          .select('follower_id')
          .eq('following_id', userId);

      final dynamic followingData = await clientProvider.client
          .from(_followsTable)
          .select('following_id')
          .eq('follower_id', userId);

      return FollowCounts(
        followerCount: (followersData as List<dynamic>).length,
        followingCount: (followingData as List<dynamic>).length,
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _requireCurrentUserId() {
    final id = clientProvider.client.auth.currentUser?.id;
    if (id == null || id.isEmpty) {
      throw const AuthSyncException(
        'unauthenticated: social operations require an authenticated user',
      );
    }
    return id;
  }

  List<String> _extractIds(dynamic data, String column) {
    return (data as List<dynamic>)
        .map(
          (dynamic row) =>
              (Map<String, dynamic>.from(row as Map))[column] as String,
        )
        .toList();
  }

  Future<List<UserProfileSummary>> _fetchSummaries(List<String> userIds) async {
    final dynamic data = await clientProvider.client
        .from(_profilesTable)
        .select('id, username, display_name, avatar_url')
        .inFilter('id', userIds);

    return (data as List<dynamic>)
        .map(
          (dynamic row) => SupabaseUserProfileSummaryDto.fromMap(
            Map<String, dynamic>.from(row as Map),
          ).toEntity(),
        )
        .toList();
  }
}
