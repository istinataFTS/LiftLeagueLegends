---
name: feature-development-with-domain-and-test-coverage
description: Workflow command scaffold for feature-development-with-domain-and-test-coverage in LiftLeagueLegends.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /feature-development-with-domain-and-test-coverage

Use this workflow when working on **feature-development-with-domain-and-test-coverage** in `LiftLeagueLegends`.

## Goal

Implements a new feature or projection, updating domain entities, usecases, repositories, data sources, and models, along with comprehensive test coverage.

## Common Files

- `fitness_tracker/lib/domain/entities/*.dart`
- `fitness_tracker/lib/domain/usecases/**/*.dart`
- `fitness_tracker/lib/domain/repositories/*.dart`
- `fitness_tracker/lib/data/models/*.dart`
- `fitness_tracker/lib/data/repositories/*.dart`
- `fitness_tracker/lib/data/datasources/local/*.dart`

## Suggested Sequence

1. Understand the current state and failure mode before editing.
2. Make the smallest coherent change that satisfies the workflow goal.
3. Run the most relevant verification for touched files.
4. Summarize what changed and what still needs review.

## Typical Commit Signals

- Update or add domain entities and usecases related to the feature.
- Modify or extend data models and repositories to support the new feature.
- Update data sources to handle new data requirements.
- Update configuration or constants as needed.
- Implement or update integration points (e.g., demo runtime).

## Notes

- Treat this as a scaffold, not a hard-coded script.
- Update the command if the workflow evolves materially.