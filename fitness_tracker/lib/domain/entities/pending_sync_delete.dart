import 'package:equatable/equatable.dart';

import '../../core/enums/sync_entity_type.dart';

class PendingSyncDelete extends Equatable {
  final String id;
  final SyncEntityType entityType;
  final String localEntityId;
  final String? serverEntityId;
  final DateTime createdAt;
  final DateTime? lastAttemptAt;
  final String? errorMessage;

  const PendingSyncDelete({
    required this.id,
    required this.entityType,
    required this.localEntityId,
    this.serverEntityId,
    required this.createdAt,
    this.lastAttemptAt,
    this.errorMessage,
  });

  PendingSyncDelete copyWith({
    String? id,
    SyncEntityType? entityType,
    String? localEntityId,
    String? serverEntityId,
    bool clearServerEntityId = false,
    DateTime? createdAt,
    DateTime? lastAttemptAt,
    bool clearLastAttemptAt = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return PendingSyncDelete(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      localEntityId: localEntityId ?? this.localEntityId,
      serverEntityId: clearServerEntityId
          ? null
          : (serverEntityId ?? this.serverEntityId),
      createdAt: createdAt ?? this.createdAt,
      lastAttemptAt: clearLastAttemptAt
          ? null
          : (lastAttemptAt ?? this.lastAttemptAt),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
    id,
    entityType,
    localEntityId,
    serverEntityId,
    createdAt,
    lastAttemptAt,
    errorMessage,
  ];
}
