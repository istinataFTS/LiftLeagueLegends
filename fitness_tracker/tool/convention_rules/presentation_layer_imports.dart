import 'shared.dart';

/// No file under `lib/features/<x>/presentation/` may import from the shared
/// `lib/data/` layer or from any feature's own `data/` layer. Presentation
/// code must only depend on domain interfaces and use cases.
final class PresentationLayerImportsRule implements ConventionRule {
  @override
  String get id => 'presentation-layer-data-import';

  @override
  String get description =>
      'Presentation files must not import from lib/data/ or lib/features/*/data/.';

  /// Matches imports that resolve to any data layer:
  ///   - package:fitness_tracker/data/...  (shared data layer)
  ///   - package:fitness_tracker/features/<x>/data/...  (feature data layer)
  ///   - Relative paths with 1+ ../ followed by data/  (both shared and
  ///     feature-local data layers reachable from any presentation/ depth)
  static final _crossLayerImportPattern = RegExp(
    r'''import\s+['"]'''
    r'''(package:fitness_tracker/data/'''
    r'''|package:fitness_tracker/features/[^/]+/data/'''
    r'''|(?:\.\.\/)+data/)''',
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
