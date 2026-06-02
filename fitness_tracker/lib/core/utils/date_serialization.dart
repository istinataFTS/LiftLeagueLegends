/// Boundary helpers for persisting and transporting [DateTime]s.
///
/// The app keeps entity timestamps as *local* `DateTime`s in memory. Storage
/// (SQLite) and transport (Supabase `timestamptz`) are always normalised to
/// UTC at the boundary. A bare `DateTime.toIso8601String()` on a local
/// DateTime omits the timezone offset, which Postgres reads as UTC — shifting
/// the instant by the device offset. These helpers prevent that.
///
/// See KNOWN_ISSUES.md `#timestamps-must-round-trip-as-utc-not-naive-local`.
extension DateSerialization on DateTime {
  /// ISO-8601 string in UTC, for SQLite columns, Supabase payloads, and query
  /// bounds. Always carries a `Z` suffix so reads are unambiguous and string
  /// range/order comparisons are chronological.
  String toStorageIso() => toUtc().toIso8601String();
}

/// Parses a stored/transported timestamp back into a *local* `DateTime`.
/// Accepts both offset-aware (`…Z`/`+00:00`) and legacy offset-less strings;
/// the former are normalised from UTC, the latter are treated as already-local
/// (which heals never-synced legacy rows).
DateTime parseStorageDate(String value) => DateTime.parse(value).toLocal();

/// Nullable variant: returns `null` for null/empty input.
DateTime? parseStorageDateOrNull(String? value) =>
    (value == null || value.isEmpty) ? null : DateTime.parse(value).toLocal();
