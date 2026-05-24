/// CozoScript for the deterministic graph schema (docs/GRAPH-SPEC.md §5).
///
/// P10a creates the node + entity + typed-edge relations only. The HNSW
/// `embedding` vector relation is added in P10b once the embedder (and its
/// dimension) is known. Pure Dart so the schema is unit-testable without the
/// native engine.
library;

/// Relation name → its `:create` CozoScript. Order is insignificant (relations
/// are independent), but kept stable for readable diffs. Keys before `=>` are
/// the relation's primary key; `?` marks a nullable value column.
const Map<String, String> graphSchema = {
  // --- nodes -------------------------------------------------------------
  'media':
      ':create media { id: String => '
      'title: String, site: String, type: String, createdAt: Int, '
      'isFavorite: Bool, contentHash: String?, filePath: String }',
  'uploader':
      ':create uploader { uploaderId: String => '
      'name: String, channelId: String? }',
  'site': ':create site { site: String }',
  'playlist': ':create playlist { playlistId: String => title: String }',
  'tag': ':create tag { name: String }',
  'collection': ':create collection { collectionId: Int => name: String }',
  'folder': ':create folder { folderId: Int => name: String, parentId: Int? }',
  // --- typed edges -------------------------------------------------------
  'postedBy': ':create postedBy { mediaId: String, uploaderId: String }',
  'onPlatform': ':create onPlatform { mediaId: String, site: String }',
  'inPlaylist': ':create inPlaylist { mediaId: String, playlistId: String }',
  'taggedWith': ':create taggedWith { mediaId: String, tag: String }',
  'inCollection': ':create inCollection { mediaId: String, collectionId: Int }',
  'inFolder': ':create inFolder { mediaId: String, folderId: Int }',
  'folderParent': ':create folderParent { folderId: Int, parentId: Int }',
  'duplicateOf': ':create duplicateOf { mediaId: String, otherId: String }',
  'coDownloadedWith':
      ':create coDownloadedWith { mediaId: String, otherId: String => '
      'gapSec: Int }',
};

/// The `:create` scripts for every relation in [graphSchema] not present in
/// [existing] (the names returned by `::relations`). Used by `ensureSchema()`
/// to create only what's missing, so it's idempotent across restarts.
List<String> missingSchemaScripts(Set<String> existing) => [
  for (final entry in graphSchema.entries)
    if (!existing.contains(entry.key)) entry.value,
];
