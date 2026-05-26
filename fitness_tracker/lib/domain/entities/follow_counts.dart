import 'package:equatable/equatable.dart';

/// Aggregated follower / following counts for a user profile.
class FollowCounts extends Equatable {
  const FollowCounts({
    required this.followerCount,
    required this.followingCount,
  });

  const FollowCounts.zero() : followerCount = 0, followingCount = 0;

  final int followerCount;
  final int followingCount;

  @override
  List<Object?> get props => <Object?>[followerCount, followingCount];
}
