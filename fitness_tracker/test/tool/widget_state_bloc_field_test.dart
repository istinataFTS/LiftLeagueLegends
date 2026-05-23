import 'package:flutter_test/flutter_test.dart';

import '../../tool/convention_rules/shared.dart';
import '../../tool/convention_rules/widget_state_bloc_field.dart';

void main() {
  final rule = WidgetStateBlocFieldRule();

  group('WidgetStateBlocFieldRule', () {
    test('passes when State<...> has no BLoC/Cubit field', () async {
      final repo = FakeRepoView({
        'lib/features/foo/presentation/foo_page.dart':
            'class FooPage extends StatefulWidget {\n'
            '  const FooPage({super.key});\n'
            '  @override\n'
            '  State<FooPage> createState() => _FooPageState();\n'
            '}\n'
            'class _FooPageState extends State<FooPage> {\n'
            '  int _counter = 0;\n'
            '  @override\n'
            '  Widget build(BuildContext context) => Container();\n'
            '}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'passes when StatefulWidget (not State) holds a BLoC constructor parameter',
      () async {
        // Constructor-injected blocs on the StatefulWidget itself are the
        // canonical test-injection pattern and must NOT be flagged.
        final repo = FakeRepoView({
          'lib/features/foo/presentation/foo_page.dart':
              'class FooPage extends StatefulWidget {\n'
              '  const FooPage({super.key, this.fooBloc});\n'
              '  final FooBloc? fooBloc;\n'
              '  @override\n'
              '  State<FooPage> createState() => _FooPageState();\n'
              '}\n'
              'class _FooPageState extends State<FooPage> {\n'
              '  @override\n'
              '  Widget build(BuildContext context) => Container();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test(
      'passes when type name contains Bloc/Cubit but does not end in it',
      () async {
        // The type-token boundary check ensures `MyBlocConfig` and
        // `BlocBaseHolder` are NOT flagged.
        final repo = FakeRepoView({
          'lib/features/foo/presentation/foo_page.dart':
              'class _FooPageState extends State<FooPage> {\n'
              '  final MyBlocConfig _config = MyBlocConfig();\n'
              '  late final BlocBaseHolder _holder;\n'
              '  @override\n'
              '  Widget build(BuildContext context) => Container();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    test(
      'reports a violation for a late final XxxCubit field captured in State',
      () async {
        final repo = FakeRepoView({
          'lib/presentation/navigation/bottom_navigation.dart':
              'class _BottomNavigationState extends State<BottomNavigation> {\n'
              '  late final VoiceSettingsCubit _voiceSettingsCubit;\n'
              '  @override\n'
              '  void initState() {\n'
              '    super.initState();\n'
              '    _voiceSettingsCubit = sl<VoiceSettingsCubit>();\n'
              '  }\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.ruleId, 'widget-state-bloc-field');
        expect(violations.first.line, 2);
      },
    );

    test(
      'reports a violation for a final XxxBloc field captured in State',
      () async {
        final repo = FakeRepoView({
          'lib/features/foo/presentation/foo_page.dart':
              'class _FooPageState extends State<FooPage> {\n'
              '  final FooBloc _fooBloc = sl<FooBloc>();\n'
              '  @override\n'
              '  Widget build(BuildContext context) => Container();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        expect(violations.first.line, 2);
      },
    );

    test(
      'reports two violations when State holds both a Bloc and a Cubit field',
      () async {
        final repo = FakeRepoView({
          'lib/features/foo/presentation/foo_page.dart':
              'class _FooPageState extends State<FooPage> {\n'
              '  final FooBloc _fooBloc = sl<FooBloc>();\n'
              '  late final BarCubit _barCubit;\n'
              '  @override\n'
              '  Widget build(BuildContext context) => Container();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(2));
        expect(violations.map((v) => v.line), containsAll(<int>[2, 3]));
      },
    );

    test('does not flag method-local final BLoC/Cubit declarations', () async {
      // Method-local `final XxxBloc x = ...;` lives inside a `{...}` block
      // nested in the State body — depth > 0 — and is excluded by the
      // depth-tracking scan. (It's still an anti-pattern but a different one.)
      final repo = FakeRepoView({
        'lib/features/foo/presentation/foo_page.dart':
            'class _FooPageState extends State<FooPage> {\n'
            '  @override\n'
            '  Widget build(BuildContext context) {\n'
            '    final FooBloc bloc = context.read<FooBloc>();\n'
            '    return Container();\n'
            '  }\n'
            '}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('waiver on preceding line suppresses violation', () async {
      final repo = FakeRepoView({
        'lib/features/foo/presentation/foo_page.dart':
            'class _FooPageState extends State<FooPage> {\n'
            '  // convention-checker:allow=widget-state-bloc-field reason=test harness owns lifecycle deliberately\n'
            '  late final FooBloc _fooBloc;\n'
            '  @override\n'
            '  Widget build(BuildContext context) => Container();\n'
            '}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test('waiver for wrong rule-id does not suppress violation', () async {
      final repo = FakeRepoView({
        'lib/features/foo/presentation/foo_page.dart':
            'class _FooPageState extends State<FooPage> {\n'
            '  // convention-checker:allow=some-other-rule reason=valid 10-char reason here\n'
            '  late final FooBloc _fooBloc;\n'
            '}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, hasLength(1));
    });

    test('does not scan files outside lib/', () async {
      final repo = FakeRepoView({
        'test/features/foo/foo_page_test.dart':
            'class _FakeState extends State<Fake> {\n'
            '  final FooBloc _bloc = FooBloc();\n'
            '}\n',
      });
      final violations = await rule.check(repo);
      expect(violations, isEmpty);
    });

    test(
      'does not flag non-State classes that have BLoC/Cubit fields',
      () async {
        // BLoCs are routinely declared as fields in *other* BLoCs / services /
        // injection modules. The rule is scoped to `State<...>` classes only.
        final repo = FakeRepoView({
          'lib/features/foo/application/foo_service.dart':
              'class FooService {\n'
              '  final BarBloc _barBloc = BarBloc();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, isEmpty);
      },
    );

    // Multi-line fixture: dart-formatter may wrap a long type expression
    // across the `final` declaration. The regex tolerates whitespace
    // (including newlines) between `final`, the type, and the identifier.

    test(
      'reports a violation when the type is wrapped to the next line by dart-format',
      () async {
        // `late final\n      VoiceSettingsCubit _x;` — dart-format may break
        // after `late final` for very long type+identifier combinations.
        // The `\s+` separators in the field pattern span newlines.
        final repo = FakeRepoView({
          'lib/features/foo/presentation/foo_page.dart':
              'class _FooPageState extends State<FooPage> {\n'
              '  late final\n'
              '      VoiceSettingsCubit _voiceSettingsCubit;\n'
              '  @override\n'
              '  Widget build(BuildContext context) => Container();\n'
              '}\n',
        });
        final violations = await rule.check(repo);
        expect(violations, hasLength(1));
        // The violation's reported line is the start of the match — the
        // `late final` line — which is acceptable: editors jump there and
        // the eye sees the wrapped declaration immediately below.
        expect(violations.first.line, 2);
      },
    );
  });
}
