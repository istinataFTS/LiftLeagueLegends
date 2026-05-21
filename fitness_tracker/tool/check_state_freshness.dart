// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'convention_rules/shared.dart';

/// Entry point. Checks that `.claude/memory/state.json` is consistent with
/// the current state of the `lib/` source tree.
///
/// Exit codes:
///   0 — all checks passed.
///   1 — one or more violations found (see stderr for details).
///   2 — the checker itself encountered an IO error (bug in the checker).
Future<void> main() async {
  final repoRoot = Directory.current.path;
  final repo = FsRepoView(repoRoot);
  final checker = StateFreshnessChecker(repo);

  List<Violation> violations;
  try {
    violations = await checker.run();
  } catch (e, st) {
    stderr.writeln('[checker-error] StateFreshnessChecker threw: $e\n$st');
    exit(2);
  }

  if (violations.isEmpty) {
    stdout.writeln('check_state_freshness: all checks passed.');
    exit(0);
  }

  stderr.writeln('\n── [state-freshness] ${violations.length} violation(s) ──');
  for (final v in violations) {
    stderr.writeln(v.toString());
  }
  stderr.writeln(
    '\ncheck_state_freshness: ${violations.length} violation(s) found.\n'
    'Run `dart run tool/check_state_freshness.dart` locally to see the\n'
    'expected fingerprint values, then paste them into state.json.',
  );
  exit(1);
}

// ---------------------------------------------------------------------------
// Checker
// ---------------------------------------------------------------------------

/// Validates `.claude/memory/state.json` against the live source tree.
final class StateFreshnessChecker {
  const StateFreshnessChecker(this._repo);

  final RepoView _repo;

  static const String _stateJsonPath = '.claude/memory/state.json';

  /// The eight features tracked in the codebase map. Alphabetical.
  static const Set<String> _requiredFeatures = {
    'auth',
    'history',
    'home',
    'library',
    'log',
    'profile',
    'settings',
    'voice',
  };

  /// Fields every feature entry must declare.
  static const List<String> _requiredFeatureFields = [
    'paths',
    'blocs',
    'repositories',
    'useCases',
    'injectionModule',
    'tables',
    'fingerprint',
  ];

  /// Maps the eight snake_case table names (as stored in state.json) to the
  /// matching camelCase `DatabaseTables.<member>` constant name.
  /// Used to validate the `tables` field in each feature entry.
  static const Map<String, String> _knownTables = {
    'app_metadata': 'appMetadata',
    'exercise_muscle_factors': 'exerciseMuscleFactors',
    'exercises': 'exercises',
    'meals': 'meals',
    'muscle_stimulus': 'muscleStimulus',
    'nutrition_logs': 'nutritionLogs',
    'pending_sync_deletes': 'pendingSyncDeletes',
    'workout_sets': 'workoutSets',
  };

  /// Number of hex chars retained from the SHA-256 digest in fingerprints.
  /// Locked at 16 to keep state.json values short and human-comparable.
  static const int _fingerprintLength = 16;

  // ── Regex constants (locked per plan Section 3.8) ───────────────────────

  /// Matches the start of a Dart class declaration.
  /// Captures the class name (group 1).
  static final _classDeclarationRegex = RegExp(
    r'^\s*(?:abstract\s+|final\s+|sealed\s+|base\s+|interface\s+|mixin\s+)*'
    r'class\s+(\w+)\b',
    multiLine: true,
  );

  // ---------------------------------------------------------------------------

  Future<List<Violation>> run() async {
    final violations = <Violation>[];

    // ── 1. Read & parse state.json ──────────────────────────────────────────
    final raw = await _repo.readFile(_stateJsonPath);
    if (raw == null) {
      violations.add(
        const Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message: 'state.json is missing',
          fixHint:
              'Create .claude/memory/state.json per boilerplate-06-codebase-map-plan.md.',
        ),
      );
      return violations;
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      violations.add(
        Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message: 'state.json is not valid JSON: $e',
          fixHint: 'Fix the JSON syntax error.',
        ),
      );
      return violations;
    }

    // ── 2. schemaVersion ───────────────────────────────────────────────────
    if (data['schemaVersion'] != 1) {
      violations.add(
        Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message: 'schemaVersion must be 1, got: ${data['schemaVersion']}',
          fixHint: 'Set "schemaVersion" to 1.',
        ),
      );
    }

    // ── 3. Required top-level keys ─────────────────────────────────────────
    for (final key in [
      'schemaVersion',
      'generatedAt',
      'fingerprint',
      'features',
    ]) {
      if (!data.containsKey(key)) {
        violations.add(
          Violation(
            ruleId: 'state-freshness',
            filePath: _stateJsonPath,
            message: 'Missing required top-level key: "$key"',
            fixHint: 'Add the "$key" field to state.json.',
          ),
        );
      }
    }

    if (!data.containsKey('features')) return violations;
    final features = data['features'] as Map<String, dynamic>;

    // ── 4. Feature key set ─────────────────────────────────────────────────
    final actualKeys = features.keys.toSet();
    for (final missing in _requiredFeatures.difference(actualKeys)) {
      violations.add(
        Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message: 'Missing required feature entry: "$missing"',
          fixHint: 'Add a "$missing" entry to the features map in state.json.',
        ),
      );
    }
    for (final extra in actualKeys.difference(_requiredFeatures)) {
      violations.add(
        Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message: 'Unexpected feature entry: "$extra"',
          fixHint:
              'Remove "$extra" from state.json, or add it to '
              '_requiredFeatures in check_state_freshness.dart if it is a new feature.',
        ),
      );
    }

    // ── 5–8. Per-feature validation ────────────────────────────────────────
    final featureFingerprints = <String, String>{};

    for (final featureName in _requiredFeatures) {
      if (!features.containsKey(featureName)) continue;
      final entry = features[featureName] as Map<String, dynamic>;

      // 5a. Required fields present
      for (final field in _requiredFeatureFields) {
        if (!entry.containsKey(field)) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" is missing required field: "$field"',
              fixHint:
                  'Add the "$field" field to the "$featureName" entry in state.json.',
            ),
          );
        }
      }

      final paths = _toStringList(entry['paths']);
      final blocs = _toStringList(entry['blocs']);
      final repos = _toStringList(entry['repositories']);
      final useCases = _toStringList(entry['useCases']);
      final tables = _toStringList(entry['tables']);
      final injMod = entry['injectionModule'];
      final injModPaths = _injModToList(injMod);

      // 5b. Paths must resolve to at least one file
      for (final path in paths) {
        final files = await _repo.listFiles(path);
        if (files.isEmpty) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" path "$path" contains no files '
                  '(directory missing or empty)',
              fixHint:
                  'Verify the path exists and contains source files, '
                  'or remove it from the paths list.',
            ),
          );
        }
      }

      // 5c. Repository paths must exist
      for (final repoPath in repos) {
        if (await _repo.readFile(repoPath) == null) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" repository path does not exist: '
                  '"$repoPath"',
              fixHint:
                  'Update the "repositories" list for "$featureName" in state.json.',
            ),
          );
        }
      }

      // 5d. Use-case paths must exist
      for (final ucPath in useCases) {
        if (await _repo.readFile(ucPath) == null) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" use case path does not exist: '
                  '"$ucPath"',
              fixHint:
                  'Update the "useCases" list for "$featureName" in state.json.',
            ),
          );
        }
      }

      // 5e. injectionModule paths must exist
      for (final modPath in injModPaths) {
        if (await _repo.readFile(modPath) == null) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" injectionModule path does not exist: '
                  '"$modPath"',
              fixHint:
                  'Update "injectionModule" for "$featureName" in state.json.',
            ),
          );
        }
      }

      // 6. BLoC class names must appear in feature source files
      if (blocs.isNotEmpty) {
        final foundClasses = await _extractClassNames(paths);
        for (final bloc in blocs) {
          if (!foundClasses.contains(bloc)) {
            violations.add(
              Violation(
                ruleId: 'state-freshness',
                filePath: _stateJsonPath,
                message:
                    'Feature "$featureName" BLoC/Cubit class "$bloc" not found '
                    'in feature source files under: ${paths.join(", ")}',
                fixHint:
                    'Update the "blocs" list for "$featureName", or check '
                    'that the class declaration exists in the tracked paths.',
              ),
            );
          }
        }
      }

      // 7. Table names must be in the known-tables map
      for (final table in tables) {
        if (!_knownTables.containsKey(table)) {
          violations.add(
            Violation(
              ruleId: 'state-freshness',
              filePath: _stateJsonPath,
              message:
                  'Feature "$featureName" references unknown table "$table"',
              fixHint:
                  'Table names must be snake_case and match one of: '
                  '${_knownTables.keys.toList()..sort()}. '
                  'If this is a new table, add it to _knownTables in '
                  'check_state_freshness.dart.',
            ),
          );
        }
      }

      // 8. Per-feature fingerprint
      final expectedFp = await _computeFeatureFingerprint(
        paths: paths,
        blocs: blocs,
        repositories: repos,
        useCases: useCases,
        injectionModule: injMod,
        tables: tables,
      );
      featureFingerprints[featureName] = expectedFp;

      final storedFp = entry['fingerprint'] as String? ?? '';
      if (storedFp != expectedFp) {
        violations.add(
          Violation(
            ruleId: 'state-freshness',
            filePath: _stateJsonPath,
            message:
                'Feature "$featureName" fingerprint stale\n'
                '  Expected: $expectedFp\n'
                '  Actual:   $storedFp',
            fixHint:
                'Update state.json ".$featureName.fingerprint" to: $expectedFp',
          ),
        );
      }
    }

    // ── 9. Top-level fingerprint ───────────────────────────────────────────
    final expectedTopFp = _computeTopLevelFingerprint(featureFingerprints);
    final storedTopFp = data['fingerprint'] as String? ?? '';
    if (storedTopFp != expectedTopFp) {
      violations.add(
        Violation(
          ruleId: 'state-freshness',
          filePath: _stateJsonPath,
          message:
              'Top-level fingerprint stale\n'
              '  Expected: $expectedTopFp\n'
              '  Actual:   $storedTopFp',
          fixHint:
              'Update the top-level "fingerprint" field in state.json to: '
              '$expectedTopFp',
        ),
      );
    }

    return violations;
  }

  // ---------------------------------------------------------------------------
  // Fingerprint computation
  // ---------------------------------------------------------------------------

  /// Computes a deterministic 16-hex-char fingerprint over [inputs].
  ///
  /// Serialises with `jsonEncode` (key order is the caller's responsibility —
  /// pass an already-sorted map), then takes the first [_fingerprintLength]
  /// hex chars of the SHA-256 digest.
  static String _sha16(Object inputs) {
    final encoded = jsonEncode(inputs);
    final digest = sha256.convert(utf8.encode(encoded));
    return digest.toString().substring(0, _fingerprintLength);
  }

  /// Computes the per-feature fingerprint per plan Section 3.1.
  ///
  /// Inputs (all sorted for determinism):
  ///   - repo-relative file paths under [paths]
  ///   - class names declared in those files
  ///   - [repositories] paths
  ///   - [useCases] paths
  ///   - [injectionModule] path(s)
  ///   - [tables] names
  ///
  /// Returns the first 16 hex chars of the SHA-256 digest.
  Future<String> _computeFeatureFingerprint({
    required List<String> paths,
    required List<String> blocs,
    required List<String> repositories,
    required List<String> useCases,
    required dynamic injectionModule,
    required List<String> tables,
  }) async {
    // File list
    final allFiles = <String>[];
    for (final path in paths) {
      allFiles.addAll(await _repo.listFiles(path));
    }
    allFiles.sort();

    // Class declarations extracted from source
    final classNames = (await _extractClassNames(paths)).toList()..sort();

    // Injection module normalised to sorted list
    final injModList = _injModToList(injectionModule)..sort();

    final inputMap = {
      'files': allFiles,
      'classes': classNames,
      'repositories': (List<String>.from(repositories))..sort(),
      'useCases': (List<String>.from(useCases))..sort(),
      'injectionModule': injModList,
      'tables': (List<String>.from(tables))..sort(),
    };

    return _sha16(inputMap);
  }

  /// Combines per-feature fingerprints into one top-level fingerprint.
  String _computeTopLevelFingerprint(Map<String, String> featureFingerprints) {
    final sorted = Map.fromEntries(
      featureFingerprints.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    return _sha16(sorted);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Extracts all class names declared in `.dart` files under [paths].
  /// Normalises CRLF → LF before regex application (plan Section 3.7).
  Future<Set<String>> _extractClassNames(List<String> paths) async {
    final names = <String>{};
    for (final path in paths) {
      for (final filePath in await _repo.listDartFiles(path)) {
        var content = await _repo.readFile(filePath);
        if (content == null) continue;
        content = content.replaceAll('\r\n', '\n');
        for (final m in _classDeclarationRegex.allMatches(content)) {
          names.add(m.group(1)!);
        }
      }
    }
    return names;
  }

  /// Normalises the `injectionModule` field (string or list) to a `List<String>`.
  static List<String> _injModToList(dynamic value) {
    if (value is List) return value.cast<String>();
    if (value is String) return [value];
    return [];
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) return value.cast<String>();
    return [];
  }
}
