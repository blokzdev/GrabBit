import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:grabbit/core/graph/cozo_schema.dart';
import 'package:grabbit/core/graph/graph_error.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/pigeon/cozo.pigeon.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts the `name` column from a Cozo `::relations` result
/// (`{headers: [...], rows: [[...], ...]}`). Pure so it's unit-testable.
Set<String> graphRelationNames(Map<String, Object?> result) {
  final headers = (result['headers'] as List?)?.cast<Object?>() ?? const [];
  final nameIdx = headers.indexOf('name');
  if (nameIdx < 0) return {};
  final rows = (result['rows'] as List?)?.cast<Object?>() ?? const [];
  return {
    for (final row in rows)
      if (row is List && nameIdx < row.length) row[nameIdx].toString(),
  };
}

/// Android [GraphStore] backed by the `cozo_android` Maven AAR through the
/// `CozoHostApi` Pigeon bridge. The SQLite-backed DB lives in app-private
/// support storage at `<support>/graph/cozo.db` (never the media/documents dirs,
/// so it can't leak into a library export).
///
/// If the native library isn't bundled for this device's ABI, [open] returns
/// false and [isAvailable] stays false — graph features then degrade gracefully
/// (the download/manager core is unaffected).
class AndroidCozoGraphStore implements GraphStore {
  AndroidCozoGraphStore({CozoHostApi? host}) : _host = host ?? CozoHostApi();

  final CozoHostApi _host;
  bool _available = false;

  @override
  bool get isAvailable => _available;

  @override
  Future<bool> open() async {
    try {
      final base = await getApplicationSupportDirectory();
      final dir = Directory('${base.path}/graph');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      _available = await _host.openDb('${dir.path}/cozo.db');
      if (_available) {
        await ensureSchema();
      }
      return _available;
    } on PlatformException catch (_) {
      // e.g. UnsatisfiedLinkError surfaced from Kotlin on an unsupported ABI.
      _available = false;
      return false;
    }
  }

  @override
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params = const {},
  ]) async {
    if (!_available) {
      throw const GraphException(
        GraphErrorCode.unavailable,
        'Graph store is not available on this device',
      );
    }
    final String raw;
    try {
      raw = await _host.runScript(script, jsonEncode(params));
    } on PlatformException catch (e) {
      throw GraphException(
        GraphErrorCode.queryFailed,
        e.message ?? 'CozoScript execution failed',
        cause: e,
      );
    }
    final decoded = jsonDecode(raw) as Map<String, Object?>;
    if (decoded['ok'] == false) {
      throw GraphException(
        GraphErrorCode.queryFailed,
        (decoded['display'] ?? decoded['message'] ?? 'CozoScript error')
            .toString(),
      );
    }
    return decoded;
  }

  @override
  Future<void> ensureSchema() async {
    final existing = await _existingRelations();
    for (final script in missingSchemaScripts(existing)) {
      await runScript(script);
    }
  }

  /// Names of stored relations that already exist (`::relations`).
  Future<Set<String>> _existingRelations() async =>
      graphRelationNames(await runScript('::relations'));

  @override
  Future<void> close() async {
    if (!_available) return;
    try {
      await _host.closeDb();
    } finally {
      _available = false;
    }
  }
}
