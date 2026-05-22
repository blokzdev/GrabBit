import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/data/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Central settings state. Hydrates from the repository on build; each mutator
/// updates state optimistically and persists.
@Riverpod(keepAlive: true)
class SettingsController extends _$SettingsController {
  @override
  Future<SettingsModel> build() => ref.watch(settingsRepositoryProvider).read();

  Future<void> _update(SettingsModel next) async {
    state = AsyncData(next);
    await ref.read(settingsRepositoryProvider).write(next);
  }

  Future<void> setMode(UiMode mode) async =>
      _update((await future).copyWith(mode: mode));

  Future<void> setTheme(ThemeChoice theme) async =>
      _update((await future).copyWith(theme: theme));

  Future<void> setDynamicColor(bool enabled) async =>
      _update((await future).copyWith(dynamicColor: enabled));

  Future<void> setDefaultQuality(String quality) async =>
      _update((await future).copyWith(defaultQuality: quality));

  Future<void> setDefaultContainer(String container) async =>
      _update((await future).copyWith(defaultContainer: container));

  Future<void> setStoragePolicy(StoragePolicy policy) async =>
      _update((await future).copyWith(storagePolicy: policy));

  Future<void> setExportFolder(String? folder) async =>
      _update((await future).copyWith(exportFolder: folder));

  Future<void> setMaxConcurrentDownloads(int value) async =>
      _update((await future).copyWith(maxConcurrentDownloads: value));

  Future<void> setFilenameTemplate(String template) async =>
      _update((await future).copyWith(filenameTemplate: template));

  Future<void> setWifiOnly(bool value) async =>
      _update((await future).copyWith(wifiOnly: value));

  Future<void> setDefaultSubtitles(bool value) async =>
      _update((await future).copyWith(defaultSubtitles: value));

  Future<void> setEmbedThumbnail(bool value) async =>
      _update((await future).copyWith(embedThumbnail: value));

  Future<void> setEmbedMetadata(bool value) async =>
      _update((await future).copyWith(embedMetadata: value));

  Future<void> setAppLock(AppLockSettings appLock) async =>
      _update((await future).copyWith(appLock: appLock));

  Future<void> acceptDisclaimer() async =>
      _update((await future).copyWith(disclaimerAccepted: true));

  Future<void> setAutoCheckEngineUpdate(bool value) async =>
      _update((await future).copyWith(autoCheckEngineUpdate: value));

  Future<void> setLastEngineCheck(DateTime when) async =>
      _update((await future).copyWith(lastEngineCheck: when));
}
