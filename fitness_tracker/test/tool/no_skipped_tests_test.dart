import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/no_skipped_tests.dart';
import '../../tool/convention_rules/shared.dart';

const _path = 'test/foo_test.dart';

void main() {
  final rule = NoSkippedTestsRule();

  group('NoSkippedTestsRule', () {
    test('passes for a clean test file', () async {
      const code = '''
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('a passing test', () {
    expect(1 + 1, 2);
  });
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('flags @Skip file-level annotation', () async {
      const code = '''
@Skip('flaky on CI, see #123')
library;
import 'package:flutter_test/flutter_test.dart';
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
      expect(violations.single.message, contains('@Skip'));
      expect(violations.single.line, 1);
    });

    test(
      'flags skip: true on a test/testWidgets/group call (each variant)',
      () async {
        const code = '''
void main() {
  test('a', () {}, skip: true);
  testWidgets('b', (t) async {}, skip: 'waiting on fix');
  group('c', () {}, skip: "another reason");
  test('d', () {}, skip: kSomeConst);
}
''';
        final repo = FakeRepoView({_path: code});

        final violations = await rule.check(repo);

        expect(violations, hasLength(4));
        for (final v in violations) {
          expect(v.ruleId, 'no-skipped-tests');
          expect(v.filePath, _path);
        }
      },
    );

    test(
      'accepts skip: false and skip: null as explicit not-skipped',
      () async {
        const code = '''
void main() {
  test('a', () {}, skip: false);
  test('b', () {}, skip: null);
}
''';
        final repo = FakeRepoView({_path: code});

        final violations = await rule.check(repo);

        expect(violations, isEmpty);
      },
    );

    test('flags solo: true', () async {
      const code = '''
void main() {
  test('focused', () {}, solo: true);
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
      expect(violations.single.message, contains('solo'));
    });

    test('ignores skip patterns inside line comments', () async {
      const code = '''
void main() {
  // skip: true would be a violation if it weren't commented out
  test('a', () {});
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('honours an inline waiver on the offending line', () async {
      const code = '''
void main() {
  test('a', () {}, skip: 'waiting on PR #99'); // convention-checker:allow=no-skipped-tests reason=tracked under PR #99
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('honours a waiver on the preceding line', () async {
      const code = '''
void main() {
  // convention-checker:allow=no-skipped-tests reason=tracked in KNOWN_ISSUES #foo
  test('a', () {}, skip: 'see anchor');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('exempts files under test/tool/ (convention-rule tests)', () async {
      const code = '''
@Skip('this would normally violate')
library;
void main() {
  test('a', () {}, skip: true);
}
''';
      final repo = FakeRepoView({'test/tool/some_rule_test.dart': code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('does not flag identifiers that merely contain "skip"', () async {
      const code = '''
void main() {
  final useSkipReason = true;
  test('a', () { expect(useSkipReason, true); });
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });
  });
}
