import 'package:grabbit/core/db/database.dart';

/// A read-only snapshot of the canonical library, gathered from Drift, that the
/// projection turns into Cozo relation rows. Kept as plain lists so
/// [buildGraphRelations] is pure and unit-testable without the engine.
class LibrarySnapshot {
  const LibrarySnapshot({
    this.media = const [],
    this.metadata = const [],
    this.folders = const [],
    this.tags = const [],
    this.tagLinks = const [],
    this.collections = const [],
    this.collectionLinks = const [],
  });

  final List<MediaItem> media;
  final List<MediaMetadataData> metadata;
  final List<Folder> folders;
  final List<Tag> tags;
  final List<({String itemId, String tag})> tagLinks;
  final List<Collection> collections;
  final List<({String itemId, int collectionId})> collectionLinks;
}

/// Downloads within this window of each other are treated as one session and
/// chained by `coDownloadedWith` (a deterministic temporal-proximity signal).
const Duration _coDownloadWindow = Duration(minutes: 5);

/// Projects [snapshot] into `relationName → rows` (each row a value list in the
/// column order of `graphRelationColumns`). Pure: no I/O, deterministic — the
/// heart of the Drift→Cozo sync. Entity nodes are de-duplicated by key; edges
/// are emitted only when their foreign key is present. `duplicateOf` (identical
/// `contentHash`) and `coDownloadedWith` (close `createdAt`) are deterministic
/// signals already in the library, projected here; `similarTo` (vector-derived)
/// stays for P10c.
Map<String, List<List<Object?>>> buildGraphRelations(LibrarySnapshot snapshot) {
  final metaByItem = {for (final m in snapshot.metadata) m.itemId: m};

  // --- nodes ---
  final media = <List<Object?>>[];
  final sites = <String>{};
  final uploaders = <String, List<Object?>>{}; // uploaderId → row
  final playlists = <String, List<Object?>>{}; // playlistId → row
  for (final it in snapshot.media) {
    media.add([
      it.id,
      it.title,
      it.site,
      it.type,
      it.createdAt.millisecondsSinceEpoch,
      it.isFavorite,
      it.contentHash,
      it.filePath,
    ]);
    sites.add(it.site);
    final m = metaByItem[it.id];
    final uploaderId = m?.uploaderId;
    if (uploaderId != null && uploaderId.isNotEmpty) {
      uploaders[uploaderId] = [
        uploaderId,
        m?.uploader ?? uploaderId,
        m?.channelId,
      ];
    }
    final playlistId = m?.playlistId;
    if (playlistId != null && playlistId.isNotEmpty) {
      playlists[playlistId] = [playlistId, m?.playlistTitle ?? playlistId];
    }
  }

  // --- edges ---
  final postedBy = <List<Object?>>[];
  final onPlatform = <List<Object?>>[];
  final inPlaylist = <List<Object?>>[];
  final inFolder = <List<Object?>>[];
  for (final it in snapshot.media) {
    onPlatform.add([it.id, it.site]);
    if (it.folderId != null) inFolder.add([it.id, it.folderId]);
    final m = metaByItem[it.id];
    final uploaderId = m?.uploaderId;
    if (uploaderId != null && uploaderId.isNotEmpty) {
      postedBy.add([it.id, uploaderId]);
    }
    final playlistId = m?.playlistId;
    if (playlistId != null && playlistId.isNotEmpty) {
      inPlaylist.add([it.id, playlistId]);
    }
  }

  final folderParent = [
    for (final f in snapshot.folders)
      if (f.parentId != null) [f.id, f.parentId],
  ];

  // --- deterministic similarity edges ---
  // duplicateOf: symmetric pairs within each non-empty contentHash group.
  final byHash = <String, List<String>>{};
  for (final it in snapshot.media) {
    final h = it.contentHash;
    if (h != null && h.isNotEmpty) (byHash[h] ??= []).add(it.id);
  }
  final duplicateOf = <List<Object?>>[];
  for (final ids in byHash.values) {
    if (ids.length < 2) continue;
    for (var i = 0; i < ids.length; i++) {
      for (var j = i + 1; j < ids.length; j++) {
        duplicateOf
          ..add([ids[i], ids[j]])
          ..add([ids[j], ids[i]]);
      }
    }
  }

  // coDownloadedWith: chain consecutive downloads within _coDownloadWindow,
  // weighted by the gap in seconds (symmetric). O(n) over time-sorted media.
  final timeSorted = [...snapshot.media]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final coDownloadedWith = <List<Object?>>[];
  for (var i = 1; i < timeSorted.length; i++) {
    final prev = timeSorted[i - 1];
    final cur = timeSorted[i];
    final gap = cur.createdAt.difference(prev.createdAt);
    if (gap <= _coDownloadWindow) {
      final gapSec = gap.inSeconds;
      coDownloadedWith
        ..add([prev.id, cur.id, gapSec])
        ..add([cur.id, prev.id, gapSec]);
    }
  }

  return {
    'media': media,
    'uploader': uploaders.values.toList(),
    'site': [
      for (final s in sites) [s],
    ],
    'playlist': playlists.values.toList(),
    'tag': [
      for (final t in snapshot.tags) [t.name],
    ],
    'collection': [
      for (final c in snapshot.collections) [c.id, c.name],
    ],
    'folder': [
      for (final f in snapshot.folders) [f.id, f.name, f.parentId],
    ],
    'postedBy': postedBy,
    'onPlatform': onPlatform,
    'inPlaylist': inPlaylist,
    'taggedWith': [
      for (final l in snapshot.tagLinks) [l.itemId, l.tag],
    ],
    'inCollection': [
      for (final l in snapshot.collectionLinks) [l.itemId, l.collectionId],
    ],
    'inFolder': inFolder,
    'folderParent': folderParent,
    'duplicateOf': duplicateOf,
    'coDownloadedWith': coDownloadedWith,
  };
}
