import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/local/app_metadata_local_datasource.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  static const String _notificationsEnabledKey =
      'settings.notifications_enabled';
  static const String _weekStartDayKey = 'settings.week_start_day';
  static const String _weightUnitKey = 'settings.weight_unit';
  static const String _uiExpansionStateKey = 'settings.ui_expansion_state';

  final AppMetadataLocalDataSource localDataSource;

  AppSettingsRepositoryImpl({required this.localDataSource});

  /// Most recently observed [AppSettings]. Populated on successful
  /// [getSettings] reads and successful [saveSettings] writes. Replayed
  /// to each new [watchSettings] subscriber.
  AppSettings? _lastCached;

  /// Broadcasts post-save updates to all [watchSettings] listeners.
  /// Created lazily so callers that never subscribe pay nothing.
  StreamController<AppSettings>? _controller;

  StreamController<AppSettings> _ensureController() {
    return _controller ??= StreamController<AppSettings>.broadcast();
  }

  @override
  Future<Either<Failure, AppSettings>> getSettings() {
    return RepositoryGuard.run(() async {
      final notificationsEnabled = await localDataSource.readBool(
        _notificationsEnabledKey,
      );
      final weekStartDayRaw = await localDataSource.readString(
        _weekStartDayKey,
      );
      final weightUnitRaw = await localDataSource.readString(_weightUnitKey);
      final uiExpansionRaw = await localDataSource.readJsonObject(
        _uiExpansionStateKey,
      );

      final settings = AppSettings(
        notificationsEnabled: notificationsEnabled ?? true,
        weekStartDay: _parseWeekStartDay(weekStartDayRaw),
        weightUnit: _parseWeightUnit(weightUnitRaw),
        uiExpansionState: _parseUiExpansionState(uiExpansionRaw),
      );

      _lastCached = settings;
      return settings;
    });
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) {
    return RepositoryGuard.run(() async {
      await localDataSource.writeBool(
        _notificationsEnabledKey,
        settings.notificationsEnabled,
      );
      await localDataSource.writeString(
        _weekStartDayKey,
        settings.weekStartDay.name,
      );
      await localDataSource.writeString(
        _weightUnitKey,
        settings.weightUnit.name,
      );
      await localDataSource.writeJsonObject(
        _uiExpansionStateKey,
        settings.uiExpansionState.cast<String, dynamic>(),
      );

      // Only emit AFTER every write succeeds. RepositoryGuard.run catches
      // a throw above and short-circuits this line, so failures never
      // propagate to listeners.
      _lastCached = settings;
      _controller?.add(settings);
    });
  }

  @override
  Stream<AppSettings> watchSettings() {
    // `Stream.multi` creates a per-subscriber controller, which lets us
    // replay [_lastCached] only to the subscriber that just connected
    // (not to existing listeners again). The merged inner subscription
    // forwards all subsequent broadcast events.
    return Stream<AppSettings>.multi((listener) {
      final cached = _lastCached;
      if (cached != null) listener.add(cached);
      final sub = _ensureController().stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () async {
        await sub.cancel();
      };
    });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, bool> _parseUiExpansionState(Map<String, dynamic>? raw) {
    if (raw == null) return const <String, bool>{};
    try {
      return raw.map((String k, dynamic v) => MapEntry(k, v == true));
    } catch (_) {
      return const <String, bool>{};
    }
  }

  WeekStartDay _parseWeekStartDay(String? rawValue) {
    switch (rawValue) {
      case 'sunday':
        return WeekStartDay.sunday;
      case 'monday':
      default:
        return WeekStartDay.monday;
    }
  }

  WeightUnit _parseWeightUnit(String? rawValue) {
    switch (rawValue) {
      case 'pounds':
        return WeightUnit.pounds;
      case 'kilograms':
      default:
        return WeightUnit.kilograms;
    }
  }
}
