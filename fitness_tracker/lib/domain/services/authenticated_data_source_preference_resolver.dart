import '../../core/enums/data_source_preference.dart';
import '../repositories/app_session_repository.dart';

class AuthenticatedDataSourcePreferenceResolver {
  final AppSessionRepository appSessionRepository;

  const AuthenticatedDataSourcePreferenceResolver({
    required this.appSessionRepository,
  });

  Future<DataSourcePreference> resolveReadPreference() async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    return sessionResult.fold((_) => DataSourcePreference.localOnly, (session) {
      // Remote is not yet usable until the initial cloud migration has
      // completed — the user's local data has not been uploaded and RLS
      // on Supabase will return an empty set (or fail). Serve local-only
      // to avoid a doomed remote round-trip that surfaces as an error.
      if (session.requiresInitialCloudMigration) {
        return DataSourcePreference.localOnly;
      }

      if (appSessionRepository
          .syncPolicy
          .remoteIsSourceOfTruthWhenAuthenticated) {
        return DataSourcePreference.remoteThenLocal;
      }

      return DataSourcePreference.localOnly;
    });
  }
}
