import '../../core/enums/sync_entity_type.dart';

class EntitySyncDescriptor {
  final SyncEntityType entityType;
  final String operationKey;
  final String entityLabel;

  const EntitySyncDescriptor({
    required this.entityType,
    required this.operationKey,
    required this.entityLabel,
  });
}
