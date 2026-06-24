import 'package:fitness_tracker/config/env_config.dart';
import 'package:flutter_test/flutter_test.dart';

// EnvConfig is built entirely from compile-time String.fromEnvironment constants.
// In the test environment those resolve to the declared defaultValues, which
// represent a valid development build. Tests here verify:
//   (a) the declared defaults form a valid configuration with zero issues, and
//   (b) individual helpers return the values that match those defaults.

void main() {
  group('EnvConfig', () {
    group('getRuntimeConfigIssues', () {
      test('returns no issues for the default development configuration', () {
        final issues = EnvConfig.getRuntimeConfigIssues();

        expect(
          issues,
          isEmpty,
          reason:
              'Default compile-time values must represent a valid development '
              'configuration so the app starts cleanly in CI and local builds.',
        );
      });

      test(
        'ensureValidRuntimeConfig does not throw for default configuration',
        () {
          expect(EnvConfig.ensureValidRuntimeConfig, returnsNormally);
        },
      );
    });

    group('environment', () {
      test('exactly one environment flag is active', () {
        final activeCount = [
          EnvConfig.isDevelopment,
          EnvConfig.isStaging,
          EnvConfig.isProduction,
        ].where((flag) => flag).length;

        expect(
          activeCount,
          1,
          reason:
              'Exactly one of isDevelopment / isStaging / isProduction must be '
              'true. Overlapping or missing environment flags indicate a broken '
              'ENVIRONMENT value.',
        );
      });

      test('default build is development', () {
        expect(EnvConfig.isDevelopment, isTrue);
        expect(EnvConfig.isStaging, isFalse);
        expect(EnvConfig.isProduction, isFalse);
      });
    });

    group('Supabase', () {
      test('Supabase is enabled by default with production credentials', () {
        // Production URL and ANON key are baked in as defaults so that any
        // fork build connects to the shared backend without configuration.
        // The ANON key is public by design (Supabase client-side key);
        // RLS enforces per-user data isolation server-side.
        expect(EnvConfig.enableSupabase, isTrue);
        expect(EnvConfig.supabaseUrl, isNotEmpty);
        expect(EnvConfig.supabaseAnonKey, isNotEmpty);
        expect(EnvConfig.isSupabaseConfigured, isTrue);
      });
    });

    group('database', () {
      test('databaseVersion is a positive integer', () {
        expect(EnvConfig.databaseVersion, greaterThan(0));
      });

      test('databaseName is non-empty', () {
        expect(EnvConfig.databaseName.trim(), isNotEmpty);
      });
    });

    group('production safety', () {
      test('forceReseed is false by default', () {
        // forceReseed=true in production would wipe user data on every launch.
        expect(EnvConfig.forceReseed, isFalse);
      });
    });
  });
}
