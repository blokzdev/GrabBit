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
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            id: const Value(_rowId),
            data: jsonEncode(settings.toJson()),
          ),
        );
  }
}

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));
