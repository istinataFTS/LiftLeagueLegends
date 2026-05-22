import 'shared.dart';

/// A `State<...>` class must not declare a `final` or `late final` field
/// whose type ends in `Bloc` or `Cubit`. Field-capturing a BLoC/Cubit
/// from `sl<>()` (or any source) in widget state produces a ghost
/// instance distinct from whatever `BlocProvider` is up the tree. With
/// factory-registered BLoCs/Cubits (the canonical convention), events
/// dispatched to the field-captured instance are silently lost — the
/// pages the user actually interacts with never see them.
///
/// This rule is the guardrail that would have caught the original
/// silent-dispatch bug (`VoiceBloc` holding `_workoutBloc`) and the
/// `BottomNavigation` `_voiceSettingsCubit` field capture.
///
/// Correct patterns:
///
/// - Read lazily inside `build` or `didChangeDependencies`:
///   `final cubit = context.read<XxxCubit>();`
/// - Accept the bloc/cubit as a constructor parameter on the
///   `StatefulWidget` (NOT the `State<>`) for test injection, then
///   read it via `widget.xxxCubit` inside `State<>`.
///
/// The type-token boundary in the regex (`\b` immediately after
/// `Bloc`/`Cubit`) ensures legitimate types like `MyBlocConfig` or
/// `BlocBase` are not flagged.
///
/// Method-local declarations are accepted as a false-positive risk —
/// `final XxxBloc x = …;` inside a method body is itself an
/// anti-pattern, and waivers are available for the rare legitimate
/// case. The rule prioritises catching the field-level pattern reliably
/// over precise method-local exclusion.
///
/// Waiver comment:
///
/// ```dart
/// // convention-checker:allow=widget-state-bloc-field reason=...
/// ```
final class WidgetStateBlocFieldRule implements ConventionRule {
  @override
  String get id => 'widget-state-bloc-field';

  @override
  String get description =>
      'State<...> classes must not field-capture BLoCs or Cubits.';

  /// Header of a `State<...>` class declaration. Matches both
  /// `class _FooState extends State<Foo>` and `class FooState extends State<Foo>`
  /// and tolerates whitespace around `<` `>`.
  ///
  /// Whole-file regex with line-number recovery (per the
  /// `bloc-factory-registration` precedent — multi-line patterns must not
  /// rely on per-line iteration).
  static final _stateClassHeaderPattern = RegExp(
    r'class\s+\w+\s+extends\s+State\s*<\s*\w+\s*>',
  );

  /// A field declaration of the shape `final XxxBloc _x` or
  /// `late final XxxCubit _x`. The type identifier MUST end at the
  /// `Bloc`/`Cubit` token (followed by whitespace) so `MyBlocConfig`
  /// does not false-positive.
  ///
  /// The trailing `[;=]` requires the declaration to terminate (`;`) or
  /// begin an initializer (`=`), distinguishing field shapes from method
  /// signatures like `Future<MyBloc> getBloc() { … }`.
  static final _fieldPattern = RegExp(
    r'(?:late\s+)?final\s+\w*(?:Bloc|Cubit)\s+\w+\s*[;=]',
  );

  @override
  Future<List<Violation>> check(RepoView repo) async {
    final files = await repo.listDartFiles('lib');
    final violations = <Violation>[];

    for (final path in files) {
      final raw = await repo.readFile(path);
      if (raw == null) continue;
      final content = raw.replaceAll('\r\n', '\n');

      if (!_stateClassHeaderPattern.hasMatch(content)) continue;

      final lines = content.split('\n');

      for (final header in _stateClassHeaderPattern.allMatches(content)) {
        final braceStart = content.indexOf('{', header.end);
        if (braceStart < 0) continue;
        final braceEnd = _findMatchingBrace(content, braceStart);
        if (braceEnd < 0) continue;

        final body = content.substring(braceStart + 1, braceEnd);

        for (final field in _fieldPattern.allMatches(body)) {
          // Skip method-local declarations: those live at depth > 0 within
          // the class body. Class-member fields are at depth 0.
          final depth = _depthAt(body, field.start);
          if (depth != 0) continue;

          final absStart = braceStart + 1 + field.start;
          final lineNum =
              '\n'.allMatches(content.substring(0, absStart)).length + 1;
          if (hasWaiver(lines, lineNum - 1, id)) continue;

          violations.add(
            Violation(
              ruleId: id,
              filePath: path,
              line: lineNum,
              message:
                  'State<...> class declares a BLoC/Cubit field. With '
                  'factory-registered BLoCs/Cubits this produces a ghost '
                  'instance separate from any BlocProvider in the tree.',
              fixHint:
                  'Read via context.read<X>() / context.watch<X>() inside '
                  'build or didChangeDependencies, or accept the bloc as a '
                  'constructor parameter on the StatefulWidget (not the '
                  "State<>). See KNOWN_ISSUES.md "
                  '#widget-state-must-not-field-capture-factory-blocs-or-cubits.',
            ),
          );
        }
      }
    }

    return violations;
  }

  /// Returns the index of the matching `}` for the `{` at [openIdx], or -1
  /// if unmatched. Naive char-by-char counting; does not skip strings or
  /// comments. Accepted because State class bodies do not typically
  /// contain `{`/`}` in string literals or comments at the file scale we
  /// scan, and any false start surfaces a waiver-eligible diagnostic.
  int _findMatchingBrace(String content, int openIdx) {
    var depth = 0;
    for (var i = openIdx; i < content.length; i++) {
      final c = content[i];
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// Brace depth of position [pos] within [body], where [body] starts at
  /// depth 0 (just inside the class's opening `{`).
  int _depthAt(String body, int pos) {
    var depth = 0;
    for (var i = 0; i < pos; i++) {
      final c = body[i];
      if (c == '{') {
        depth++;
      } else if (c == '}') {
        depth--;
      }
    }
    return depth;
  }
}
