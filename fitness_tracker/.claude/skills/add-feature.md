# Playbook — Add a new feature end-to-end

- **Task:** Add a brand-new feature with domain entity, datasource, repository, use case, BLoC, DI module, and tests
- **When to use:** When a genuinely new capability needs its own screen, its own local storage, and its own state management — not an extension of an existing feature
- **Estimated steps:** 12
- **Last verified:** 2026-05-21
- **Canonical references:** [[datasource]], [[repository]], [[use_case]], [[bloc]], [[injection_module]], [[bloc_test]], [[widget_test]]
- **Touches:** domain, data, application, presentation, di, test
- **Related playbooks:** [add-datasource](add-datasource.md), [add-use-case](add-use-case.md), [add-bloc-effect](add-bloc-effect.md), [add-migration](add-migration.md)

---

## 0. Preconditions

- Read **all seven** `.claude/reference/` files end-to-end before starting. This playbook references them constantly.
- Agree on the feature name `<name>` (snake_case, e.g. `nutrition_goal`). All file and class names derive from it.
- `dart run tool/check_conventions.dart` passes before you touch anything.

---

## Steps

### 1. Create the directory layout

- [ ] Create the domain directories: `lib/domain/entities/`, `lib/domain/repositories/` (file: `<name>_repository.dart`), `lib/domain/usecases/<name>/`.
- [ ] Create the data directories: `lib/data/datasources/local/` (files added in step 4), `lib/data/repositories/` (file: `<name>_repository_impl.dart`).
- [ ] Create the feature directories: `lib/features/<name>/application/` and `lib/features/<name>/presentation/`.
- [ ] Create the DI module: `lib/injection/modules/register_<name>_module.dart`.

### 2. Define the domain entity

- [ ] Create `lib/domain/entities/<name>.dart`. The entity is a pure Dart class with immutable `final` fields. It must extend `Equatable` with all fields in `props`.
- [ ] No Flutter imports. No database types. No JSON serialization in the entity. Those belong in the data layer.

### 3. Define the repository interface

- [ ] Create `lib/domain/repositories/<name>_repository.dart`. Every method returns `Future<Either<Failure, T>>`. See `.claude/reference/repository.md` for the `Either` pattern.
- [ ] The interface lives in the domain layer. It imports only domain entities and `dartz`.

### 4. Create the user-scoped local datasource

- [ ] Follow `add-datasource.md` in full. The canonical is `.claude/reference/datasource.md`.
- [ ] This step produces `lib/data/datasources/local/<name>_local_datasource.dart` and `..._impl.dart`.

### 5. Create the repository implementation

- [ ] Create `lib/data/repositories/<name>_repository_impl.dart`. Mirror `.claude/reference/repository.md` exactly — `RepositoryGuard.run(...)`, `RepositoryErrorMapper`, `Either<Failure, T>`.
- [ ] `DataSourcePreference` controls whether to read from local or remote. Default to `DataSourcePreference.localFirst` for offline-resilient reads.
- [ ] The implementation is in `lib/data/`; it imports the datasource but **not** any Flutter widget.

### 6. Create the use case(s)

- [ ] Follow `add-use-case.md` for each use case. The canonical is `.claude/reference/use_case.md`.
- [ ] One use case per user action (add, delete, fetch-list, etc.). Keep each use case focused on a single operation.

### 7. Create the BLoC

- [ ] Create `lib/features/<name>/application/<name>_bloc.dart`. Put events, states, effects, and the BLoC class in the same file. Mirror `.claude/reference/bloc.md`.
- [ ] Register event handlers in the constructor via `on<Event>(_onEvent)`. Never inline lambdas.
- [ ] One-shot UI signals (snackbars, navigation) go through `BlocEffectsMixin`. See `.claude/reference/bloc.md` (lines 65–84).

### 8. Create the DI module

- [ ] In `lib/injection/modules/register_<name>_module.dart`, register: datasource as `registerLazySingleton`, repository as `registerLazySingleton<Interface>`, each use case as `registerLazySingleton`, BLoC as `registerFactory`. Mirror `.claude/reference/injection_module.md`.
- [ ] Pass `currentUserIdResolver: sl()` to the datasource constructor. This is required by `UserScopedLocalDatasource`.
- [ ] See [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons) and [KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs).

### 9. Register the module in the injection container

- [ ] In `lib/injection/injection_container.dart`, call `register<Name>Module(sl)` in the appropriate order (after any modules it depends on).
- [ ] Run `flutter analyze` and confirm no unresolved imports before proceeding.

### 10. Add a schema migration if a new table is needed

- [ ] If the feature requires a new SQLite table, follow `add-migration.md` in full before writing any datasource code that references the table.
- [ ] Never reference a table in a datasource before the migration that creates it has been merged and the `databaseVersion` bumped.

### 11. Write BLoC tests and widget tests

- [ ] Add `test/features/<name>/application/<name>_bloc_test.dart`. Mirror `.claude/reference/bloc_test.md`.
- [ ] Add `test/features/<name>/presentation/<name>_page_test.dart` (or equivalent). Mirror `.claude/reference/widget_test.md`.
- [ ] Run `flutter test test/features/<name>/` before moving on.

### 12. Connect the presentation layer

- [ ] Create the page widget(s) in `lib/features/<name>/presentation/`. The page provides the BLoC via `BlocProvider(create: (_) => sl()<NameBloc>(), ...)`.
- [ ] Wire navigation: add the route to the app's router configuration. The presentation layer must not import from `lib/data/` — only from the BLoC and domain entities.
- [ ] Confirm the `presentation-layer-data-import` convention rule passes: `dart run tool/check_conventions.dart`.

---

## Verification

Run the following from `fitness_tracker/` and confirm each passes before opening a PR:

```sh
dart format --output=none --set-exit-if-changed $(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- **BLoC registered as `registerLazySingleton`** — see [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons). The convention checker will catch this.
- **Duplicate DI registration** — see [KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs). Registering the same interface twice causes a silent runtime bug.
- **Presentation importing from `lib/data/`** — the `presentation-layer-data-import` convention rule will fail the build. Use domain entities and BLoC states only.
- **Table referenced before migration is added** — if the datasource calls `db.query('<table>')` and the table doesn't exist on a fresh install, the app crashes silently on launch. Always do the migration first (step 10).
- **Missing `currentUserIdResolver: sl()` in datasource DI registration** — `UserScopedLocalDatasource` requires it at construction time. The app will throw at the first datasource call if it is missing.
