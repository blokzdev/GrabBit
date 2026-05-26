import 'dart:io';

import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/utils/filename_template.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

/// Builds a [DownloadRequest] from the chosen format/quality and the user's
/// [settings], applying the P8b power options. Shared by the single-download
/// (`downloader_controller`) and batch (`selection_controller`) paths so the
/// two can't drift apart. [index] (1-based) drives batch filename numbering.
DownloadRequest buildDownloadRequest({
  required String taskId,
  required String url,
  required String outputDir,
  required SettingsModel settings,
  required bool audioOnly,
  String? formatSelector,
  int index = 1,
}) {
  final extra = parseExtraArgs(settings.extraDownloadArgs);
  final subLangs = parseCsvList(settings.subtitleLangs);
  // P10f-3: when "Auto-fetch captions for transcripts" is on and no explicit
  // caption langs are set, fetch captions in the app's language (auto-generated
  // as fallback) so transcripts can auto-build. Explicit "Download captions"
  // langs win.
  final autoCaps = settings.autoDownloadCaptions && subLangs.isEmpty;
  final effLangs = autoCaps ? [settings.captionLanguage] : subLangs;
  final sponsorOn = settings.sponsorBlockMode != 'off';
  final sponsorCats = sponsorOn
      ? parseCsvList(settings.sponsorBlockCategories)
      : const <String>[];
  return DownloadRequest(
    taskId: taskId,
    url: url,
    outputDir: outputDir,
    filenameTemplate: resolveOutputTemplate(
      settings.filenameTemplate,
      index: index,
    ),
    formatId: formatSelector,
    audioOnly: audioOnly,
    // For audio, the container doubles as the codec (yt-dlp --audio-format).
    container: audioOnly ? settings.audioFormat : settings.defaultContainer,
    subtitleLangs: effLangs.isEmpty ? null : effLangs,
    autoSubs: autoCaps ? true : settings.subtitleAuto,
    subtitleFormat: settings.subtitleFormat,
    embedThumbnail: settings.embedThumbnail,
    embedMetadata: settings.embedMetadata,
    rateLimit: settings.rateLimit.isEmpty ? null : settings.rateLimit,
    concurrentFragments: settings.concurrentFragments > 1
        ? settings.concurrentFragments
        : null,
    audioQuality: audioOnly && settings.audioQuality != 'best'
        ? settings.audioQuality
        : null,
    downloadArchivePath: settings.useDownloadArchive
        ? '$outputDir/.download-archive.txt'
        : null,
    extraArgs: extra.isEmpty ? null : extra,
    sponsorBlock: sponsorOn ? settings.sponsorBlockMode : null,
    sponsorBlockCategories: sponsorCats.isEmpty ? null : sponsorCats,
    embedChapters: settings.embedChapters,
    splitChapters: settings.splitChapters,
  );
}

/// Builds a subtitles-only [DownloadRequest] (P10f-2) that fetches captions in
/// [lang] for an already-downloaded item — `--skip-download`, so no media is
/// re-fetched. The caption file lands in the item's **existing** media folder
/// (so it sits beside the media and the player's track picker can use it):
/// [outputDir]/[taskId] is reconstructed from [mediaPath]'s folder. Auto-
/// generated captions are accepted as a fallback ([DownloadRequest.autoSubs]).
DownloadRequest buildCaptionFetchRequest({
  required String sourceUrl,
  required String mediaPath,
  required SettingsModel settings,
  required String lang,
}) {
  final dir = File(mediaPath).parent;
  final folderName = dir.path.split('/').last;
  return DownloadRequest(
    taskId: folderName,
    url: sourceUrl,
    outputDir: dir.parent.path,
    filenameTemplate: '${_fileStem(mediaPath)}.%(ext)s',
    skipDownload: true,
    subtitleLangs: [lang],
    autoSubs: true,
    subtitleFormat: settings.subtitleFormat,
  );
}

/// Filename without directory or extension.
String _fileStem(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot > 0 ? name.substring(0, dot) : name;
}

/// Splits a comma/whitespace-separated list (subtitle langs, SponsorBlock
/// categories) into trimmed, non-empty tokens.
List<String> parseCsvList(String raw) => raw
    .split(RegExp(r'[,\s]+'))
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .toList();

/// Resolves a probed [MediaFormat] into a yt-dlp `-f` selector + whether it's
/// audio-only (P8d). A video-only stream is paired with `+bestaudio` (falling
/// back to the bare stream) so the result always carries sound when available.
({String selector, bool audioOnly}) formatSelectorFor(MediaFormat f) {
  final hasVideo = f.vcodec != null && f.vcodec != 'none';
  final hasAudio = f.acodec != null && f.acodec != 'none';
  if (hasVideo && !hasAudio) {
    return (selector: '${f.id}+bestaudio/${f.id}', audioOnly: false);
  }
  return (selector: f.id, audioOnly: hasAudio && !hasVideo);
}

/// Tokenizes the raw "extra yt-dlp args" string into argv elements (whitespace
/// split, empties dropped). Boundary validation for the Advanced escape hatch:
/// each token is passed to yt-dlp as one argument (no shell, no interpolation).
List<String> parseExtraArgs(String raw) => raw
    .split(RegExp(r'\s+'))
    .map((t) => t.trim())
    .where((t) => t.isNotEmpty)
    .toList();
