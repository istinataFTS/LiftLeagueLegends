import '../../core/constants/database_tables.dart';
import '../../domain/repositories/stimulus_rebuild_flag_repository.dart';
import '../datasources/local/app_metadata_local_datasource.dart';

class StimulusRebuildFlagRepositoryImpl
    implements StimulusRebuildFlagRepository {
  const StimulusRebuildFlagRepositoryImpl(this._metadata);

  final AppMetadataLocalDataSource _metadata;

  @override
  Future<bool> isPending() async {
    return await _metadata.readBool(
          DatabaseTables.metadataPendingStimulusRebuild,
        ) ==
        true;
  }

  @override
  Future<void> clear() {
    return _metadata.delete(DatabaseTables.metadataPendingStimulusRebuild);
  }
}
