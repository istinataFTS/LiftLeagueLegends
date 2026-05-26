import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/known_issues_schema.dart';
import '../../tool/convention_rules/shared.dart';

// Minimal well-formed entry content (all 9 required fields present and valid).
const _goodEntry = '''
### good-entry

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** sync

**Symptom**

App crashes on launch.

**Root cause**

Missing nil check.

**Workaround / fix**

Add nil guard.

**References**

- `lib/foo.dart:42`
''';

const _templateInFence = '''
## How to add an entry

```
### <short-kebab-case-title>

- **Severity:** Critical | High | Medium | Low
- **Status:** Active | Mitigated | Resolved-but-monitor
- **First observed:** YYYY-MM-DD
- **Last verified:** YYYY-MM-DD
- **Area:** sync | voice | db | di | ci | platform | other

**Symptom**

**Root cause**

**Workaround / fix**

**References**
```

''';

void main() {
  final rule = KnownIssuesSchemaRule();

  group('KnownIssuesSchemaRule', () {
    test('passes for a well-formed entry', () async {
      final repo = FakeRepoView({'KNOWN_ISSUES.md': _goodEntry});
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'does not report the template inside a code fence as an entry',
      () async {
        final repo = FakeRepoView({'KNOWN_ISSUES.md': _templateInFence});
        final violations = await rule.check(repo);
        // The template is inside ``` so no entry should be parsed.
        expect(violations, isEmpty);
      },
    );

    test('reports a missing Severity field', () async {
      const bad = '''
### bad-entry

- **Status:** Active
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** sync

**Symptom**

**Root cause**

**Workaround / fix**

**References**
''';
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('missing field "Severity"')),
        isTrue,
      );
    });

    test('reports an invalid Severity value', () async {
      const bad = '''
### bad-entry

- **Severity:** Catastrophic
- **Status:** Active
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** sync

**Symptom**

**Root cause**

**Workaround / fix**

**References**
''';
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) => v.message.contains('invalid Severity "Catastrophic"'),
        ),
        isTrue,
      );
    });

    test('reports an invalid Status value', () async {
      const bad = '''
### bad-entry

- **Severity:** High
- **Status:** WontFix
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** sync

**Symptom**

**Root cause**

**Workaround / fix**

**References**
''';
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('invalid Status "WontFix"')),
        isTrue,
      );
    });

    test('reports a malformed date in Last verified', () async {
      const bad = '''
### bad-entry

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-01-01
- **Last verified:** May 21 2026
- **Area:** ci

**Symptom**

**Root cause**

**Workaround / fix**

**References**
''';
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('"Last verified"')),
        isTrue,
      );
    });

    test('reports an invalid Area value', () async {
      const bad = '''
### bad-entry

- **Severity:** Medium
- **Status:** Mitigated
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** networking

**Symptom**

**Root cause**

**Workaround / fix**

**References**
''';
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('invalid Area "networking"')),
        isTrue,
      );
    });

    test('reports a missing section header', () async {
      const bad = '''
### bad-entry

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-01-01
- **Last verified:** 2026-05-21
- **Area:** db

**Symptom**

**Root cause**

**References**
''';
      // Missing "Workaround / fix" header.
      final repo = FakeRepoView({'KNOWN_ISSUES.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('"**Workaround / fix**"')),
        isTrue,
      );
    });

    test('reports a missing KNOWN_ISSUES.md file', () async {
      final repo = FakeRepoView({});
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.message, contains('not found'));
    });
  });
}
