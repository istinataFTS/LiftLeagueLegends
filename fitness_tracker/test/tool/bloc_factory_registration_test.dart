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
  });
}
