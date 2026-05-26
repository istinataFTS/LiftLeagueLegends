import 'package:equatable/equatable.dart';

import '../../core/enums/sync_status.dart';

class EntitySyncMetadata extends Equatable {
  final String? serverId;
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? lastSyncError;

  const EntitySyncMetadata({
    this.serverId,
    this.status = SyncStatus.localOnly,
    this.lastSyncedAt,
    this.lastSyncError,
  });

  bool get isSynced => status == SyncStatus.synced;

  bool get isPendingDelete => status == SyncStatus.pendingDelete;

  bool get hasPendingSync =>
      status == SyncStatus.pendingUpload ||
      status == SyncStatus.pendingUpdate ||
      status == SyncStatus.pendingDelete;

  EntitySyncMetadata copyWith({
    String? serverId,
    bool clearServerId = false,
    SyncStatus? status,
    DateTime? lastSyncedAt,
    bool clearLastSyncedAt = false,
    String? lastSyncError,
    bool clearLastSyncError = false,
  }) {
    return EntitySyncMetadata(
      serverId: clearServerId ? null : (serverId ?? this.serverId),
      status: status ?? this.status,
      lastSyncedAt: clearLastSyncedAt
          ? null
          : (lastSyncedAt ?? this.lastSyncedAt),
      lastSyncError: clearLastSyncError
          ? null
          : (lastSyncError ?? this.lastSyncError),
    );
  }

  @override
  List<Object?> get props => [serverId, status, lastSyncedAt, lastSyncError];
}
