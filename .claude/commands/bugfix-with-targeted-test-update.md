---
name: bugfix-with-targeted-test-update
description: Workflow command scaffold for bugfix-with-targeted-test-update in LiftLeagueLegends.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /bugfix-with-targeted-test-update

Use this workflow when working on **bugfix-with-targeted-test-update** in `LiftLeagueLegends`.

## Goal

Fixes a bug in core logic or utilities and updates or adds corresponding tests to ensure correctness.

## Common Files

- `fitness_tracker/lib/core/utils/*.dart`
- `fitness_tracker/lib/domain/usecases/**/*.dart`
- `fitness_tracker/test/core/utils/*_test.dart`
- `fitness_tracker/test/domain/usecases/**/*.dart`
- `fitness_tracker/KNOWN_ISSUES.md`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Identify and fix the bug in the relevant core utility or usecase file.
- Update or add tests to cover the bug scenario.
- Document the issue or fix in the known issues log.

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.