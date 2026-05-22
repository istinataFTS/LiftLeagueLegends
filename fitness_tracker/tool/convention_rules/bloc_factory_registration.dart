import 'shared.dart';

/// BLoCs and Cubits must be registered as `registerFactory`, not
/// `registerLazySingleton`, in DI modules. A singleton BLoC carries state
/// from a previous page visit into the next (KNOWN_ISSUES.md entry
/// `blocs-must-be-factories-repositories-singletons`).
///
/// Add a `// convention-checker:allow=bloc-factory-registration reason=...`
/// comment on the offending line (or the line above) to waive this for a
/// justified singleton Cubit (e.g. a shared cross-page state holder).
final class BlocFactoryRegistrationRule implements ConventionRule {
  @override
  String get id => 'bloc-factory-registration';

  @override
  String get description =>
      'BLoCs and Cubits must use registerFactory, not registerLazySingleton.';

  /// Matches `registerLazySingleton<XxxBloc>` or `registerLazySingleton<XxxCubit>`
  /// (explicit generic form).
  static final _explicitGenericPattern = RegExp(
    r'registerLazySingleton\s*<\s*\w+(?:Bloc|Cubit)\s*>',
  );

  /// Matches `registerLazySingleton(() => XxxBloc(` or `=> XxxCubit(`
  /// (inferred generic form — type derived from the factory lambda).
  static final _inferredGenericPattern = RegExp(
    r'registerLazySingleton\s*\(\s*\(\s*\)\s*=>\s*\w+(?:Bloc|Cubit)\s*\(',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib/injection/modules');
    final violations = <Violation>[];

    for (final path in files) {
      final raw = await repo.readFile(path);
      if (raw == null) continue;
      final content = raw.replaceAll('\r\n', '\n');

      final lines = content.split('\n');

      void checkPattern(RegExp pattern) {
        for (final match in pattern.allMatches(content)) {
          final lineNum =
              '\n'.allMatches(content.substring(0, match.start)).length + 1;
          if (hasWaiver(lines, lineNum - 1, id)) continue;
          violations.add(
            Violation(
              ruleId: id,
              filePath: path,
              line: lineNum,
              message:
                  'A Bloc or Cubit is registered as registerLazySingleton. '
                  'BLoCs/Cubits must be registerFactory.',
              fixHint:
                  'Change to registerFactory, or add a waiver comment with a '
                  'reason if this is an intentional singleton (see KNOWN_ISSUES.md '
                  '#blocs-must-be-factories-repositories-singletons).',
            ),
          );
        }
      }

      checkPattern(_explicitGenericPattern);
      checkPattern(_inferredGenericPattern);
    }

    return violations;
  }
}
