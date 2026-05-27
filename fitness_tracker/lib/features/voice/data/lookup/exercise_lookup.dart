import '../../../../domain/entities/exercise.dart';
import '../../../../domain/usecases/exercises/get_all_exercises.dart';

/// Caches and resolves exercises by name for voice commands.
///
/// Injected as a lazy singleton so the cache persists across voice sessions.
/// The VoiceBloc and the offline parser share this single instance so
/// resolution logic never drifts.
///
/// Call [invalidate] whenever the exercise library is mutated (add / update /
/// delete) so the next lookup sees the fresh catalog.
class ExerciseLookup {
  ExerciseLookup(this._getAllExercises);

  final GetAllExercises _getAllExercises;
  List<Exercise> _cache = const [];
  // Starts dirty so the very first lookup always loads from the repository.
  bool _isDirty = true;

  bool get hasCached => _cache.isNotEmpty;

  /// Marks the cache dirty so the next [refreshIfStale] call reloads it.
  void invalidate() => _isDirty = true;

  /// Populate the cache from the repository if the cache is dirty.
  /// No-op when the cache is fresh. Safe to call before every lookup.
  Future<void> refreshIfStale() async {
    if (!_isDirty) return;
    final result = await _getAllExercises();
    result.fold((_) {}, (list) {
      _cache = list;
      _isDirty = false;
    });
  }

  /// Sync lookup against the current cache.
  /// Returns null if the cache is empty or no match is found.
  /// Resolution order: exact name → starts-with prefix.
  Exercise? byName(String spoken) => _matchName(spoken, _cache);

  /// Async version — refreshes the cache if stale, then resolves.
  Future<Exercise?> findByName(String spoken) async {
    await refreshIfStale();
    return byName(spoken);
  }

  /// Returns the exercise ID for [name], or null if unresolvable.
  String? resolveId(String name) => byName(name)?.id;

  /// Returns the human-readable exercise name for [id], or [id] itself as a
  /// fallback so callers never get an empty string in spoken output.
  String nameForId(String id) {
    for (final ex in _cache) {
      if (ex.id == id) return ex.name;
    }
    return id;
  }

  Exercise? _matchName(String spoken, List<Exercise> list) {
    final lower = spoken.toLowerCase().trim();
    for (final ex in list) {
      if (ex.name.toLowerCase() == lower) return ex;
    }
    for (final ex in list) {
      if (ex.name.toLowerCase().startsWith(lower)) return ex;
    }
    return null;
  }
}
