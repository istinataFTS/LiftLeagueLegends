import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/sync_exceptions.dart';

class RemoteDatasourceGuard {
  const RemoteDatasourceGuard._();

  static Future<T> run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthSyncException {
      rethrow;
    } on NetworkSyncException {
      rethrow;
    } on RemoteSyncException {
      rethrow;
    } on AuthException catch (e) {
      throw AuthSyncException(e.message, cause: e);
    } on PostgrestException catch (e) {
      throw RemoteSyncException(e.message, cause: e);
    } on SocketException catch (e) {
      throw NetworkSyncException(e.message, cause: e);
    } on TimeoutException catch (e) {
      throw NetworkSyncException(
        e.message ?? 'remote request timed out',
        cause: e,
      );
    }
  }
}
