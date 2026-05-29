import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/forbid_todo_without_anchor.dart';
import '../../tool/convention_rules/shared.dart';

const _path = 'lib/foo.dart';

void main() {
  final rule = ForbidTodoWithoutAnchorRule();

  group('ForbidTodoWithoutAnchorRule', () {
    test('passes for code with no TODO markers', () async {
      const code = '''
void main() {
  AppLogger.info('hello');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('accepts a KNOWN_ISSUES-style kebab anchor', () async {
      const code = '''
void main() {
  // TODO(#guest-catalog-pk-collision-blocks-initial-sign-in): drop after Plan 1
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('accepts a numeric issue/PR reference', () async {
      const code = '''
void main() {
  // FIXME: tracked under #123
  // TODO(#999) plumb in once the API ships
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('flags a bare TODO with no anchor', () async {
      const code = '''
void main() {
  // TODO refactor this when time permits
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
      expect(violations.single.message, contains('TODO'));
      expect(violations.single.line, 2);
    });

    test('flags FIXME, XXX, HACK variants the same way', () async {
      const code = '''
void main() {
  // FIXME flaky on Android
  // XXX: this is gross
  // HACK around the missing API
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(3));
      expect(
        violations.map((v) => v.message).toList(),
        containsAll([contains('FIXME'), contains('XXX'), contains('HACK')]),
      );
    });

    test('honours an inline waiver on the offending line', () async {
      const code = '''
void main() {
  // TODO clean this up // convention-checker:allow=forbid-todo-without-anchor reason=transient cleanup
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('honours a waiver on the preceding line', () async {
      const code = '''
void main() {
  // convention-checker:allow=forbid-todo-without-anchor reason=transient cleanup
  // TODO clean this up
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('exempts files under test/tool/', () async {
      const code = '''
void main() {
  // TODO this would normally fire
}
''';
      final repo = FakeRepoView({'test/tool/some_rule_test.dart': code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('does not match identifiers like "todo" inside other words', () async {
      const code = '''
void main() {
  final todoList = ['x'];
  AppLogger.debug('count=\${todoList.length}');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('rejects a single-char hash like #x as not a valid anchor', () async {
      const code = '''
void main() {
  // TODO see #x
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
    });
  });
}
