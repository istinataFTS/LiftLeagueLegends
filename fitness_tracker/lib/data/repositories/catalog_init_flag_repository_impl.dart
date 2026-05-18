import '../../data/datasources/local/app_metadata_local_datasource.dart';
import '../../domain/repositories/catalog_init_flag_repository.dart';

class CatalogInitFlagRepositoryImpl implements CatalogInitFlagRepository {
  const CatalogInitFlagRepositoryImpl(this._metadata);

  final AppMetadataLocalDataSource _metadata;

  static String _key(String ownerUserId, String catalogType) =>
      'catalog_init_${catalogType}_$ownerUserId';

  @override
  Future<bool> isInitialized(String ownerUserId, String catalogType) async {
    return await _metadata.readBool(_key(ownerUserId, catalogType)) == true;
  }

  @override
  Future<void> markInitialized(String ownerUserId, String catalogType) async {
    await _metadata.writeBool(_key(ownerUserId, catalogType), true);
  }
}
