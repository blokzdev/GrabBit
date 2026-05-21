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
    @Default(false) bool wifiOnly,
    @Default(false) bool defaultSubtitles,
    @Default(true) bool embedThumbnail,
    @Default(true) bool embedMetadata,
    @Default(ThemeChoice.system) ThemeChoice theme,
    @Default(true) bool dynamicColor,
    String? locale,
    @Default(AppLockSettings()) AppLockSettings appLock,
    @Default(false) bool disclaimerAccepted,
  }) = _SettingsModel;

  factory SettingsModel.fromJson(Map<String, dynamic> json) =>
      _$SettingsModelFromJson(json);
}
