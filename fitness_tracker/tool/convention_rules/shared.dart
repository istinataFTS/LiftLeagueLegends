import 'dart:io';

/// Contract every convention rule must implement.
abstract class ConventionRule {
  String get id;
  String get description;
  Future<List<Violation>> check(RepoView repo);
}

/// A single rule violation found in the codebase.
final class Violation {
  const Violation({
    required this.ruleId,
    required this.filePath,
    required this.message,
    required this.fixHint,
    this.line,
  });

  final String ruleId;

  /// Repo-relative path with forward slashes.
  final String filePath;

  /// 1-based line number, if applicable.
  final int? line;

  final String message;
  final String fixHint;

  @override
  String toString() {
    final loc = line != null ? ':$line' : '';
    return '[$ruleId] $filePath$loc — $message\n  Fix: $fixHint';
  }
}

/// Thin abstraction over the repository file system.
/// Substitute [FakeRepoView] in tests for deterministic, in-memory checks.
abstract class RepoView {
  /// All `.dart` files under [relPath] (relative to repo root), recursively.
  Future<List<String>> listDartFiles(String relPath);

  /// All files under [relPath] (relative to repo root), recursively.
  Future<List<String>> listFiles(String relPath);

  /// Contents of the file at [relPath], or `null` if the file does not exist.
  Future<String?> readFile(String relPath);
}

/// [RepoView] that reads from the real filesystem.
final class FsRepoView implements RepoView {
  const FsRepoView(this.root);

  final String root;

  @override
  Future<List<String>> listDartFiles(String relPath) => _list(relPath, '.dart');

  @override
  Future<List<String>> listFiles(String relPath) => _list(relPath, null);

  Future<List<String>> _list(String relPath, String? ext) async {
    final sep = Platform.pathSeparator;
    final dir = Directory('$root$sep${relPath.replaceAll('/', sep)}');
    if (!dir.existsSync()) return [];
    final results = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is! File) continue;
      if (ext != null && !entity.path.endsWith(ext)) continue;
      results.add(_relativize(entity.path));
    }
    return results;
  }

  String _relativize(String absPath) {
    final normalized = absPath.replaceAll('\\', '/');
    final rootNorm = root.replaceAll('\\', '/');
    final rel = normalized.startsWith(rootNorm)
        ? normalized.substring(rootNorm.length)
        : normalized;
    return rel.startsWith('/') ? rel.substring(1) : rel;
  }

  @override
  Future<String?> readFile(String relPath) async {
    final sep = Platform.pathSeparator;
    final file = File('$root$sep${relPath.replaceAll('/', sep)}');
    if (!file.existsSync()) return null;
    return file.readAsString();
  }
}

/// [RepoView] backed by an in-memory map for use in tests.
final class FakeRepoView implements RepoView {
  FakeRepoView(this._files);

  final Map<String, String> _files;

  @override
  Future<List<String>> listDartFiles(String relPath) async {
    final prefix = relPath.endsWith('/') ? relPath : '$relPath/';
    return _files.keys
        .where((k) => k.startsWith(prefix) && k.endsWith('.dart'))
        .toList();
  }

  @override
  Future<List<String>> listFiles(String relPath) async {
    final prefix = relPath.endsWith('/') ? relPath : '$relPath/';
    return _files.keys.where((k) => k.startsWith(prefix)).toList();
  }

  @override
  Future<String?> readFile(String relPath) async => _files[relPath];
}

/// Returns `true` if the line at [zeroBasedIndex] or the line immediately
/// before it contains a valid waiver comment for [ruleId].
///
/// Waiver syntax (must appear on the offending line or the preceding line):
/// ```
/// // convention-checker:allow=<rule-id> reason=<at-least-10-char prose>
/// ```
bool hasWaiver(List<String> lines, int zeroBasedIndex, String ruleId) {
  final pattern = RegExp(
    r'convention-checker:allow=(\S+)\s+reason=(.+)',
  );
  for (final idx in [zeroBasedIndex, zeroBasedIndex - 1]) {
    if (idx < 0 || idx >= lines.length) continue;
    final match = pattern.firstMatch(lines[idx]);
    if (match == null) continue;
    if (match.group(1)!.trim() != ruleId) continue;
    final reason = match.group(2)!.trim();
    if (reason.length >= 10) return true;
  }
  return false;
}
