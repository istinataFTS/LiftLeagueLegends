# Playbook — Add a use case to an existing feature

- **Task:** Add a new use case to an existing feature
- **When to use:** When a feature needs a new user-initiated action that crosses the domain boundary (e.g. "delete all sets", "export history")
- **Estimated steps:** 5
- **Last verified:** 2026-05-21
- **Canonical references:** [[use_case]], [[injection_module]], [[bloc_test]]
- **Touches:** domain, application, di, test
- **Related playbooks:** [add-feature](add-feature.md), [add-bloc-effect](add-bloc-effect.md)

---

## 0. Preconditions

- Read `.claude/reference/use_case.md` before starting.
- The feature's repository interface already exists in `lib/domain/repositories/`.
- `dart run tool/check_conventions.dart` passes before you touch anything.

---

## Steps

### 1. Create the use case file

- [ ] Create `lib/domain/usecases/<feature>/<verb>_<noun>.dart`. Mirror the structure of `.claude/reference/use_case.md` exactly — a single `Params` class and a single `call(Params params)` method.
- [ ] Import the repository interface, not the implementation. Use cases live in the domain layer and must never import from `lib/data/`.
- [ ] `Params` must be immutable (`final` fields) and extend `Equatable` with a populated `props` list.
- [ ] `call()` returns `Future<Either<Failure, T>>` where `T` is the domain result type.

### 2. Implement call() — validate then delegate

- [ ] Validate inputs inside `call()` before delegating to the repository. Return `Left(ValidationFailure(...))` for invalid inputs; do not throw.
- [ ] Delegate to the repository method. Wrap the await in `RepositoryGuard.run(...)` only if this use case is the outermost caller; if the repository already guards internally, do not double-wrap.
- [ ] Never catch exceptions in the use case — let them propagate to `RepositoryGuard` or surface as `Left(Failure)` from the repository.

### 3. Register the use case in the feature's DI module

- [ ] In `lib/injection/modules/register_<feature>_module.dart`, add `sl.registerLazySingleton(() => <UseCase>(repository: sl()))`. Mirror `.claude/reference/injection_module.md`.
- [ ] Use cases are **always** `registerLazySingleton`, never `registerFactory`.
- [ ] Verify no duplicate registration. See KNOWN_ISSUES.md [#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs).

### 4. Wire the use case into the BLoC

- [ ] Inject the use case into the BLoC constructor as a required parameter.
- [ ] Add the new event type to the BLoC file and call the use case from the event handler. See `.claude/reference/bloc.md` for the event-handler shape.
- [ ] If this use case triggers a one-shot UI signal (snackbar, navigation), emit it via `BlocEffectsMixin`. Do not call `BuildContext` from inside the BLoC.

### 5. Add use-case unit tests and BLoC test coverage

- [ ] Add `test/domain/usecases/<feature>/<verb>_<noun>_test.dart`. Mirror `.claude/reference/bloc_test.md` for the mock/stub pattern.
- [ ] Test the happy path and at least one failure path (validation failure, repository failure).
- [ ] Extend the BLoC test file with a case for the new event. Assert the emitted state and, if applicable, `await bloc.effects.first` for the effect.
- [ ] Run `flutter test test/domain/usecases/<feature>/` and `flutter test test/features/<feature>/` before moving on.

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

- **Import a concrete repository class** — use cases must import only the abstract `lib/domain/repositories/` interface. The `presentation-layer-data-import` convention rule does not fire here (use cases are in `lib/domain/`), but the dependency is still wrong architecturally.
- **Forget to add the use case to the DI module** — the BLoC's `sl()` call will throw at runtime. Always run the convention checker before pushing.
- **Duplicate DI registration** — see [KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs).
- **Missing `props` on `Params`** — `bloc_test`'s `act` comparisons use value equality. An `Equatable` class with an empty `props` list will make all instances equal, causing silent test failures.
