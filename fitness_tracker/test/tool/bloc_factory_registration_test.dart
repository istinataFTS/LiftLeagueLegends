import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/bloc_factory_registration.dart';
import '../../tool/convention_rules/shared.dart';

void main() {
  final rule = BlocFactoryRegistrationRule();

  group('BlocFactoryRegistrationRule', () {
    test('passes when all BLoCs are registerFactory (explicit generic)', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_log_module.dart':
            'sl.registerFactory<WorkoutBloc>(\n'
            '  () => WorkoutBloc(useCase: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes when all BLoCs are registerFactory (inferred generic)', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_log_module.dart':
            'sl.registerFactory(() => WorkoutBloc(useCase: sl()));\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('passes when a non-Bloc class is registerLazySingleton', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_core_module.dart':
            'sl.registerLazySingleton<AppRepository>(\n'
            '  () => AppRepositoryImpl(),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('reports a violation for registerLazySingleton<XxxBloc> (explicit generic)', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            'sl.registerLazySingleton<FooBloc>(\n'
            '  () => FooBloc(useCase: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'bloc-factory-registration');
      expect(violations.first.line, 1);
    });

    test('reports a violation for registerLazySingleton<XxxCubit> (explicit generic)', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            'sl.registerLazySingleton<FooCubit>(() => FooCubit());\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'bloc-factory-registration');
    });

    test('reports a violation for inferred-generic bloc singleton', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            'sl.registerLazySingleton(() => FooBloc(useCase: sl()));\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'bloc-factory-registration');
    });

    test('waiver on preceding line suppresses violation', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_settings_module.dart':
            '// convention-checker:allow=bloc-factory-registration reason=shared cross-page state for Settings and VoiceSettings\n'
            'sl.registerLazySingleton<AppSettingsCubit>(\n'
            '  () => AppSettingsCubit(repository: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('waiver with reason shorter than 10 chars does not suppress violation', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            '// convention-checker:allow=bloc-factory-registration reason=todo\n'
            'sl.registerLazySingleton<FooBloc>(() => FooBloc());\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    test('waiver for wrong rule-id does not suppress violation', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            '// convention-checker:allow=some-other-rule reason=shared cross-page state\n'
            'sl.registerLazySingleton<FooBloc>(() => FooBloc());\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    // Multi-line fixtures — the dart-formatter routinely wraps long lines so
    // `registerLazySingleton(\n  () => XxxBloc(` spans two lines. A per-line
    // scan cannot match across the wrap; these fixtures verify the whole-file
    // scan detects and correctly suppresses multi-line singletons.

    test('passes for multi-line inferred-generic singleton with waiver on preceding line', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            '// convention-checker:allow=bloc-factory-registration reason=shared cross-page state for AppSettings\n'
            'sl.registerLazySingleton(\n'
            '  () => FooBloc(useCase: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('reports a violation with correct line number for multi-line inferred-generic singleton with no waiver', () async {
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            'sl.registerLazySingleton(\n'
            '  () => FooBloc(useCase: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
      expect(violations.first.ruleId, 'bloc-factory-registration');
      expect(violations.first.line, 1);
    });

    test('reports a violation when waiver is on the lambda line of the multi-line block, not the preceding line', () async {
      // The waiver is placed inline on the `() => FooBloc(` continuation line
      // (lineIndex 1). The match starts at `registerLazySingleton` (lineIndex 0).
      // hasWaiver checks [0, -1] — the lambda line is not in scope.
      final repo = FakeRepoView({
        'lib/injection/modules/register_foo_module.dart':
            'sl.registerLazySingleton(\n'
            '  () => FooBloc( // convention-checker:allow=bloc-factory-registration reason=shared cross-page state\n'
            '    useCase: sl()),\n'
            ');\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });
  });
}
