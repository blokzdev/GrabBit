import 'dart:io';

const _subtitleExts = {'srt', 'vtt', 'ass', 'ssa'};

/// Subtitle sidecar files (`.srt`/`.vtt`/…) sitting next to [mediaPath]
/// (yt-dlp writes them into the same per-task folder). Used by the player's
/// subtitle-track picker (P9c) and Media Studio burn-in (P8c).
List<File> subtitleSidecars(String mediaPath) {
  final dir = File(mediaPath).parent;
  if (!dir.existsSync()) return const [];
  return dir.listSync().whereType<File>().where((f) {
    return _subtitleExts.contains(f.path.split('.').last.toLowerCase());
  }).toList();
}

/// The language tag from a subtitle filename (`clip.en.srt` → `en`); falls back
/// to the base name when there's no language segment.
String subtitleLabel(String path) {
  final parts = path.split('/').last.split('.');
  return parts.length >= 3 ? parts[parts.length - 2] : parts.first;
}
