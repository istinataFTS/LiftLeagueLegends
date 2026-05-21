import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/playbook_canonical_link.dart';
import '../../tool/convention_rules/shared.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

/// A minimal FakeRepoView populated for every test.
/// Contains:
///   - .claude/reference/bloc.md       (canonical exists)
///   - .claude/reference/datasource.md (canonical exists)
///   - KNOWN_ISSUES.md with two real anchors
///   - lib/features/log/application/workout_bloc.dart (real file)
FakeRepoView _baseRepo({Map<String, String> extra = const {}}) {
  return FakeRepoView({
    '.claude/reference/bloc.md': '# Canonical — BLoC',
    '.claude/reference/datasource.md': '# Canonical — datasource',
    'KNOWN_ISSUES.md': '''
### blocs-must-be-factories-repositories-singletons

- **Severity:** High
- **Status:** Active

**Symptom** text. **Root cause** text. **Workaround / fix** text. **References** ref.

### user-scoped-datasource-or-loud-failure

- **Severity:** Critical
- **Status:** Active

**Symptom** text. **Root cause** text. **Workaround / fix** text. **References** ref.
''',
    'lib/features/log/application/workout_bloc.dart': '// real file',
    ...extra,
  });
}

/// A fully valid playbook used as the baseline for pass and targeted-fail tests.
const _goodPlaybook = '''
# Playbook — Add a new BLoC effect

- **Task:** Add a new event, state, or one-shot effect to an existing BLoC
- **When to use:** When an existing BLoC needs a new user-initiated action
- **Estimated steps:** 2
- **Last verified:** 2026-05-21
- **Canonical references:** [[bloc]], [[datasource]]
- **Touches:** application, presentation, test

---

## 0. Preconditions

- Read `.claude/reference/bloc.md` before starting.

---

## Steps

### 1. Add the event class

- [ ] Create the event class in the BLoC file, mirroring [[bloc]].
- [ ] Check file `lib/features/log/application/workout_bloc.dart`.

### 2. Add the BLoC test

- [ ] Mirror the test from [[datasource]].
- [ ] Link to KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons.

---

## Verification

Run the following from `fitness_tracker/`:

```sh
dart format --output=none --set-exit-if-changed \$(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- BLoC registered as singleton — see [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons).
''';

/// A valid playbook with EMPTY canonical references (e.g. add-migration).
/// Must pass as long as it has a KNOWN_ISSUES anchor.
const _noCanonicalButAnchoredPlaybook = '''
# Playbook — Add a migration

- **Task:** Add a new SQLite schema migration
- **When to use:** When a new table or column is required
- **Estimated steps:** 1
- **Last verified:** 2026-05-21
- **Canonical references:**
- **Touches:** data

---

## 0. Preconditions

- Read KNOWN_ISSUES.md migration entries first.

---

## Steps

### 1. Bump the version

- [ ] Increment `EnvConfig.databaseVersion`.

---

## Verification

Run the following from `fitness_tracker/`:

```sh
dart format --output=none --set-exit-if-changed \$(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- Additive only — see [KNOWN_ISSUES.md#user-scoped-datasource-or-loud-failure](../../KNOWN_ISSUES.md#user-scoped-datasource-or-loud-failure).
''';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final rule = PlaybookCanonicalLinkRule();

  group('PlaybookCanonicalLinkRule', () {
    // -------------------------------------------------------------------------
    // Pass cases
    // -------------------------------------------------------------------------

    test('passes for a fully valid playbook', () async {
      final repo = _baseRepo(
        extra: {'.claude/skills/add-bloc-effect.md': _goodPlaybook},
      );
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('returns no violations when .claude/skills/ is empty', () async {
      final repo = _baseRepo();
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes when Canonical references: is empty but a KNOWN_ISSUES anchor '
        'is present', () async {
      final repo = _baseRepo(
        extra: {
          '.claude/skills/add-migration.md': _noCanonicalButAnchoredPlaybook,
        },
      );
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Check 1 — Required header fields
    // -------------------------------------------------------------------------

    test('reports a missing "Task:" header field', () async {
      final bad = _goodPlaybook.replaceAll('- **Task:**', '');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(violations.any((v) => v.message.contains('"Task:"')), isTrue);
    });

    test('reports a missing "Last verified:" header field', () async {
      final bad = _goodPlaybook.replaceAll('- **Last verified:**', '');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('"Last verified:"')),
        isTrue,
      );
    });

    test('reports a missing "Canonical references:" header field', () async {
      final bad = _goodPlaybook.replaceAll('- **Canonical references:**', '');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('"Canonical references:"')),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Check 2 — Last verified ISO date
    // -------------------------------------------------------------------------

    test('reports a malformed "Last verified" date', () async {
      final bad = _goodPlaybook.replaceFirst('2026-05-21', '21/05/2026');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('"Last verified"')),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Check 3 — Estimated steps vs actual count
    // -------------------------------------------------------------------------

    test('reports when Estimated steps: does not match actual count', () async {
      // _goodPlaybook has Estimated steps: 2 and two ### N. headings.
      // Replace with a wrong declared count.
      final bad = _goodPlaybook.replaceFirst(
        '- **Estimated steps:** 2',
        '- **Estimated steps:** 5',
      );
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) =>
              v.message.contains('Estimated steps: 5') &&
              v.message.contains('actual step count (2)'),
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Check 4 — [[name]] wiki-links resolve
    // -------------------------------------------------------------------------

    test('reports an unknown [[canonical]] reference', () async {
      final bad = _goodPlaybook.replaceFirst('[[bloc]]', '[[nonexistent]]');
      // Update Estimated steps to avoid a false step-count violation.
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) =>
              v.message.contains('[[nonexistent]]') &&
              v.message.contains('does not resolve'),
        ),
        isTrue,
      );
    });

    test('deduplicates violations for the same unknown [[name]]', () async {
      // Repeat the same bad link twice.
      final bad = _goodPlaybook.replaceAll('[[bloc]]', '[[ghost]]');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      final ghostViolations = violations
          .where((v) => v.message.contains('[[ghost]]'))
          .toList();
      expect(ghostViolations.length, 1);
    });

    // -------------------------------------------------------------------------
    // Check 5 — KNOWN_ISSUES.md anchors resolve
    // -------------------------------------------------------------------------

    test('reports a KNOWN_ISSUES.md anchor that does not exist', () async {
      final bad = _goodPlaybook.replaceFirst(
        'blocs-must-be-factories-repositories-singletons',
        'this-anchor-does-not-exist',
      );
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) =>
              v.message.contains('this-anchor-does-not-exist') &&
              v.message.contains('does not match any heading'),
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Check 6 — Concrete source-file paths exist
    // -------------------------------------------------------------------------

    test('reports a backtick-wrapped Dart path that does not exist', () async {
      const bad = '''
# Playbook — test

- **Task:** test task
- **When to use:** always
- **Estimated steps:** 1
- **Last verified:** 2026-05-21
- **Canonical references:** [[bloc]]
- **Touches:** application

---

## 0. Preconditions

---

## Steps

### 1. Do the thing

- [ ] Open `lib/nonexistent/file.dart` and edit it.

---

## Verification

Run the following from `fitness_tracker/`:

```sh
dart format --output=none --set-exit-if-changed \$(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- See [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons).
''';
      final repo = _baseRepo(extra: {'.claude/skills/test.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any((v) => v.message.contains('lib/nonexistent/file.dart')),
        isTrue,
      );
    });

    test(
      'skips template-placeholder paths containing angle brackets',
      () async {
        const content = '''
# Playbook — test

- **Task:** test task
- **When to use:** always
- **Estimated steps:** 1
- **Last verified:** 2026-05-21
- **Canonical references:** [[bloc]]
- **Touches:** domain

---

## 0. Preconditions

---

## Steps

### 1. Create the file

- [ ] Create `lib/features/<name>/application/<name>_bloc.dart`.

---

## Verification

Run the following from `fitness_tracker/`:

```sh
dart format --output=none --set-exit-if-changed \$(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- See [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons).
''';
        final repo = _baseRepo(extra: {'.claude/skills/test.md': content});
        final violations = await rule.check(repo);
        // Template paths like `lib/features/<name>/...` must NOT be reported.
        expect(
          violations.any((v) => v.message.contains('non-existent file')),
          isFalse,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Check 7 — Verification block commands
    // -------------------------------------------------------------------------

    test(
      'reports a missing "flutter analyze" in the verification block',
      () async {
        final bad = _goodPlaybook.replaceFirst('flutter analyze\n', '');
        final repo = _baseRepo(
          extra: {'.claude/skills/add-bloc-effect.md': bad},
        );
        final violations = await rule.check(repo);
        expect(
          violations.any((v) => v.message.contains('flutter analyze')),
          isTrue,
        );
      },
    );

    test('reports a missing "dart run tool/check_conventions.dart"', () async {
      final bad = _goodPlaybook.replaceFirst(
        'dart run tool/check_conventions.dart\n',
        '',
      );
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) => v.message.contains('dart run tool/check_conventions.dart'),
        ),
        isTrue,
      );
    });

    // -------------------------------------------------------------------------
    // Check 8 — Must be anchored to at least one canonical or KNOWN_ISSUES entry
    // -------------------------------------------------------------------------

    test(
      'reports a playbook with no canonicals and no KNOWN_ISSUES anchors',
      () async {
        const unanchored = '''
# Playbook — Unanchored

- **Task:** some task
- **When to use:** sometimes
- **Estimated steps:** 1
- **Last verified:** 2026-05-21
- **Canonical references:**
- **Touches:** other

---

## 0. Preconditions

---

## Steps

### 1. Do something

- [ ] Do it.

---

## Verification

Run the following from `fitness_tracker/`:

```sh
dart format --output=none --set-exit-if-changed \$(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

No links here at all.
''';
        final repo = _baseRepo(
          extra: {'.claude/skills/unanchored.md': unanchored},
        );
        final violations = await rule.check(repo);
        expect(
          violations.any(
            (v) => v.message.contains('no [[canonical]] references'),
          ),
          isTrue,
        );
      },
    );

    // -------------------------------------------------------------------------
    // Violation metadata
    // -------------------------------------------------------------------------

    test('violation has the correct ruleId', () async {
      final bad = _goodPlaybook.replaceAll('- **Task:**', '');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(violations.first.ruleId, equals('playbook-canonical-link'));
    });

    test('violation filePath is the playbook path', () async {
      final bad = _goodPlaybook.replaceAll('- **Task:**', '');
      final repo = _baseRepo(extra: {'.claude/skills/add-bloc-effect.md': bad});
      final violations = await rule.check(repo);
      expect(
        violations.any(
          (v) => v.filePath == '.claude/skills/add-bloc-effect.md',
        ),
        isTrue,
      );
    });
  });
}
