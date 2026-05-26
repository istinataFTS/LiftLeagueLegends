import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tool/check_state_freshness.dart';
import '../../tool/convention_rules/shared.dart';

// ---------------------------------------------------------------------------
// Fingerprint helper (mirrors StateFreshnessChecker._computeFeatureFingerprint
// and _computeTopLevelFingerprint exactly — used to pre-compute values for the
// pass-case fixture without needing to expose internals).
// ---------------------------------------------------------------------------

String _fp(Map<String, dynamic> inputs) {
  final encoded = jsonEncode(inputs);
  final digest = sha256.convert(utf8.encode(encoded));
  return digest.toString().substring(0, 16);
}

/// Builds the per-feature fingerprint map entry from raw sorted components,
/// matching StateFreshnessChecker._computeFeatureFingerprint exactly.
String _featureFp({
  required List<String> files,
  required List<String> classes,
  required List<String> repositories,
  required List<String> useCases,
  required List<String> injectionModule,
  required List<String> tables,
}) {
  return _fp({
    'files': (List<String>.from(files))..sort(),
    'classes': (List<String>.from(classes))..sort(),
    'repositories': (List<String>.from(repositories))..sort(),
    'useCases': (List<String>.from(useCases))..sort(),
    'injectionModule': (List<String>.from(injectionModule))..sort(),
    'tables': (List<String>.from(tables))..sort(),
  });
}

String _topFp(Map<String, String> featureFps) {
  final sorted = Map.fromEntries(
    featureFps.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
  return _fp(sorted);
}

// ---------------------------------------------------------------------------
// Minimal fixture helpers
// ---------------------------------------------------------------------------

/// Builds a complete, valid FakeRepoView for the pass-case test.
/// Eight features, one source file each, matching fingerprints.
(FakeRepoView, String) _buildPassRepo() {
  // ── Source files ──────────────────────────────────────────────────────────
  final sourceFiles = <String, String>{
    'lib/features/auth/application/sign_in_cubit.dart':
        'class SignInCubit extends Cubit<SignInState> {}\n'
        'class SignUpCubit extends Cubit<SignUpState> {}\n'
        'class OtpVerificationCubit extends Cubit<OtpState> {}\n',
    'lib/features/history/presentation/bloc/history_bloc.dart':
        'class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {}\n',
    'lib/features/home/application/home_bloc.dart':
        'class HomeBloc extends Bloc<HomeEvent, HomeState> {}\n'
        'class MuscleVisualBloc extends Bloc<MuscleVisualEvent, MuscleVisualState> {}\n',
    'lib/features/library/application/exercise_bloc.dart':
        'class ExerciseBloc extends Bloc<ExerciseEvent, ExerciseState> {}\n'
        'class MealBloc extends Bloc<MealEvent, MealState> {}\n',
    'lib/features/log/application/workout_bloc.dart':
        'class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {}\n'
        'class NutritionLogBloc extends Bloc<NutritionLogEvent, NutritionLogState> {}\n',
    'lib/features/profile/application/profile_cubit.dart':
        'class ProfileCubit extends Cubit<ProfileState> {}\n',
    'lib/features/settings/application/app_settings_cubit.dart':
        'class AppSettingsCubit extends Cubit<AppSettingsState> {}\n',
    'lib/features/voice/application/voice_bloc.dart':
        'class VoiceBloc extends Bloc<VoiceEvent, VoiceState> {}\n'
        'class VoiceSettingsCubit extends Cubit<VoiceSettings> {}\n',
    // Repo / use-case / module stubs (existence-checked, content ignored)
    'lib/domain/repositories/app_session_repository.dart': '// stub\n',
    'lib/domain/repositories/exercise_repository.dart': '// stub\n',
    'lib/domain/repositories/meal_repository.dart': '// stub\n',
    'lib/domain/repositories/muscle_factor_repository.dart': '// stub\n',
    'lib/domain/repositories/muscle_stimulus_repository.dart': '// stub\n',
    'lib/domain/repositories/nutrition_log_repository.dart': '// stub\n',
    'lib/domain/repositories/user_profile_repository.dart': '// stub\n',
    'lib/domain/repositories/voice_repository.dart': '// stub\n',
    'lib/domain/repositories/workout_set_repository.dart': '// stub\n',
    'lib/domain/repositories/app_settings_repository.dart': '// stub\n',
    'lib/domain/usecases/workout_sets/add_workout_set.dart': '// stub\n',
    'lib/domain/usecases/nutrition_logs/add_nutrition_log.dart': '// stub\n',
    'lib/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart':
        '// stub\n',
    'lib/domain/usecases/voice/send_voice_message.dart': '// stub\n',
    'lib/injection/modules/register_core_module.dart': '// stub\n',
    'lib/injection/modules/register_exercises_module.dart': '// stub\n',
    'lib/injection/modules/register_history_module.dart': '// stub\n',
    'lib/injection/modules/register_meals_nutrition_module.dart': '// stub\n',
    'lib/injection/modules/register_muscle_stimulus_module.dart': '// stub\n',
    'lib/injection/modules/register_profile_module.dart': '// stub\n',
    'lib/injection/modules/register_settings_module.dart': '// stub\n',
    'lib/injection/modules/register_voice_module.dart': '// stub\n',
    'lib/injection/modules/register_workout_module.dart': '// stub\n',
    'lib/injection/injection_container.dart': '// stub\n',
  };

  // ── Per-feature fingerprint inputs ────────────────────────────────────────
  // Each value mirrors what StateFreshnessChecker._computeFeatureFingerprint
  // will derive from the FakeRepoView above.

  final authFp = _featureFp(
    files: ['lib/features/auth/application/sign_in_cubit.dart'],
    classes: ['OtpVerificationCubit', 'SignInCubit', 'SignUpCubit'],
    repositories: ['lib/domain/repositories/app_session_repository.dart'],
    useCases: [],
    injectionModule: ['lib/injection/modules/register_core_module.dart'],
    tables: [],
  );

  final historyFp = _featureFp(
    files: ['lib/features/history/presentation/bloc/history_bloc.dart'],
    classes: ['HistoryBloc'],
    repositories: [
      'lib/domain/repositories/nutrition_log_repository.dart',
      'lib/domain/repositories/workout_set_repository.dart',
    ],
    useCases: [],
    injectionModule: ['lib/injection/modules/register_history_module.dart'],
    tables: ['nutrition_logs', 'workout_sets'],
  );

  final homeFp = _featureFp(
    files: ['lib/features/home/application/home_bloc.dart'],
    classes: ['HomeBloc', 'MuscleVisualBloc'],
    repositories: [
      'lib/domain/repositories/app_session_repository.dart',
      'lib/domain/repositories/muscle_factor_repository.dart',
      'lib/domain/repositories/muscle_stimulus_repository.dart',
      'lib/domain/repositories/nutrition_log_repository.dart',
    ],
    useCases: [
      'lib/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart',
    ],
    injectionModule: [
      'lib/injection/injection_container.dart',
      'lib/injection/modules/register_muscle_stimulus_module.dart',
    ],
    tables: ['exercise_muscle_factors', 'muscle_stimulus'],
  );

  final libraryFp = _featureFp(
    files: ['lib/features/library/application/exercise_bloc.dart'],
    classes: ['ExerciseBloc', 'MealBloc'],
    repositories: [
      'lib/domain/repositories/exercise_repository.dart',
      'lib/domain/repositories/meal_repository.dart',
    ],
    useCases: [],
    injectionModule: [
      'lib/injection/modules/register_exercises_module.dart',
      'lib/injection/modules/register_meals_nutrition_module.dart',
    ],
    tables: ['exercises', 'meals'],
  );

  final logFp = _featureFp(
    files: ['lib/features/log/application/workout_bloc.dart'],
    classes: ['NutritionLogBloc', 'WorkoutBloc'],
    repositories: [
      'lib/domain/repositories/exercise_repository.dart',
      'lib/domain/repositories/meal_repository.dart',
      'lib/domain/repositories/nutrition_log_repository.dart',
      'lib/domain/repositories/workout_set_repository.dart',
    ],
    useCases: [
      'lib/domain/usecases/nutrition_logs/add_nutrition_log.dart',
      'lib/domain/usecases/workout_sets/add_workout_set.dart',
    ],
    injectionModule: [
      'lib/injection/modules/register_meals_nutrition_module.dart',
      'lib/injection/modules/register_workout_module.dart',
    ],
    tables: ['exercises', 'meals', 'nutrition_logs', 'workout_sets'],
  );

  final profileFp = _featureFp(
    files: ['lib/features/profile/application/profile_cubit.dart'],
    classes: ['ProfileCubit'],
    repositories: ['lib/domain/repositories/user_profile_repository.dart'],
    useCases: [],
    injectionModule: ['lib/injection/modules/register_profile_module.dart'],
    tables: [],
  );

  final settingsFp = _featureFp(
    files: ['lib/features/settings/application/app_settings_cubit.dart'],
    classes: ['AppSettingsCubit'],
    repositories: ['lib/domain/repositories/app_settings_repository.dart'],
    useCases: [],
    injectionModule: ['lib/injection/modules/register_settings_module.dart'],
    tables: ['app_metadata'],
  );

  final voiceFp = _featureFp(
    files: ['lib/features/voice/application/voice_bloc.dart'],
    classes: ['VoiceBloc', 'VoiceSettingsCubit'],
    repositories: ['lib/domain/repositories/voice_repository.dart'],
    useCases: ['lib/domain/usecases/voice/send_voice_message.dart'],
    injectionModule: ['lib/injection/modules/register_voice_module.dart'],
    tables: [],
  );

  final featureFps = {
    'auth': authFp,
    'history': historyFp,
    'home': homeFp,
    'library': libraryFp,
    'log': logFp,
    'profile': profileFp,
    'settings': settingsFp,
    'voice': voiceFp,
  };
  final topFp = _topFp(featureFps);

  // ── state.json ────────────────────────────────────────────────────────────
  final stateJson = jsonEncode({
    'schemaVersion': 1,
    'generatedAt': '2026-05-21',
    'fingerprint': topFp,
    'features': {
      'auth': {
        'summary': 'Auth cubits.',
        'paths': ['lib/features/auth/'],
        'blocs': ['SignInCubit', 'SignUpCubit', 'OtpVerificationCubit'],
        'repositories': ['lib/domain/repositories/app_session_repository.dart'],
        'useCases': [],
        'injectionModule': 'lib/injection/modules/register_core_module.dart',
        'tables': [],
        'notes': '',
        'fingerprint': authFp,
      },
      'history': {
        'summary': 'History feature.',
        'paths': ['lib/features/history/'],
        'blocs': ['HistoryBloc'],
        'repositories': [
          'lib/domain/repositories/workout_set_repository.dart',
          'lib/domain/repositories/nutrition_log_repository.dart',
        ],
        'useCases': [],
        'injectionModule': 'lib/injection/modules/register_history_module.dart',
        'tables': ['workout_sets', 'nutrition_logs'],
        'notes': '',
        'fingerprint': historyFp,
      },
      'home': {
        'summary': 'Home dashboard.',
        'paths': ['lib/features/home/'],
        'blocs': ['HomeBloc', 'MuscleVisualBloc'],
        'repositories': [
          'lib/domain/repositories/muscle_stimulus_repository.dart',
          'lib/domain/repositories/muscle_factor_repository.dart',
          'lib/domain/repositories/app_session_repository.dart',
          'lib/domain/repositories/nutrition_log_repository.dart',
        ],
        'useCases': [
          'lib/domain/usecases/muscle_stimulus/get_muscle_visual_data.dart',
        ],
        'injectionModule': [
          'lib/injection/modules/register_muscle_stimulus_module.dart',
          'lib/injection/injection_container.dart',
        ],
        'tables': ['muscle_stimulus', 'exercise_muscle_factors'],
        'notes': '',
        'fingerprint': homeFp,
      },
      'library': {
        'summary': 'Library feature.',
        'paths': ['lib/features/library/'],
        'blocs': ['ExerciseBloc', 'MealBloc'],
        'repositories': [
          'lib/domain/repositories/exercise_repository.dart',
          'lib/domain/repositories/meal_repository.dart',
        ],
        'useCases': [],
        'injectionModule': [
          'lib/injection/modules/register_exercises_module.dart',
          'lib/injection/modules/register_meals_nutrition_module.dart',
        ],
        'tables': ['exercises', 'meals'],
        'notes': '',
        'fingerprint': libraryFp,
      },
      'log': {
        'summary': 'Workout and nutrition logging.',
        'paths': ['lib/features/log/'],
        'blocs': ['WorkoutBloc', 'NutritionLogBloc'],
        'repositories': [
          'lib/domain/repositories/workout_set_repository.dart',
          'lib/domain/repositories/nutrition_log_repository.dart',
          'lib/domain/repositories/exercise_repository.dart',
          'lib/domain/repositories/meal_repository.dart',
        ],
        'useCases': [
          'lib/domain/usecases/workout_sets/add_workout_set.dart',
          'lib/domain/usecases/nutrition_logs/add_nutrition_log.dart',
        ],
        'injectionModule': [
          'lib/injection/modules/register_workout_module.dart',
          'lib/injection/modules/register_meals_nutrition_module.dart',
        ],
        'tables': ['workout_sets', 'nutrition_logs', 'exercises', 'meals'],
        'notes': '',
        'fingerprint': logFp,
      },
      'profile': {
        'summary': 'User profile.',
        'paths': ['lib/features/profile/'],
        'blocs': ['ProfileCubit'],
        'repositories': [
          'lib/domain/repositories/user_profile_repository.dart',
        ],
        'useCases': [],
        'injectionModule': 'lib/injection/modules/register_profile_module.dart',
        'tables': [],
        'notes': '',
        'fingerprint': profileFp,
      },
      'settings': {
        'summary': 'App settings.',
        'paths': ['lib/features/settings/'],
        'blocs': ['AppSettingsCubit'],
        'repositories': [
          'lib/domain/repositories/app_settings_repository.dart',
        ],
        'useCases': [],
        'injectionModule':
            'lib/injection/modules/register_settings_module.dart',
        'tables': ['app_metadata'],
        'notes': '',
        'fingerprint': settingsFp,
      },
      'voice': {
        'summary': 'Voice bot.',
        'paths': ['lib/features/voice/'],
        'blocs': ['VoiceBloc', 'VoiceSettingsCubit'],
        'repositories': ['lib/domain/repositories/voice_repository.dart'],
        'useCases': ['lib/domain/usecases/voice/send_voice_message.dart'],
        'injectionModule': 'lib/injection/modules/register_voice_module.dart',
        'tables': [],
        'notes': '',
        'fingerprint': voiceFp,
      },
    },
  });

  sourceFiles['.claude/memory/state.json'] = stateJson;
  return (FakeRepoView(sourceFiles), topFp);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('StateFreshnessChecker', () {
    // ── Pass ─────────────────────────────────────────────────────────────────
    test(
      'pass — all eight features consistent with source, fingerprints match',
      () async {
        final (repo, _) = _buildPassRepo();
        final checker = StateFreshnessChecker(repo);
        final violations = await checker.run();
        expect(
          violations,
          isEmpty,
          reason:
              'Expected zero violations but got:\n'
              '${violations.map((v) => v.toString()).join('\n')}',
        );
      },
    );

    // ── state.json missing ────────────────────────────────────────────────────
    test('fail — state.json is missing', () async {
      final repo = FakeRepoView({});
      final violations = await StateFreshnessChecker(repo).run();
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'state-freshness');
      expect(violations.first.message, contains('missing'));
    });

    // ── Invalid JSON ─────────────────────────────────────────────────────────
    test('fail — state.json is not valid JSON', () async {
      final repo = FakeRepoView({
        '.claude/memory/state.json': '{ not valid json',
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('not valid JSON'));
    });

    // ── schemaVersion ─────────────────────────────────────────────────────────
    test('fail — schemaVersion is 0, not 1', () async {
      final json = jsonEncode({
        'schemaVersion': 0,
        'generatedAt': '2026-05-21',
        'fingerprint': 'abc',
        'features': {},
      });
      final repo = FakeRepoView({'.claude/memory/state.json': json});
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any((v) => v.message.contains('schemaVersion must be 1')),
        isTrue,
      );
    });

    // ── Missing top-level key ─────────────────────────────────────────────────
    test('fail — top-level "fingerprint" key missing', () async {
      final json = jsonEncode({
        'schemaVersion': 1,
        'generatedAt': '2026-05-21',
        // fingerprint omitted
        'features': {},
      });
      final repo = FakeRepoView({'.claude/memory/state.json': json});
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any(
          (v) => v.message.contains(
            'Missing required top-level key: "fingerprint"',
          ),
        ),
        isTrue,
      );
    });

    // ── Missing feature ───────────────────────────────────────────────────────
    test('fail — required feature "voice" missing from features map', () async {
      final (fullRepo, _) = _buildPassRepo();
      // Parse, remove voice, re-serialize
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features'] as Map<String, dynamic>).remove('voice');
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any(
          (v) => v.message.contains('Missing required feature entry: "voice"'),
        ),
        isTrue,
      );
    });

    // ── Unexpected feature ────────────────────────────────────────────────────
    test('fail — unexpected feature "marketing" in features map', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features'] as Map<String, dynamic>)['marketing'] = {
        'paths': [],
        'blocs': [],
        'repositories': [],
        'useCases': [],
        'injectionModule': '',
        'tables': [],
        'fingerprint': '',
      };
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any(
          (v) => v.message.contains('Unexpected feature entry: "marketing"'),
        ),
        isTrue,
      );
    });

    // ── Required field missing ────────────────────────────────────────────────
    test('fail — "blocs" field missing from "home" entry', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features']['home'] as Map<String, dynamic>).remove('blocs');
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any(
          (v) => v.message.contains(
            'Feature "home" is missing required field: "blocs"',
          ),
        ),
        isTrue,
      );
    });

    // ── Path does not exist ───────────────────────────────────────────────────
    test('fail — feature path "lib/features/ghost/" has no files', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features']['settings'] as Map<String, dynamic>)['paths'] = [
        'lib/features/ghost/',
      ];
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any((v) => v.message.contains('"lib/features/ghost/"')),
        isTrue,
      );
    });

    // ── BLoC class not found ──────────────────────────────────────────────────
    test(
      'fail — "GhostBloc" listed in "log" blocs but not in source files',
      () async {
        final (fullRepo, _) = _buildPassRepo();
        final raw = await fullRepo.readFile('.claude/memory/state.json');
        final data = jsonDecode(raw!) as Map<String, dynamic>;
        final logEntry = data['features']['log'] as Map<String, dynamic>;
        logEntry['blocs'] = ['WorkoutBloc', 'NutritionLogBloc', 'GhostBloc'];
        final repo = FakeRepoView({
          ...fullRepo.files,
          '.claude/memory/state.json': jsonEncode(data),
        });
        final violations = await StateFreshnessChecker(repo).run();
        expect(
          violations.any((v) => v.message.contains('"GhostBloc" not found')),
          isTrue,
        );
      },
    );

    // ── Per-feature fingerprint stale ─────────────────────────────────────────
    test(
      'fail — "settings" fingerprint stale after class added to source file',
      () async {
        final (fullRepo, _) = _buildPassRepo();
        // Simulate adding a new class to the settings feature
        final repo = FakeRepoView({
          ...fullRepo.files,
          'lib/features/settings/application/app_settings_cubit.dart':
              'class AppSettingsCubit extends Cubit<AppSettingsState> {}\n'
              'class NewSettingsHelper {}\n', // new class
        });
        final violations = await StateFreshnessChecker(repo).run();
        expect(
          violations.any(
            (v) =>
                v.ruleId == 'state-freshness' &&
                v.message.contains('Feature "settings" fingerprint stale'),
          ),
          isTrue,
        );
        // The violation message must include the expected fingerprint value
        final fpViolation = violations.firstWhere(
          (v) => v.message.contains('Feature "settings" fingerprint stale'),
        );
        expect(fpViolation.fixHint, contains('state.json'));
      },
    );

    // ── Top-level fingerprint stale, per-feature all match ────────────────────
    test(
      'fail — top-level fingerprint wrong even though per-feature fingerprints match',
      () async {
        final (fullRepo, _) = _buildPassRepo();
        final raw = await fullRepo.readFile('.claude/memory/state.json');
        final data = jsonDecode(raw!) as Map<String, dynamic>;
        data['fingerprint'] = 'badf00dbadf00d00'; // deliberately wrong
        final repo = FakeRepoView({
          ...fullRepo.files,
          '.claude/memory/state.json': jsonEncode(data),
        });
        final violations = await StateFreshnessChecker(repo).run();
        expect(
          violations.any(
            (v) => v.message.contains('Top-level fingerprint stale'),
          ),
          isTrue,
        );
        // The per-feature fingerprints must all pass
        expect(
          violations.any(
            (v) => v.message.contains('Feature') && v.message.contains('stale'),
          ),
          isFalse,
        );
      },
    );

    // ── Unknown table name ────────────────────────────────────────────────────
    test('fail — "log" entry lists unknown table "ghost_table"', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      final logEntry = data['features']['log'] as Map<String, dynamic>;
      (logEntry['tables'] as List).add('ghost_table');
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any(
          (v) => v.message.contains('unknown table "ghost_table"'),
        ),
        isTrue,
      );
    });

    // ── CRLF normalisation ────────────────────────────────────────────────────
    test(
      'CRLF — source file with CRLF line endings produces same fingerprint as LF',
      () async {
        // Build a LF repo and a CRLF repo with identical logical content.
        const lfContent =
            'class WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> {}\n'
            'class NutritionLogBloc extends Bloc<NutritionLogEvent, NutritionLogState> {}\n';
        final crlfContent = lfContent.replaceAll('\n', '\r\n');

        final (lfRepo, _) = _buildPassRepo();

        // CRLF variant: replace the log feature source file with CRLF version.
        final crlfFiles = Map<String, String>.from(lfRepo.files);
        crlfFiles['lib/features/log/application/workout_bloc.dart'] =
            crlfContent;

        final crlfRepo = FakeRepoView(crlfFiles);

        final lfViolations = await StateFreshnessChecker(lfRepo).run();
        final crlfViolations = await StateFreshnessChecker(crlfRepo).run();

        // Both must produce zero violations (same fingerprint).
        expect(
          lfViolations.where((v) => v.message.contains('Feature "log"')),
          isEmpty,
          reason: 'LF repo should have zero log violations',
        );
        expect(
          crlfViolations.where((v) => v.message.contains('Feature "log"')),
          isEmpty,
          reason: 'CRLF repo should produce identical fingerprint to LF repo',
        );
      },
    );

    // ── Repository path does not exist ────────────────────────────────────────
    test('fail — "voice" repository path does not exist', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features']['voice'] as Map<String, dynamic>)['repositories'] = [
        'lib/domain/repositories/ghost_repository.dart',
      ];
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any((v) => v.message.contains('ghost_repository.dart')),
        isTrue,
      );
    });

    // ── injectionModule path does not exist ───────────────────────────────────
    test('fail — "profile" injectionModule path does not exist', () async {
      final (fullRepo, _) = _buildPassRepo();
      final raw = await fullRepo.readFile('.claude/memory/state.json');
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      (data['features']['profile'] as Map<String, dynamic>)['injectionModule'] =
          'lib/injection/modules/ghost_module.dart';
      final repo = FakeRepoView({
        ...fullRepo.files,
        '.claude/memory/state.json': jsonEncode(data),
      });
      final violations = await StateFreshnessChecker(repo).run();
      expect(
        violations.any((v) => v.message.contains('ghost_module.dart')),
        isTrue,
      );
    });
  });
}

// ---------------------------------------------------------------------------
// FakeRepoView convenience extension used by mutation-based test helpers
// ---------------------------------------------------------------------------
extension FakeRepoViewFiles on FakeRepoView {
  /// Alias for [FakeRepoView.testFiles] — keeps test code readable.
  Map<String, String> get files => testFiles;
}
