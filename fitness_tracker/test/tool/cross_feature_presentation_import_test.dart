import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/cross_feature_presentation_import.dart';
import '../../tool/convention_rules/shared.dart';

void main() {
  final rule = CrossFeaturePresentationImportRule();

  group('CrossFeaturePresentationImportRule', () {
    test('passes for same-feature imports across layers', () async {
      final repo = FakeRepoView({
        'lib/features/profile/presentation/profile_page.dart':
            "import '../application/profile_cubit.dart';\n"
            "import '../domain/profile_view_data.dart';\n"
            'class ProfilePage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes for domain, core, and external imports', () async {
      final repo = FakeRepoView({
        'lib/features/profile/presentation/profile_page.dart':
            "import 'package:flutter/material.dart';\n"
            "import '../../../core/themes/app_theme.dart';\n"
            "import '../../../domain/entities/user_profile.dart';\n"
            'class ProfilePage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'reports a violation for relative cross-feature import (presentation)',
      () async {
        final repo = FakeRepoView({
          'lib/features/settings/presentation/settings_page.dart':
              "import '../../../features/voice/presentation/voice_settings_page.dart';\n"
              'class SettingsPage {}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'cross-feature-presentation-import');
        expect(violations.first.line, 1);
      },
    );

    test(
      'reports a violation for relative cross-feature import (application)',
      () async {
        final repo = FakeRepoView({
          'lib/features/settings/presentation/settings_page.dart':
              "import '../../../features/voice/application/voice_settings_cubit.dart';\n"
              'class SettingsPage {}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'cross-feature-presentation-import');
      },
    );

    test(
      'reports a violation for package:fitness_tracker cross-feature import',
      () async {
        final repo = FakeRepoView({
          'lib/features/settings/presentation/settings_page.dart':
              "import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';\n"
              'class SettingsPage {}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'cross-feature-presentation-import');
      },
    );

    test('does not scan files outside lib/features/<F>/presentation/', () async {
      // lib/presentation/ (shell-level) and lib/app/ (composition root) are
      // both allowed to import cross-feature; the rule must not flag them.
      final repo = FakeRepoView({
        'lib/presentation/navigation/bottom_navigation.dart':
            "import '../../features/voice/application/voice_settings_cubit.dart';\n"
            'class BottomNavigation {}\n',
        'lib/app/routes/app_router.dart':
            "import '../../features/voice/presentation/voice_overlay_page.dart';\n"
            'class AppRouter {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('does not flag non-feature import paths', () async {
      // Paths that happen to contain "features" in a different context
      // must not match.
      final repo = FakeRepoView({
        'lib/features/profile/presentation/profile_page.dart':
            "import 'package:flutter/material.dart';\n"
            "import 'package:my_package/some_features_helper.dart';\n"
            'class ProfilePage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('reports multiple violations on multiple offending lines', () async {
      final repo = FakeRepoView({
        'lib/features/profile/presentation/profile_page.dart':
            "import '../../../features/auth/presentation/sign_in_page.dart';\n"
            "import '../../../features/settings/presentation/settings_page.dart';\n"
            "import '../../../features/voice/application/voice_settings_cubit.dart';\n"
            'class ProfilePage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(3));
      expect(violations.map((v) => v.line), containsAll(<int>[1, 2, 3]));
    });

    test('waiver on preceding line suppresses violation', () async {
      final repo = FakeRepoView({
        'lib/features/settings/presentation/settings_page.dart':
            '// convention-checker:allow=cross-feature-presentation-import reason=temporary entry-point widget pending route migration\n'
            "import '../../../features/voice/presentation/voice_settings_page.dart';\n"
            'class SettingsPage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('waiver for wrong rule-id does not suppress violation', () async {
      final repo = FakeRepoView({
        'lib/features/settings/presentation/settings_page.dart':
            '// convention-checker:allow=some-other-rule reason=valid 10-char reason here\n'
            "import '../../../features/voice/presentation/voice_settings_page.dart';\n"
            'class SettingsPage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    test('waiver with too-short reason does not suppress violation', () async {
      final repo = FakeRepoView({
        'lib/features/settings/presentation/settings_page.dart':
            '// convention-checker:allow=cross-feature-presentation-import reason=todo\n'
            "import '../../../features/voice/presentation/voice_settings_page.dart';\n"
            'class SettingsPage {}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    // Multi-line fixture: the dart-formatter does NOT split an import path
    // across lines (Dart syntax forbids it), but neighbouring multi-line
    // content must not throw off the line-number recovery. The whole-file
    // scan + line-recovery pattern is the same approach
    // bloc_factory_registration uses.

    test(
      'reports the correct line number when offenders follow multi-line content',
      () async {
        final repo = FakeRepoView({
          'lib/features/profile/presentation/profile_page.dart':
              "/// A multi-line\n"
              "/// doc comment\n"
              "/// before the imports.\n"
              "import 'package:flutter/material.dart';\n"
              "import '../../../features/voice/application/voice_settings_cubit.dart';\n"
              'class ProfilePage {}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.line, 5);
      },
    );
  });
}
