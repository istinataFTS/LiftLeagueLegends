import 'dart:io';

import 'convention_rules/bloc_factory_registration.dart';
import 'convention_rules/known_issues_schema.dart';
import 'convention_rules/playbook_canonical_link.dart';
import 'convention_rules/presentation_layer_imports.dart';
import 'convention_rules/shared.dart';
import 'convention_rules/sql_userid_interpolation.dart';
import 'convention_rules/user_scoped_datasource.dart';

Future<void> main() async {
  final repoRoot = Directory.current.path;
  final repo = FsRepoView(repoRoot);

  final rules = <ConventionRule>[
    UserScopedDatasourceRule(),
    PresentationLayerImportsRule(),
    BlocFactoryRegistrationRule(),
    SqlUseridInterpolationRule(),
    KnownIssuesSchemaRule(),
    PlaybookCanonicalLinkRule(),
  ];

  final allViolations = <Violation>[];
  var checkerError = false;

  for (final rule in rules) {
    try {
      final violations = await rule.check(repo);
      allViolations.addAll(violations);
    } catch (e, st) {
      stderr.writeln('[checker-error] Rule "${rule.id}" threw: $e\n$st');
      checkerError = true;
    }
  }

  if (checkerError) {
    stderr.writeln(
      '\ncheck_conventions: checker error — see above. This is a bug in '
      'the checker itself, not a code violation.',
    );
    exit(2);
  }

  if (allViolations.isEmpty) {
    stdout.writeln('check_conventions: ${rules.length} rules passed.');
    exit(0);
  }

  final byRule = <String, List<Violation>>{};
  for (final v in allViolations) {
    byRule.putIfAbsent(v.ruleId, () => []).add(v);
  }

  for (final entry in byRule.entries) {
    stderr.writeln('\n── [${entry.key}] ${entry.value.length} violation(s) ──');
    for (final v in entry.value) {
      stderr.writeln(v.toString());
    }
  }
  stderr.writeln(
    '\ncheck_conventions: ${allViolations.length} violation(s) across '
    '${byRule.length} rule(s).',
  );
  exit(1);
}
