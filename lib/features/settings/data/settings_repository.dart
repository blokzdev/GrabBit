import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository.g.dart';

/// Reads/writes the single-row `app_settings` JSON blob.
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;
  static const _rowId = 0;

  /// Schema version stamped into the JSON blob. `fromJson` ignores unknown keys
  /// and missing fields fall back to `@Default`, so additive changes round-trip
  /// for free; this stamp is the hook future builds branch on to migrate older
  /// blobs after a field is renamed or removed.
  static const _schemaVersion = 1;

  Future<SettingsModel> read() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.id.equals(_rowId))).getSingleOrNull();
    if (row == null) {
      const defaults = SettingsModel();
      await write(defaults);
      return defaults;
    }
    return SettingsModel.fromJson(jsonDecode(row.data) as Map<String, dynamic>);
  }

  Future<void> write(SettingsModel settings) async {
    final json = settings.toJson()..['version'] = _schemaVersion;
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(_rowId),
            data: jsonEncode(json),
          ),
        );
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));
