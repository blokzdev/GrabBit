import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_model.freezed.dart';
part 'settings_model.g.dart';

enum UiMode { simple, advanced }

enum ThemeChoice { system, light, dark }

enum StoragePolicy {
  private,
  @JsonValue('auto_export')
  autoExport,
}

@freezed
abstract class AppLockSettings with _$AppLockSettings {
  const factory AppLockSettings({
    @Default(false) bool enabled,
    @Default(false) bool biometric,
    @Default(60) int autoLockSeconds,
  }) = _AppLockSettings;

  factory AppLockSettings.fromJson(Map<String, dynamic> json) =>
      _$AppLockSettingsFromJson(json);
}

/// App-wide settings, persisted as a single JSON row (`app_settings`, id=0).
/// Mirrors SPEC §4 defaults exactly.
@freezed
abstract class SettingsModel with _$SettingsModel {
  const factory SettingsModel({
    @Default(UiMode.simple) UiMode mode,
    @Default('best') String defaultQuality,
    @Default('mp4') String defaultContainer,
    @Default(StoragePolicy.private) StoragePolicy storagePolicy,
    String? exportFolder,
    @Default('{title}') String filenameTemplate,
    @Default(2) int maxConcurrentDownloads,
    @Default(1) int concurrentFragments,
    @Default('') String rateLimit,
    @Default('m4a') String audioFormat,
    @Default('best') String audioQuality,
    @Default(false) bool useDownloadArchive,
    @Default('') String extraDownloadArgs,
    @Default(false) bool wifiOnly,
    @Default(500) int minFreeSpaceMb,
    @Default(false) bool pauseOnLowBattery,
    @Default(15) int lowBatteryThreshold,
    @Default('') String subtitleLangs,
    @Default(false) bool subtitleAuto,
    @Default('srt') String subtitleFormat,
    @Default('off') String sponsorBlockMode,
    @Default('sponsor') String sponsorBlockCategories,
    @Default(false) bool embedChapters,
    @Default(false) bool splitChapters,
    @Default(true) bool embedThumbnail,
    @Default(true) bool embedMetadata,
    @Default(ThemeChoice.system) ThemeChoice theme,
    @Default(true) bool dynamicColor,
    String? locale,
    @Default(AppLockSettings()) AppLockSettings appLock,
    @Default(false) bool blockScreenshots,
    @Default(false) bool secureDelete,
    @Default(false) bool disclaimerAccepted,
    @Default(true) bool autoCheckEngineUpdate,
    DateTime? lastEngineCheck,
  }) = _SettingsModel;

  factory SettingsModel.fromJson(Map<String, dynamic> json) =>
      _$SettingsModelFromJson(json);
}
