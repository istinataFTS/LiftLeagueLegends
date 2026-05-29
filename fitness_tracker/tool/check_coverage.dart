import 'dart:io';

/// Coverage gate. Parses `coverage/lcov.info` (produced by
/// `flutter test --coverage`) and fails if any directory listed in
/// [_thresholds] has line coverage below its minimum percentage.
///
/// Files under a directory not listed in [_thresholds] are not enforced —
/// they still contribute to the totals printed, but won't block CI. This
/// keeps the gate forward-looking: add a prefix here when a directory's
/// coverage stabilises and you want to lock the floor in.
///
/// Run locally:
/// ```
/// flutter test --coverage
/// dart run tool/check_coverage.dart
/// ```
///
/// Bumping thresholds: only ratchet up. Lowering a threshold to make CI
/// pass is a code smell — the right response is to add tests, not relax
/// the gate. If a baseline truly cannot be met (e.g. a feature is being
/// gutted), document the relaxation in the PR description.

/// Minimum line coverage percentage, per `lib/` subdirectory.
///
/// Longest-prefix match wins; a file matched against multiple prefixes is
/// only counted toward the most-specific one. Files outside every prefix
/// are still printed in the summary but do not gate.
///
/// Initial values were measured on the commit that introduced this gate
/// and set ~2 percentage points below current to absorb transient PR-level
/// dips. Only *raise* a threshold; lowering one to make CI pass is a code
/// smell. If a baseline genuinely cannot be met (e.g. a feature is being
/// gutted), call out the relaxation explicitly in the PR description.
///
/// Measured baseline (2026-05-29):
///   lib/domain/   65.9%   (70 files, 1037/1574)
///   lib/data/     49.3%   (61 files, 2038/4137)
///   lib/core/     76.0%   (56 files,  883/1162)
///   lib/features/ 67.3%   (94 files, 4814/7153)
const Map<String, double> _thresholds = {
  'lib/domain/': 63,
  'lib/data/': 47,
  'lib/core/': 73,
  'lib/features/': 65,
};

const String _lcovPath = 'coverage/lcov.info';

Future<int> _main() async {
  final lcovFile = File(_lcovPath);
  if (!lcovFile.existsSync()) {
    stderr.writeln(
      'check_coverage: $_lcovPath not found. Run `flutter test --coverage` '
      'first to produce it.',
    );
    return 2;
  }

  final files = _parseLcov(await lcovFile.readAsString());
  if (files.isEmpty) {
    stderr.writeln('check_coverage: $_lcovPath contained no file records.');
    return 2;
  }

  // Group by longest matching prefix.
  final prefixes = _thresholds.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  final perPrefix = <String, _PrefixTotals>{
    for (final p in prefixes) p: _PrefixTotals(),
  };
  final unmatched = _PrefixTotals();

  for (final f in files) {
    final prefix = prefixes.firstWhere(
      (p) => f.path.startsWith(p),
      orElse: () => '',
    );
    final bucket = prefix.isEmpty ? unmatched : perPrefix[prefix]!;
    bucket.linesFound += f.linesFound;
    bucket.linesHit += f.linesHit;
    bucket.fileCount += 1;
  }

  // Print summary.
  stdout.writeln('check_coverage: per-prefix line coverage\n');
  stdout.writeln(
    '  ${'prefix'.padRight(20)} ${'files'.padLeft(6)}  '
    '${'hit/total'.padLeft(15)}  ${'cov%'.padLeft(6)}  '
    '${'min%'.padLeft(5)}  status',
  );

  final violations = <String>[];
  for (final entry in perPrefix.entries) {
    final t = entry.value;
    final pct = t.linesFound == 0 ? 0.0 : t.linesHit * 100.0 / t.linesFound;
    final min = _thresholds[entry.key]!;
    final ok = pct >= min;

    stdout.writeln(
      '  ${entry.key.padRight(20)} ${t.fileCount.toString().padLeft(6)}  '
      '${'${t.linesHit}/${t.linesFound}'.padLeft(15)}  '
      '${pct.toStringAsFixed(1).padLeft(6)}  '
      '${min.toStringAsFixed(0).padLeft(5)}  ${ok ? 'OK' : 'FAIL'}',
    );

    if (!ok) {
      violations.add(
        '${entry.key}: ${pct.toStringAsFixed(1)}% < ${min.toStringAsFixed(0)}% '
        '(${t.linesHit}/${t.linesFound} lines covered across ${t.fileCount} files)',
      );
    }
  }

  if (unmatched.fileCount > 0) {
    final pct = unmatched.linesFound == 0
        ? 0.0
        : unmatched.linesHit * 100.0 / unmatched.linesFound;
    stdout.writeln(
      '  ${'(unmatched)'.padRight(20)} '
      '${unmatched.fileCount.toString().padLeft(6)}  '
      '${'${unmatched.linesHit}/${unmatched.linesFound}'.padLeft(15)}  '
      '${pct.toStringAsFixed(1).padLeft(6)}  '
      '${'-'.padLeft(5)}  (not enforced)',
    );
  }

  stdout.writeln('');

  if (violations.isEmpty) {
    stdout.writeln(
      'check_coverage: all enforced prefixes meet their thresholds.',
    );
    return 0;
  }

  stderr.writeln(
    '\ncheck_coverage: ${violations.length} prefix(es) below threshold:',
  );
  for (final v in violations) {
    stderr.writeln('  - $v');
  }
  stderr.writeln(
    '\nAdd tests to raise coverage. Only lower a threshold in tool/'
    'check_coverage.dart as a deliberate, documented retreat — never as a '
    'shortcut to make CI green.',
  );
  return 1;
}

Future<void> main(List<String> args) async {
  exit(await _main());
}

class _PrefixTotals {
  int linesFound = 0;
  int linesHit = 0;
  int fileCount = 0;
}

class _FileCoverage {
  _FileCoverage(this.path, this.linesFound, this.linesHit);
  final String path;
  final int linesFound;
  final int linesHit;
}

/// Parses an lcov.info trace file. Records use these markers:
///
///   SF:<source-file>
///   DA:<line>,<hit-count>            (one per line; we ignore — LF/LH are
///                                     authoritative for line totals)
///   LF:<lines-found>
///   LH:<lines-hit>
///   end_of_record
///
/// Tolerant of extra fields (BRDA, BRF, BRH, etc.) which we skip.
List<_FileCoverage> _parseLcov(String content) {
  final out = <_FileCoverage>[];
  String? currentPath;
  int? lf;
  int? lh;

  for (final raw in content.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('SF:')) {
      currentPath = _normalisePath(line.substring(3));
    } else if (line.startsWith('LF:')) {
      lf = int.tryParse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      lh = int.tryParse(line.substring(3));
    } else if (line == 'end_of_record') {
      if (currentPath != null && lf != null && lh != null) {
        out.add(_FileCoverage(currentPath, lf, lh));
      }
      currentPath = null;
      lf = null;
      lh = null;
    }
  }
  return out;
}

String _normalisePath(String p) {
  // Flutter emits Windows paths with backslashes; LCOV consumers expect
  // forward slashes. Normalise so the prefix match works cross-platform.
  return p.replaceAll('\\', '/');
}
