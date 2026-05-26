import '../../../domain/entities/user_profile.dart';
import '../../../domain/entities/user_profile_summary.dart';
import 'user_profile_remote_datasource.dart';

class NoopUserProfileRemoteDataSource implements UserProfileRemoteDataSource {
  const NoopUserProfileRemoteDataSource();

  @override
  bool get isConfigured => false;

  @override
  Future<UserProfile?> getProfile(String userId) async => null;

  @override
  Future<UserProfile> upsertProfile(UserProfile profile) {
    throw UnsupportedError(
      'NoopUserProfileRemoteDataSource does not support upsertProfile.',
    );
  }

  @override
  Future<List<UserProfileSummary>> searchByUsername(
    String query, {
    int limit = 20,
  }) async => const <UserProfileSummary>[];
}
