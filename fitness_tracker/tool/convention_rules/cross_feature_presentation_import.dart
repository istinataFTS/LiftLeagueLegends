import 'shared.dart';

/// No file under `lib/features/<F>/presentation/` may import from another
/// feature's directory tree (`lib/features/<G>/...` where `G != F`).
///
/// Cross-feature presentation imports create dependency cycles between
/// feature folders and make refactors brittle: changing feature G can
/// silently break feature F. Use one of these instead:
///
/// - `Navigator.pushNamed(context, AppRoutes.someRoute)` for navigation
///   between feature pages. The named-route registry in
///   `lib/app/routes/app_routes.dart` is the only file allowed to know
///   about every feature's top-level page class.
/// - Depend on shared `lib/domain/` entities, repository interfaces, or
///   use cases when behaviour (not presentation) needs to be shared.
///
/// The shell layers `lib/app/` and `lib/presentation/` are exempt by
/// construction (they compose features). External-package imports and
/// imports of `dart:`/`package:flutter/` are not checked.
///
/// Add a waiver comment on the offending import or the line above it
/// to allow a specific cross-feature import:
///
/// ```dart
/// // convention-checker:allow=cross-feature-presentation-import reason=...
/// ```
final class CrossFeaturePresentationImportRule implements ConventionRule {
  @override
  String get id => 'cross-feature-presentation-import';

  @override
  String get description =>
      "Presentation files must not import from another feature's layers.";

  /// Captures the current file's feature name from its path.
  /// Match: `lib/features/<feature>/presentation/...`.
  static final _filePathFeaturePattern = RegExp(
    r'^lib/features/([^/]+)/presentation/',
  );

  /// Captures the imported feature name from any cross-feature import.
  /// Match shapes:
  ///   - `package:fitness_tracker/features/<F>/...`
  ///   - relative `'../../../features/<F>/...'` (any depth of `../`)
  ///
  /// Multi-line mode so a dart-formatter-wrapped import (whose URL string
  /// itself is single-line, but whose surrounding `import` clause may have
  /// trailing line content) does not escape detection. The whole-file
  /// `allMatches` traversal mirrors the lesson learned in
  /// `bloc_factory_registration.dart`.
  static final _importFeaturePattern = RegExp(
    r'''import\s+['"](?:package:fitness_tracker/|(?:\.\./)+)features/([^/]+)/''',
    multiLine: true,
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib/features');
    final violations = <Violation>[];

    for (final path in files) {
      final fileFeatureMatch = _filePathFeaturePattern.firstMatch(path);
      if (fileFeatureMatch == null) continue;

      final currentFeature = fileFeatureMatch.group(1)!;

      final raw = await repo.readFile(path);
      if (raw == null) continue;
      final content = raw.replaceAll('\r\n', '\n');
      final lines = content.split('\n');

      for (final match in _importFeaturePattern.allMatches(content)) {
        final importedFeature = match.group(1)!;
        if (importedFeature == currentFeature) continue;

        final lineNum =
            '\n'.allMatches(content.substring(0, match.start)).length + 1;
        if (hasWaiver(lines, lineNum - 1, id)) continue;

        violations.add(
          Violation(
            ruleId: id,
            filePath: path,
            line: lineNum,
            message:
                'Presentation file in feature "$currentFeature" imports from '
                'feature "$importedFeature". Cross-feature presentation '
                'imports create dependency cycles.',
            fixHint:
                'Use Navigator.pushNamed via lib/app/routes/app_routes.dart '
                'for navigation, or depend on lib/domain/ types for shared '
                'behaviour. See KNOWN_ISSUES.md '
                '#cross-feature-presentation-imports-are-architectural-cycles.',
          ),
        );
      }
    }

    return violations;
  }
}
