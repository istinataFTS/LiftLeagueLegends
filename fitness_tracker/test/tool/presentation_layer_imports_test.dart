import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/presentation_layer_imports.dart';
import '../../tool/convention_rules/shared.dart';

void main() {
  final rule = PresentationLayerImportsRule();

  group('PresentationLayerImportsRule', () {
    test('passes when presentation file has no data-layer imports', () async {
      final repo = FakeRepoView({
        'lib/features/log/presentation/log_page.dart':
            "import 'package:flutter/material.dart';\n"
            "import 'package:fitness_tracker/domain/repositories/workout_repository.dart';\n",
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'passes when presentation file imports from domain/ and application/ only',
      () async {
        final repo = FakeRepoView({
          'lib/features/voice/presentation/voice_overlay_page.dart':
              "import '../../../domain/services/voice_wake_word_service.dart';\n"
              "import '../application/voice_bloc.dart';\n",
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test(
      'reports a violation for a feature-local data import (../data/services/...)',
      () async {
        // lib/features/voice/presentation/voice_overlay_page.dart →
        // '../data/services/...' resolves to lib/features/voice/data/services/...
        // Presentation must not depend on any data layer, including feature-local.
        final repo = FakeRepoView({
          'lib/features/voice/presentation/voice_overlay_page.dart':
              "import '../data/services/voice_tts_service.dart';\n",
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'presentation-layer-data-import');
      },
    );

    test(
      'reports a violation for a nested widget importing from feature data/ via ../../data/',
      () async {
        // lib/features/voice/presentation/widgets/voice_fab.dart →
        // '../../data/services/...' resolves to lib/features/voice/data/services/...
        final repo = FakeRepoView({
          'lib/features/voice/presentation/widgets/voice_fab.dart':
              "import '../../data/services/voice_wake_word_service.dart';\n",
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'presentation-layer-data-import');
      },
    );

    test('passes for non-presentation dart files', () async {
      final repo = FakeRepoView({
        'lib/features/log/application/log_bloc.dart':
            "import 'package:fitness_tracker/data/repositories/workout_repo_impl.dart';\n",
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('reports a violation for a package: import of lib/data/', () async {
      final repo = FakeRepoView({
        'lib/features/log/presentation/log_page.dart':
            "import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource_impl.dart';\n",
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'presentation-layer-data-import');
      expect(violations.first.line, 1);
    });

    test(
      'reports a violation for a deep relative import escaping to lib/data/',
      () async {
        // lib/features/log/presentation/widgets/foo.dart:
        // '../../../data/...' → lib/features/../../../data/ = lib/data/
        // Wait: from lib/features/log/presentation/widgets/, 4x ../ = lib/
        // So '../../../data/' (3x ../) = lib/features/../data/ which is lib/data/? No.
        // From lib/features/log/presentation/widgets/:
        //   ../ = lib/features/log/presentation/
        //   ../../ = lib/features/log/
        //   ../../../ = lib/features/
        //   ../../../../ = lib/
        //   ../../../../data/ = lib/data/  ← 4x ../ needed from widgets/
        // From lib/features/log/presentation/ (not widgets):
        //   ../ = lib/features/log/
        //   ../../ = lib/features/
        //   ../../../ = lib/
        //   ../../../data/ = lib/data/ ← 3x ../ needed from presentation/
        final repo = FakeRepoView({
          'lib/features/log/presentation/log_page.dart':
              "import '../../../data/datasources/local/workout_set_local_datasource_impl.dart';\n",
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'presentation-layer-data-import');
      },
    );
  });
}
