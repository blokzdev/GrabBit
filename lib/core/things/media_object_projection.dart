import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// The schema.org `MediaObject` subtypes this projection emits — the set the
/// backfill prunes against (a Thing of one of these types whose media row is gone
/// is an orphaned projection).
const Set<String> kMediaObjectTypes = {
  'VideoObject',
  'AudioObject',
  'ImageObject',
};

/// Pure, deterministic projection of a canonical library row pair
/// `(MediaItem + MediaMetadata?)` into a schema.org `MediaObject`-family
/// [ThingDoc] (ADR-0003) — no I/O, no vocabulary. The media tables stay canonical;
/// the Thing is a derived, rebuildable view keyed by `media_items.id`.
///
/// Null/blank inputs are omitted so the document carries only present facts.
/// Provenance is stamped under `grabbit:` (ADR-0004), which boundary validation
/// ignores. Object-valued properties (`author`, `isPartOf`) are nested nodes for a
/// later edge projection (P14d/P16).
ThingDoc projectMediaObject(MediaItem item, MediaMetadataData? meta) {
  final isImage = item.type == 'image';

  final json = <String, dynamic>{
    '@context': 'https://schema.org',
    '@type': _typeFor(item.type),
    'name': item.title,
    'url': item.sourceUrl,
    'contentUrl': item.filePath, // the local file leaf (ADR-0003)
  };

  if (_notBlank(meta?.description)) json['description'] = meta!.description;
  if (_notBlank(item.thumbPath)) json['thumbnailUrl'] = item.thumbPath;
  if (meta?.uploadDate != null) {
    json['uploadDate'] = meta!.uploadDate!.toIso8601String();
  }
  if (!isImage && item.durationSec != null) {
    json['duration'] = iso8601Duration(item.durationSec!);
  }
  if (item.width != null) json['width'] = item.width;
  if (item.height != null) json['height'] = item.height;
  if (item.sizeBytes != null) json['contentSize'] = item.sizeBytes!.toString();
  if (_notBlank(meta?.tags)) json['keywords'] = meta!.tags;
  if (!isImage && _notBlank(meta?.transcript)) {
    json['transcript'] = meta!.transcript;
  }
  if (_notBlank(meta?.uploader)) {
    json['author'] = {
      '@type': 'Person',
      'name': meta!.uploader,
      if (_notBlank(meta.channelId)) 'identifier': meta.channelId,
    };
  }
  if (_notBlank(meta?.playlistTitle)) {
    json['isPartOf'] = {
      '@type': 'CreativeWork',
      'name': meta!.playlistTitle,
      if (_notBlank(meta.playlistId)) 'identifier': meta.playlistId,
    };
  }

  // Provenance (ADR-0004): a deterministic direct-parse from the canonical media
  // row. `capturedAt` is the stable `createdAt` (never `now()`) so re-projection
  // stays byte-identical and the P14c backfill diff holds.
  json[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
    provenance: Provenance.directParse,
    sourceRef: item.sourceUrl,
    capturedAt: item.createdAt,
  );

  return ThingDoc(json);
}

String _typeFor(String mediaType) => switch (mediaType) {
  'video' => 'VideoObject',
  'audio' => 'AudioObject',
  'image' => 'ImageObject',
  _ => 'MediaObject',
};

bool _notBlank(String? s) => s != null && s.trim().isNotEmpty;

/// Formats whole [seconds] as an ISO-8601 duration (`PT1H1M1S`), the form schema.org
/// `duration` expects. Negative input is clamped to zero; zero is `PT0S`. (The UI's
/// `formatDuration` is clock-style `H:MM:SS` — a different need.)
String iso8601Duration(int seconds) {
  final total = seconds < 0 ? 0 : seconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  final out = StringBuffer('PT');
  if (h > 0) out.write('${h}H');
  if (m > 0) out.write('${m}M');
  if (s > 0 || (h == 0 && m == 0)) out.write('${s}S');
  return out.toString();
}
