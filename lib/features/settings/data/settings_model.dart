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
    // P10f: build a text transcript from downloaded captions automatically,
    // and backfill older items the first time they're opened. Both opt-in.
    @Default(false) bool autoTranscribe,
    @Default(false) bool transcriptBackfill,
    // P10f-3: also fetch captions (in the app's language) on every download
    // when no explicit subtitle languages are set, so transcripts auto-build.
    @Default(false) bool autoDownloadCaptions,
    @Default('off') String sponsorBlockMode,
    @Default('sponsor') String sponsorBlockCategories,
    @Default(false) bool embedChapters,
    @Default(false) bool splitChapters,
    @Default(true) bool embedThumbnail,
    @Default(true) bool embedMetadata,
    @Default(ThemeChoice.system) ThemeChoice theme,
    @Default(true) bool dynamicColor,
    @Default(false) bool amoledDark,
    String? locale,
    @Default(AppLockSettings()) AppLockSettings appLock,
    @Default(false) bool blockScreenshots,
    @Default(false) bool secureDelete,
    @Default(false) bool disclaimerAccepted,
    @Default(true) bool autoCheckEngineUpdate,
    DateTime? lastEngineCheck,
    @Default('') String graphIndexVersion,
    // On-device AI (P10b-2). Opt-in: the embedder model is downloaded only when
    // the user enables semantic search. `aiSetupSeen` defaults true so existing
    // installs aren't shown the first-run AI-setup screen; `acceptDisclaimer()`
    // flips it false, so only a brand-new user sees disclaimer → ai-setup.
    @Default(false) bool semanticSearchEnabled,
    @Default(true) bool aiSetupSeen,
    // Install-global embedder selection (P12c-3). Empty = the device-tier
    // default (Gecko); set to a catalog model id (e.g. the multilingual MiniLM)
    // to override it. Resolved + eligibility-guarded by activeEmbedderModelProvider,
    // which falls back to Gecko for an unknown/ineligible id. Switching re-embeds.
    @Default('') String selectedEmbedderModelId,
    // On-device text generation (P12d). Opt-in (defaults off); the LLM is
    // downloaded only when the user enables it + picks a model.
    // `selectedGenerationModelId` empty = the device-tier recommendation;
    // eligibility-guarded by activeGenerationModelProvider.
    @Default(false) bool generationEnabled,
    @Default('') String selectedGenerationModelId,
    // On-device speech transcription (P12e). Opt-in (defaults off); the whisper
    // model is downloaded only when the user enables it + picks a model.
    // `selectedTranscriptionModelId` empty = the device-tier recommendation;
    // eligibility-guarded by activeTranscriptionModelProvider. Whisper is a
    // fallback for media without caption sidecars (P12e-3).
    @Default(false) bool transcriptionEnabled,
    @Default('') String selectedTranscriptionModelId,
    // Activity inbox (P11). Retention 0 = keep forever; otherwise entries are
    // swept lazily once older than this many days. The per-category notify
    // toggles gate whether that category is recorded at all (errors and system
    // notices are always recorded regardless).
    @Default(30) int notificationRetentionDays,
    @Default(true) bool notifyDownload,
    @Default(true) bool notifyTranscript,
    @Default(true) bool notifyAi,
    @Default(true) bool notifyGraph,
  }) = _SettingsModel;

  factory SettingsModel.fromJson(Map<String, dynamic> json) =>
      _$SettingsModelFromJson(json);
}

extension SettingsCaptionLang on SettingsModel {
  /// The app's language as a bare subtitle code (e.g. `en-US` → `en`), used as
  /// the default for caption fetch/auto-download. Falls back to English.
  String get captionLanguage => (locale ?? 'en').split(RegExp('[-_]')).first;
}
