import 'package:equatable/equatable.dart';

/// Lightweight profile snapshot used in social lists (followers, following,
/// search results). Does not include mutable fields like bio.
class UserProfileSummary extends Equatable {
  const UserProfileSummary({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  /// The name to display in UI — prefers displayName, falls back to username.
  String get effectiveName => (displayName != null && displayName!.isNotEmpty)
      ? displayName!
      : username;

  @override
  List<Object?> get props => <Object?>[id, username, displayName, avatarUrl];
}
