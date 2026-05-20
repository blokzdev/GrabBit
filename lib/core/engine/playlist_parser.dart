import 'dart:convert';

import 'package:grabbit/core/engine/download_engine.dart';

/// Parses `yt-dlp --flat-playlist -J` stdout into a [PlaylistInfo].
///
/// Playlists/carousels are `{_type: "playlist", entries: [...]}`; a single video
/// is a video object with no `entries`, which collapses to a one-entry result.
PlaylistInfo parsePlaylistJson(String raw) {
  final decoded = jsonDecode(raw.trim());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Unexpected yt-dlp output');
  }

  final entriesRaw = decoded['entries'];
  if (decoded['_type'] == 'playlist' || entriesRaw is List) {
    final entries = <MediaEntry>[];
    if (entriesRaw is List) {
      for (final e in entriesRaw) {
        if (e is Map<String, dynamic>) {
          final entry = _entryFromMap(e, decoded);
          if (entry != null) entries.add(entry);
        }
      }
    }
    return PlaylistInfo(
      entries: entries,
      title: decoded['title'] as String?,
      isPlaylist: true,
    );
  }

  // Single media object → one entry.
  final single = _entryFromMap(decoded, decoded);
  return PlaylistInfo(
    entries: single == null ? const [] : [single],
    title: decoded['title'] as String?,
  );
}

MediaEntry? _entryFromMap(Map<String, dynamic> e, Map<String, dynamic> parent) {
  // A playable URL is required; flat entries carry `url`, single objects carry
  // `webpage_url` or `original_url`.
  final url =
      (e['url'] ?? e['webpage_url'] ?? e['original_url'] ?? e['id']) as String?;
  if (url == null || url.isEmpty) return null;

  final id = e['id'] as String?;
  final title = (e['title'] ?? id ?? url) as String;
  final duration = (e['duration'] as num?)?.round();

  return MediaEntry(
    url: url,
    title: title,
    id: id,
    thumbnailUrl: _thumbnail(e),
    durationSec: duration,
    isImage: _looksLikeImage(e),
  );
}

String? _thumbnail(Map<String, dynamic> e) {
  final thumb = e['thumbnail'];
  if (thumb is String && thumb.isNotEmpty) return thumb;
  final thumbs = e['thumbnails'];
  if (thumbs is List && thumbs.isNotEmpty) {
    final last = thumbs.last;
    if (last is Map<String, dynamic>) return last['url'] as String?;
  }
  return null;
}

/// Heuristic: an entry with no video codec/duration but an image extension is an
/// image (e.g. an Instagram carousel photo). Permissive — when unsure, not image.
bool _looksLikeImage(Map<String, dynamic> e) {
  final ext = (e['ext'] as String?)?.toLowerCase();
  const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'heic'};
  if (ext != null && imageExts.contains(ext)) return true;
  final vcodec = e['vcodec'] as String?;
  if (vcodec == 'none' && e['duration'] == null && e['acodec'] == 'none') {
    return true;
  }
  return false;
}
