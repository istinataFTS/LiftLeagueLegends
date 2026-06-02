import '../../../core/utils/date_serialization.dart';
import '../../../domain/entities/user_profile.dart';

class SupabaseUserProfileDto {
  const SupabaseUserProfileDto({
    required this.id,
    required this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupabaseUserProfileDto.fromMap(Map<String, dynamic> map) {
    return SupabaseUserProfileDto(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String?,
      bio: map['bio'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: parseStorageDate(map['created_at'] as String),
      updatedAt: parseStorageDate(map['updated_at'] as String),
    );
  }

  factory SupabaseUserProfileDto.fromEntity(UserProfile entity) {
    return SupabaseUserProfileDto(
      id: entity.id,
      username: entity.username,
      displayName: entity.displayName,
      bio: entity.bio,
      avatarUrl: entity.avatarUrl,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  UserProfile toEntity() {
    return UserProfile(
      id: id,
      username: username,
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'username': username,
      'display_name': displayName,
      'bio': bio,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toStorageIso(),
      'updated_at': updatedAt.toStorageIso(),
    };
  }
}
