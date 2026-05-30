import 'package:meta/meta.dart';

import '../../../core/constants/database_tables.dart';
import '../../../core/session/current_user_id_resolver.dart';
import 'database_helper.dart';

/// Base class for every local datasource whose rows are owned by a specific
/// authenticated user. Extending this class is the *only* sanctioned way to
/// scope local queries to the current owner.
///
/// ## Why this exists
///
/// `fix/profile-data-isolation` (PRs #50, #51) introduced [CurrentUserIdResolver]
/// after three real cross-user data leaks. The resolver alone is a convention:
/// each datasource must remember to call it on every query. This base class
/// removes that "must remember" — `whereOwned(...)` is the path of least
/// resistance, and the resolver is reached only via [ownerId].
///
/// ## Post guest-removal contract
///
/// There is no guest mode. Every reachable datasource call site runs above
/// the auth gate, so [ownerId] either returns an authenticated user id or
/// throws `MissingUserContextException`. Callers do not need to handle a
/// "missing user" branch — that scenario indicates a session-lookup or
/// sign-out race and should surface as an error, not as silent empty data.
///
/// ## What is exempt
///
/// The following local datasources do **not** extend this class and never
/// should:
///
/// - `AppMetadataLocalDataSource` — app-wide K/V; rows have no owner column.
/// - `MuscleFactorLocalDataSource` — global exercise catalog; rows are keyed
///   by `exerciseId`, scoping is inherited from the parent exercise row.
/// - `PendingSyncDeleteLocalDataSource` — sync queue; rows carry their own
///   `ownerUserId` and are queried as a whole queue, not per-active-user.
///
/// Any file added to `lib/data/datasources/local/` must either extend this
/// class or be added to this list with a one-line reason. The
/// `user-scoped-datasource` convention rule enforces this in CI.
abstract class UserScopedLocalDatasource {
  UserScopedLocalDatasource({
    required this.databaseHelper,
    required this.currentUserIdResolver,
  });

  @protected
  final DatabaseHelper databaseHelper;

  @protected
  final CurrentUserIdResolver currentUserIdResolver;

  /// Returns the current authenticated owner id. Throws
  /// `MissingUserContextException` if no user is in context (session-lookup
  /// failure or pre-auth code path that should not be reachable).
  @protected
  Future<String> ownerId() => currentUserIdResolver.resolve();

  /// Builds a `WHERE` clause that scopes results to [ownerId], optionally
  /// composed with [extra] / [extraArgs]. Always emits `owner_user_id = ?`
  /// as the final predicate.
  ///
  /// Example:
  /// ```dart
  /// final id = await ownerId();
  /// final f = whereOwned(
  ///   ownerId: id,
  ///   extra: '(sync_status IS NULL OR sync_status != ?)',
  ///   extraArgs: [SyncStatus.pendingDelete.name],
  /// );
  /// final rows = await db.query(table, where: f.where, whereArgs: f.whereArgs);
  /// ```
  @protected
  ({String where, List<Object?> whereArgs}) whereOwned({
    required String ownerId,
    String? extra,
    List<Object?> extraArgs = const [],
  }) {
    const ownerColumn = DatabaseTables.ownerUserId;
    final clause = (extra == null || extra.isEmpty)
        ? '$ownerColumn = ?'
        : '($extra) AND $ownerColumn = ?';
    return (where: clause, whereArgs: [...extraArgs, ownerId]);
  }
}
