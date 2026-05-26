import 'dart:convert';

/// The subset of yt-dlp's `.info.json` we persist for faceted browsing/filtering.
/// All fields are optional — availability varies by site.
class InfoJson {
  const InfoJson({
    this.uploader,
    this.uploaderId,
    this.channelId,
    this.sourceId,
    this.uploadDate,
    this.description,
    this.tags,
    this.extractor,
    this.width,
    this.height,
  });

  final String? uploader; // channel / author display name
  final String? uploaderId; // handle / username
  final String? channelId;
  final String? sourceId; // yt-dlp %(id)s
  final String? uploadDate; // raw YYYYMMDD
  final String? description;
  final String? tags; // comma-joined
  final String? extractor; // site key
  final int? width; // pixel width of the (merged) video
  final int? height; // pixel height
}

/// Parses a decoded `.info.json` map. Falls back across related keys and is
/// tolerant of missing/empty values.
InfoJson parseInfoJson(Map<String, dynamic> json) {
  String? str(String key) {
    final v = json[key];
    return v is String && v.trim().isNotEmpty ? v : null;
  }

  int? dimension(String key) {
    final v = json[key];
    return v is num && v > 0 ? v.toInt() : null;
  }

  final rawTags = json['tags'];
  final tags = rawTags is List
      ? rawTags
            .whereType<String>()
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .join(', ')
      : null;

  return InfoJson(
    uploader: str('uploader') ?? str('channel'),
    uploaderId: str('uploader_id'),
    channelId: str('channel_id'),
    sourceId: str('id'),
    uploadDate: str('upload_date'),
    description: str('description'),
    tags: (tags != null && tags.isNotEmpty) ? tags : null,
    extractor: str('extractor_key') ?? str('extractor'),
    width: dimension('width'),
    height: dimension('height'),
  );
}

/// Parses raw `.info.json` text; returns null on any malformed input.
InfoJson? parseInfoJsonString(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return parseInfoJson(decoded);
  } catch (_) {}
  return null;
}
