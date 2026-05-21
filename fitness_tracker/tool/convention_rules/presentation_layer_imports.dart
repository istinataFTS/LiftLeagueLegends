import 'shared.dart';

/// No file under `lib/features/<x>/presentation/` may import from the shared
/// `lib/data/` layer. Presentation code must only depend on domain interfaces
/// and use cases.
///
/// Feature-local `data/` folders (e.g. `lib/features/voice/data/services/`)
/// are intentionally excluded — a relative `../data/services/...` from within
/// the same feature does NOT reach `lib/data/`.
final class PresentationLayerImportsRule implements ConventionRule {
  @override
  String get id => 'presentation-layer-data-import';

  @override
  String get description =>
      'Presentation files must not import from lib/data/.';

  /// Matches imports that resolve to the shared `lib/data/` layer:
  ///   - package:fitness_tracker/data/...
  ///   - Relative paths with 3+ ../ escaping the feature root into lib/
  static final _crossLayerImportPattern = RegExp(
    r'''import\s+['"](package:fitness_tracker/data/|(?:\.\.\/){3,}data/)''',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib/features');
    final violations = <Violation>[];

    for (final path in files) {
      if (!path.contains('/presentation/')) continue;

      final content = await repo.readFile(path);
      if (content == null) continue;

      final lines = content.split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (!_crossLayerImportPattern.hasMatch(lines[i])) continue;
        violations.add(
          Violation(
            ruleId: id,
            filePath: path,
            line: i + 1,
            message: 'Presentation file imports from lib/data/.',
            fixHint:
                'Depend on a domain repository interface or a use case instead '
                'of importing from lib/data/ directly.',
          ),
        );
      }
    }

    return violations;
  }
}
