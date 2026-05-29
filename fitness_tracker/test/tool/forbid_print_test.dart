import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/forbid_print.dart';
import '../../tool/convention_rules/shared.dart';

const _path = 'lib/foo.dart';

void main() {
  final rule = ForbidPrintRule();

  group('ForbidPrintRule', () {
    test('passes when no print() is used', () async {
      const code = '''
import 'package:flutter/foundation.dart';
void main() {
  AppLogger.info('hello');
  debugPrint('also fine');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('flags a top-level print() call', () async {
      const code = '''
void main() {
  print('oops');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
      expect(violations.single.line, 2);
      expect(violations.single.message, contains('print()'));
    });

    test('flags indented print() inside a function body', () async {
      const code = '''
void main() {
  if (true) {
    print('still bad');
  }
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, hasLength(1));
      expect(violations.single.line, 3);
    });

    test('allows debugPrint and member calls (.print(...))', () async {
      const code = '''
import 'package:flutter/foundation.dart';
void main() {
  debugPrint('via flutter');
  final pdf = somePdfApi();
  pdf.print();
  someService?.print('x');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('allows identifiers that merely contain "print"', () async {
      const code = '''
void main() {
  final pretty_print = 1;
  final fingerprint = 'x';
  AppLogger.debug('\$pretty_print \$fingerprint');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('ignores print() inside a line comment', () async {
      const code = '''
void main() {
  // print('this would be bad if uncommented');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('honours an inline waiver on the offending line', () async {
      const code = '''
void main() {
  print('one-off'); // convention-checker:allow=forbid-print reason=temporary CLI debug
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });

    test('honours a waiver on the preceding line', () async {
      const code = '''
void main() {
  // convention-checker:allow=forbid-print reason=temporary CLI debug
  print('one-off');
}
''';
      final repo = FakeRepoView({_path: code});

      final violations = await rule.check(repo);

      expect(violations, isEmpty);
    });
  });
}
