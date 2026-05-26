class EntitySyncBatchFailure implements Exception {
  final String entityLabel;
  final List<String> failedUpsertEntityIds;
  final List<String> failedDeleteEntityIds;

  const EntitySyncBatchFailure({
    required this.entityLabel,
    this.failedUpsertEntityIds = const <String>[],
    this.failedDeleteEntityIds = const <String>[],
  });

  bool get hasUpsertFailures => failedUpsertEntityIds.isNotEmpty;
  bool get hasDeleteFailures => failedDeleteEntityIds.isNotEmpty;
  bool get hasFailures => hasUpsertFailures || hasDeleteFailures;

  String get message {
    final List<String> parts = <String>[];

    if (hasUpsertFailures) {
      parts.add(
        'failed to upsert ${failedUpsertEntityIds.length} '
        '$entityLabel entr${failedUpsertEntityIds.length == 1 ? 'y' : 'ies'} '
        '(${failedUpsertEntityIds.join(', ')})',
      );
    }

    if (hasDeleteFailures) {
      parts.add(
        'failed to delete ${failedDeleteEntityIds.length} '
        '$entityLabel entr${failedDeleteEntityIds.length == 1 ? 'y' : 'ies'} '
        '(${failedDeleteEntityIds.join(', ')})',
      );
    }

    return parts.join('; ');
  }

  @override
  String toString() => 'EntitySyncBatchFailure($message)';
}
