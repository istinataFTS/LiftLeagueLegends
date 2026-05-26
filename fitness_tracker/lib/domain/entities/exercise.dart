import 'package:equatable/equatable.dart';

import 'entity_sync_metadata.dart';

class Exercise extends Equatable {
  final String id;
  final String? ownerUserId;
  final String name;
  final List<String> muscleGroups;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EntitySyncMetadata syncMetadata;

  const Exercise({
    required this.id,
    this.ownerUserId,
    required this.name,
    required this.muscleGroups,
    required this.createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) : updatedAt = updatedAt ?? createdAt,
       syncMetadata = syncMetadata ?? const EntitySyncMetadata();

  bool get isOwnedByAuthenticatedUser => ownerUserId != null;

  Exercise copyWith({
    String? id,
    String? ownerUserId,
    bool clearOwnerUserId = false,
    String? name,
    List<String>? muscleGroups,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata? syncMetadata,
  }) {
    return Exercise(
      id: id ?? this.id,
      ownerUserId: clearOwnerUserId ? null : (ownerUserId ?? this.ownerUserId),
      name: name ?? this.name,
      muscleGroups: muscleGroups ?? this.muscleGroups,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      syncMetadata: syncMetadata ?? this.syncMetadata,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerUserId,
    name,
    muscleGroups,
    createdAt,
    updatedAt,
    syncMetadata,
  ];
}
