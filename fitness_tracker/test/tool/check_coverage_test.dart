// Unit tests for the lcov.info parser exposed via `Process.run` of
// `tool/check_coverage.dart`. The parser itself is private to the script,
// so we exercise the binary end-to-end against synthetic fixtures.
//
// Each test writes a fake lcov.info to a temp dir, sets it as the CWD, and
// runs the script — asserting on exit code + stdout/stderr.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late String repoRoot;

  setUpAll(() {
    // The flutter_test working directory is the package root.
    repoRoot = Directory.current.path;
  });

  Future<ProcessResult> runChecker(String tempDir) {
    // runInShell: true makes Windows resolve `dart` via cmd.exe, which
    // finds `dart.bat` on PATH. Without it the test fails on Windows with
    // "The system cannot find the file specified."
    return Process.run(
      'dart',
      ['run', p.join(repoRoot, 'tool', 'check_coverage.dart')],
      workingDirectory: tempDir,
      runInShell: true,
    );
  }

  Future<Directory> withLcov(String body) async {
    final temp = await Directory.systemTemp.createTemp('check_cov_');
    final cov = Directory(p.join(temp.path, 'coverage'))
      ..createSync(recursive: true);
    await File(p.join(cov.path, 'lcov.info')).writeAsString(body);
    return temp;
  }

  test('exits 2 when coverage/lcov.info is missing', () async {
    final temp = await Directory.systemTemp.createTemp('check_cov_');
    addTearDown(() async => temp.delete(recursive: true));

    final r = await runChecker(temp.path);

    expect(r.exitCode, 2);
    expect(r.stderr.toString(), contains('lcov.info not found'));
  });

  test('exits 2 when the file is empty (no records)', () async {
    final temp = await withLcov('');
    addTearDown(() async => temp.delete(recursive: true));

    final r = await runChecker(temp.path);

    expect(r.exitCode, 2);
    expect(r.stderr.toString(), contains('contained no file records'));
  });

  test('exits 0 when every enforced prefix meets its threshold', () async {
    // 80% in lib/domain/, 70% in lib/data/, 70% in lib/core/, 50% in features.
    const body = '''
SF:lib/domain/use_case.dart
LF:10
LH:8
end_of_record
SF:lib/data/repo.dart
LF:10
LH:9
end_of_record
SF:lib/core/util.dart
LF:10
LH:9
end_of_record
SF:lib/features/home/home_bloc.dart
LF:10
LH:9
end_of_record
''';
    final temp = await withLcov(body);
    addTearDown(() async => temp.delete(recursive: true));

    final r = await runChecker(temp.path);

    expect(r.exitCode, 0, reason: r.stderr.toString());
    expect(
      r.stdout.toString(),
      contains('all enforced prefixes meet their thresholds'),
    );
  });

  test('exits 1 when a prefix is below threshold', () async {
    // lib/domain/ would be at 40% — below the 75% threshold.
    const body = '''
SF:lib/domain/use_case.dart
LF:10
LH:4
end_of_record
SF:lib/data/repo.dart
LF:10
LH:9
end_of_record
SF:lib/core/util.dart
LF:10
LH:9
end_of_record
SF:lib/features/home/home_bloc.dart
LF:10
LH:9
end_of_record
''';
    final temp = await withLcov(body);
    addTearDown(() async => temp.delete(recursive: true));

    final r = await runChecker(temp.path);

    expect(r.exitCode, 1);
    expect(r.stderr.toString(), contains('lib/domain/'));
    expect(r.stderr.toString(), contains('below threshold'));
  });

  test(
    'files outside every prefix do not gate but still appear in the report',
    () async {
      // lib/app/ has no threshold — it should show up as "(unmatched)" with
      // status "(not enforced)" and not affect the exit code.
      const body = '''
SF:lib/domain/use_case.dart
LF:10
LH:8
end_of_record
SF:lib/data/repo.dart
LF:10
LH:9
end_of_record
SF:lib/core/util.dart
LF:10
LH:9
end_of_record
SF:lib/features/home/home_bloc.dart
LF:10
LH:9
end_of_record
SF:lib/app/auth_gate.dart
LF:10
LH:0
end_of_record
''';
      final temp = await withLcov(body);
      addTearDown(() async => temp.delete(recursive: true));

      final r = await runChecker(temp.path);

      expect(r.exitCode, 0, reason: r.stderr.toString());
      expect(r.stdout.toString(), contains('(unmatched)'));
      expect(r.stdout.toString(), contains('(not enforced)'));
    },
  );

  test('normalises Windows-style backslashes in SF: paths', () async {
    // sqflite/Flutter on Windows may emit backslashes; ensure they're
    // normalised so the prefix match still works.
    const body = '''
SF:lib\\domain\\use_case.dart
LF:10
LH:8
end_of_record
SF:lib\\data\\repo.dart
LF:10
LH:9
end_of_record
SF:lib\\core\\util.dart
LF:10
LH:9
end_of_record
SF:lib\\features\\home\\home_bloc.dart
LF:10
LH:9
end_of_record
''';
    final temp = await withLcov(body);
    addTearDown(() async => temp.delete(recursive: true));

    final r = await runChecker(temp.path);

    expect(r.exitCode, 0, reason: r.stderr.toString());
    expect(r.stdout.toString(), contains('lib/domain/'));
  });
}
