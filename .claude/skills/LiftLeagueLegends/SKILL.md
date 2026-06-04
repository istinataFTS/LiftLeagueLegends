```markdown
# LiftLeagueLegends Development Patterns

> Auto-generated skill from repository analysis

## Overview

This skill provides a comprehensive guide to the development patterns and workflows used in the LiftLeagueLegends TypeScript codebase. It covers coding conventions, step-by-step feature and bugfix workflows, testing patterns, and common development commands. The repository focuses on muscle stimulus calculations and fitness tracking logic, with a strong emphasis on domain-driven design and test coverage.

## Coding Conventions

**File Naming**
- Use `snake_case` for all file names.
  - Example: `muscle_stimulus_calculator.ts`

**Import Style**
- Use relative imports for all modules.
  - Example:
    ```typescript
    import { calculateStimulus } from './muscle_stimulus_calculator';
    ```

**Export Style**
- Use named exports.
  - Example:
    ```typescript
    // In muscle_stimulus_calculator.ts
    export function calculateStimulus(...) { ... }
    ```

**Commit Messages**
- Follow [Conventional Commits](https://www.conventionalcommits.org/) with prefixes: `fix`, `feat`, `chore`.
  - Example: `feat: add muscle fatigue calculation to stimulus model`

## Workflows

### Feature Development with Domain and Test Coverage
**Trigger:** When adding a new calculated metric or feature to the muscle stimulus system  
**Command:** `/new-muscle-stimulus-feature`

1. **Update or add domain entities and usecases**  
   - Create or modify relevant files in `domain/entities/` and `domain/usecases/`.
2. **Modify or extend data models and repositories**  
   - Update files in `data/models/` and `data/repositories/` to support the new feature.
3. **Update data sources**  
   - Adjust files in `data/datasources/local/` for new data requirements.
4. **Update configuration or constants**  
   - Modify `core/constants/database_tables.ts` or any relevant config files.
5. **Implement or update integration points**  
   - Update demo or runtime files as needed.
6. **Write or update tests**  
   - Add or update tests for data sources, models, usecases, and integration.
     - Example test file: `muscle_stimulus_calculator.test.ts`
7. **Update migration or database helpers**  
   - If schema changes are needed, update migration scripts or helpers.

**Example:**
```typescript
// domain/entities/muscle_metric.ts
export interface MuscleMetric {
  id: string;
  value: number;
  timestamp: Date;
}

// domain/usecases/calculate_new_metric.ts
export function calculateNewMetric(input: InputType): OutputType { ... }
```

### Bugfix with Targeted Test Update
**Trigger:** When fixing a logic or calculation bug in a utility or usecase  
**Command:** `/bugfix-with-tests`

1. **Identify and fix the bug**  
   - Locate the issue in core utility or usecase files.
2. **Update or add tests**  
   - Write tests that reproduce the bug and verify the fix.
   - Example:
     ```typescript
     // core/utils/math_utils.test.ts
     import { fixedFunction } from './math_utils';

     test('handles edge case correctly', () => {
       expect(fixedFunction(buggyInput)).toBe(expectedOutput);
     });
     ```
3. **Document the issue or fix**  
   - Add a note to `KNOWN_ISSUES.md` if relevant.

## Testing Patterns

- Test files use the pattern: `*.test.ts`
- Testing framework is not explicitly specified; use standard TypeScript/Jest patterns.
- Tests are colocated with the modules they cover.
- Example test:
  ```typescript
  // muscle_stimulus_calculator.test.ts
  import { calculateStimulus } from './muscle_stimulus_calculator';

  test('calculates correct stimulus for input', () => {
    expect(calculateStimulus({ ... })).toBe(expectedValue);
  });
  ```

## Commands

| Command                     | Purpose                                                         |
|-----------------------------|-----------------------------------------------------------------|
| /new-muscle-stimulus-feature| Start a new feature with domain, data, and test coverage        |
| /bugfix-with-tests          | Fix a bug and update/add targeted tests                         |
```
