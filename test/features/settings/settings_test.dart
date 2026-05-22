import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

void main() {
  group('SettingsModel', () {
    test('defaults match SPEC §4', () {
      const s = SettingsModel();
      expect(s.mode, UiMode.simple);
      expect(s.defaultQuality, 'best');
      expect(s.defaultContainer, 'mp4');
      expect(s.storagePolicy, StoragePolicy.private);
      expect(s.maxConcurrentDownloads, 2);
      expect(s.wifiOnly, isFalse);
      expect(s.theme, ThemeChoice.system);
      expect(s.dynamicColor, isTrue);
      expect(s.appLock, const AppLockSettings());
    });

    test('JSON round-trip preserves enums with custom values', () {
      const s = SettingsModel(
        mode: UiMode.advanced,
        theme: ThemeChoice.dark,
        storagePolicy: StoragePolicy.autoExport,
        exportFolder: 'content://tree/abc',
        maxConcurrentDownloads: 4,
        appLock: AppLockSettings(enabled: true, biometric: true),
      );
      final json = s.toJson();
      expect(json['storagePolicy'], 'auto_export');
      expect(SettingsModel.fromJson(json), s);
    });
  });

  group('SettingsRepository', () {
    late AppDatabase db;
    late SettingsRepository repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      repo = SettingsRepository(db);
    });
    tearDown(() => db.close());

    test('returns defaults on empty DB and persists them', () async {
      final first = await repo.read();
      expect(first, const SettingsModel());
      final row = await (db.select(
        db.appSettings,
      )..where((t) => t.id.equals(0))).getSingleOrNull();
      expect(row, isNotNull);
    });

    test('write then read round-trips', () async {
      const updated = SettingsModel(mode: UiMode.advanced, wifiOnly: true);
      await repo.write(updated);
      expect(await repo.read(), updated);
    });

    test('write stamps a schema version into the blob', () async {
      await repo.write(const SettingsModel());
      final row = await (db.select(
        db.appSettings,
      )..where((t) => t.id.equals(0))).getSingle();
      expect(jsonDecode(row.data)['version'], 1);
    });

    test('reads a legacy blob without a version field', () async {
      // Simulate a pre-versioning row: valid settings JSON, no `version` key.
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              id: const Value(0),
              data: jsonEncode(const SettingsModel(wifiOnly: true).toJson()),
            ),
          );
      expect((await repo.read()).wifiOnly, isTrue);
    });
  });

  group('SettingsController', () {
    test('hydrates and persists mutations', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(settingsControllerProvider.future);
      expect(loaded.mode, UiMode.simple);

      await container
          .read(settingsControllerProvider.notifier)
          .setMode(UiMode.advanced);

      expect(
        container.read(settingsControllerProvider).asData?.value.mode,
        UiMode.advanced,
      );
      // Persisted to DB.
      expect((await SettingsRepository(db).read()).mode, UiMode.advanced);
    });

    test('acceptDisclaimer persists the flag', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(settingsControllerProvider.future);
      expect(loaded.disclaimerAccepted, isFalse);

      await container
          .read(settingsControllerProvider.notifier)
          .acceptDisclaimer();

      expect((await SettingsRepository(db).read()).disclaimerAccepted, isTrue);
    });

    test(
      'autoCheckEngineUpdate defaults on and persists when toggled',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final loaded = await container.read(settingsControllerProvider.future);
        expect(loaded.autoCheckEngineUpdate, isTrue);

        await container
            .read(settingsControllerProvider.notifier)
            .setAutoCheckEngineUpdate(false);

        expect(
          (await SettingsRepository(db).read()).autoCheckEngineUpdate,
          isFalse,
        );
      },
    );

    test('setFilenameTemplate persists the pattern', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      await container.read(settingsControllerProvider.future);
      await container
          .read(settingsControllerProvider.notifier)
          .setFilenameTemplate('{channel} - {title}');

      expect(
        (await SettingsRepository(db).read()).filenameTemplate,
        '{channel} - {title}',
      );
    });
  });
}
