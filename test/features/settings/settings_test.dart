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
      // P8b power options default to current behavior.
      expect(s.concurrentFragments, 1);
      expect(s.rateLimit, '');
      expect(s.audioFormat, 'm4a');
      expect(s.audioQuality, 'best');
      expect(s.useDownloadArchive, isFalse);
      expect(s.extraDownloadArgs, '');
      // P8c subtitles / SponsorBlock / chapters default off.
      expect(s.subtitleLangs, '');
      expect(s.subtitleAuto, isFalse);
      expect(s.subtitleFormat, 'srt');
      expect(s.sponsorBlockMode, 'off');
      expect(s.sponsorBlockCategories, 'sponsor');
      expect(s.embedChapters, isFalse);
      expect(s.splitChapters, isFalse);
      // P9e privacy defaults.
      expect(s.blockScreenshots, isFalse);
      expect(s.secureDelete, isFalse);
      expect(s.appLock.autoLockSeconds, 60);
      // P9f storage/battery safety defaults.
      expect(s.minFreeSpaceMb, 500);
      expect(s.pauseOnLowBattery, isFalse);
      expect(s.lowBatteryThreshold, 15);
      // P10b-2 AI defaults: opt-in off; first-run gate armed only by accepting
      // the disclaimer (so existing installs aren't ambushed).
      expect(s.semanticSearchEnabled, isFalse);
      expect(s.aiSetupSeen, isTrue);
      // P12d generation defaults: opt-in off, no model selected (tier rec).
      expect(s.generationEnabled, isFalse);
      expect(s.selectedGenerationModelId, '');
    });

    test('JSON round-trip preserves the P12d generation fields', () {
      const s = SettingsModel(
        generationEnabled: true,
        selectedGenerationModelId: 'qwen3-0.6b',
      );
      expect(SettingsModel.fromJson(s.toJson()), s);
    });

    test('a legacy blob without the P9f fields decodes to defaults', () {
      final legacy = const SettingsModel().toJson()
        ..remove('minFreeSpaceMb')
        ..remove('pauseOnLowBattery')
        ..remove('lowBatteryThreshold');
      final decoded = SettingsModel.fromJson(legacy);
      expect(decoded.minFreeSpaceMb, 500);
      expect(decoded.pauseOnLowBattery, isFalse);
      expect(decoded.lowBatteryThreshold, 15);
    });

    test('JSON round-trip preserves the P9e privacy fields', () {
      const s = SettingsModel(
        blockScreenshots: true,
        secureDelete: true,
        appLock: AppLockSettings(enabled: true, autoLockSeconds: 300),
      );
      expect(SettingsModel.fromJson(s.toJson()), s);
    });

    test('a legacy blob without the P9e fields decodes to defaults', () {
      final legacy = const SettingsModel().toJson()
        ..remove('blockScreenshots')
        ..remove('secureDelete');
      (legacy['appLock'] as Map).remove('autoLockSeconds');
      final decoded = SettingsModel.fromJson(legacy);
      expect(decoded.blockScreenshots, isFalse);
      expect(decoded.secureDelete, isFalse);
      expect(decoded.appLock.autoLockSeconds, 60);
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

    test('power-option setters persist (P8b)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);
      await container.read(settingsControllerProvider.future);
      await notifier.setConcurrentFragments(4);
      await notifier.setRateLimit('1M');
      await notifier.setAudioFormat('mp3');
      await notifier.setAudioQuality('192K');
      await notifier.setUseDownloadArchive(true);
      await notifier.setExtraDownloadArgs('--no-mtime');

      final saved = await SettingsRepository(db).read();
      expect(saved.concurrentFragments, 4);
      expect(saved.rateLimit, '1M');
      expect(saved.audioFormat, 'mp3');
      expect(saved.audioQuality, '192K');
      expect(saved.useDownloadArchive, isTrue);
      expect(saved.extraDownloadArgs, '--no-mtime');
    });

    test('subtitle / SponsorBlock / chapter setters persist (P8c)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);
      await container.read(settingsControllerProvider.future);
      await notifier.setSubtitleLangs('en,es');
      await notifier.setSubtitleAuto(true);
      await notifier.setSubtitleFormat('vtt');
      await notifier.setSponsorBlockMode('remove');
      await notifier.setSponsorBlockCategories('sponsor,intro');
      await notifier.setEmbedChapters(true);
      await notifier.setSplitChapters(true);

      final saved = await SettingsRepository(db).read();
      expect(saved.subtitleLangs, 'en,es');
      expect(saved.subtitleAuto, isTrue);
      expect(saved.subtitleFormat, 'vtt');
      expect(saved.sponsorBlockMode, 'remove');
      expect(saved.sponsorBlockCategories, 'sponsor,intro');
      expect(saved.embedChapters, isTrue);
      expect(saved.splitChapters, isTrue);
    });

    test('acceptDisclaimer persists the flag and arms ai-setup', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(settingsControllerProvider.future);
      expect(loaded.disclaimerAccepted, isFalse);
      expect(loaded.aiSetupSeen, isTrue);

      await container
          .read(settingsControllerProvider.notifier)
          .acceptDisclaimer();

      final saved = await SettingsRepository(db).read();
      expect(saved.disclaimerAccepted, isTrue);
      // Accepting the disclaimer arms the one-time AI-setup screen.
      expect(saved.aiSetupSeen, isFalse);
    });

    test('AI flag setters persist (P10b-2)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);
      await container.read(settingsControllerProvider.future);
      await notifier.setSemanticSearchEnabled(true);
      await notifier.markAiSetupSeen();

      final saved = await SettingsRepository(db).read();
      expect(saved.semanticSearchEnabled, isTrue);
      expect(saved.aiSetupSeen, isTrue);
    });

    test(
      'auto-process setters default off and persist (P13a-2/P13b-3/P13c-2)',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        final loaded = await container.read(settingsControllerProvider.future);
        expect(loaded.autoSummarizeOnDownload, isFalse);
        expect(loaded.autoOcrOnDownload, isFalse);
        expect(loaded.autoTagOnDownload, isFalse);

        final notifier = container.read(settingsControllerProvider.notifier);
        await notifier.setAutoSummarizeOnDownload(true);
        await notifier.setAutoOcrOnDownload(true);
        await notifier.setAutoTagOnDownload(true);

        final saved = await SettingsRepository(db).read();
        expect(saved.autoSummarizeOnDownload, isTrue);
        expect(saved.autoOcrOnDownload, isTrue);
        expect(saved.autoTagOnDownload, isTrue);
      },
    );

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

    test('setAmoledDark persists', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final loaded = await container.read(settingsControllerProvider.future);
      expect(loaded.amoledDark, isFalse);

      await container
          .read(settingsControllerProvider.notifier)
          .setAmoledDark(true);

      expect((await SettingsRepository(db).read()).amoledDark, isTrue);
    });

    test('privacy setters persist (P9e)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);
      await container.read(settingsControllerProvider.future);
      await notifier.setBlockScreenshots(true);
      await notifier.setSecureDelete(true);

      final saved = await SettingsRepository(db).read();
      expect(saved.blockScreenshots, isTrue);
      expect(saved.secureDelete, isTrue);
    });

    test('storage/battery safety setters persist (P9f)', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsControllerProvider.notifier);
      await container.read(settingsControllerProvider.future);
      await notifier.setMinFreeSpaceMb(1024);
      await notifier.setPauseOnLowBattery(true);
      await notifier.setLowBatteryThreshold(20);

      final saved = await SettingsRepository(db).read();
      expect(saved.minFreeSpaceMb, 1024);
      expect(saved.pauseOnLowBattery, isTrue);
      expect(saved.lowBatteryThreshold, 20);
    });

    test(
      'resetToDefaults restores prefs but keeps lock + disclaimer',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await SettingsRepository(db).write(
          const SettingsModel(
            mode: UiMode.advanced,
            theme: ThemeChoice.dark,
            dynamicColor: false,
            amoledDark: true,
            storagePolicy: StoragePolicy.autoExport,
            maxConcurrentDownloads: 5,
            blockScreenshots: true,
            secureDelete: true,
            appLock: AppLockSettings(enabled: true, biometric: true),
            disclaimerAccepted: true,
          ),
        );
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(db)],
        );
        addTearDown(container.dispose);

        await container.read(settingsControllerProvider.future);
        await container
            .read(settingsControllerProvider.notifier)
            .resetToDefaults();

        final saved = await SettingsRepository(db).read();
        // Prefs revert to defaults.
        expect(saved.mode, UiMode.simple);
        expect(saved.theme, ThemeChoice.system);
        expect(saved.dynamicColor, isTrue);
        expect(saved.amoledDark, isFalse);
        expect(saved.storagePolicy, StoragePolicy.private);
        expect(saved.maxConcurrentDownloads, 2);
        expect(saved.blockScreenshots, isFalse);
        expect(saved.secureDelete, isFalse);
        // Lock + disclaimer are preserved.
        expect(
          saved.appLock,
          const AppLockSettings(enabled: true, biometric: true),
        );
        expect(saved.disclaimerAccepted, isTrue);
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
