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
  // --- things (P14e) -----------------------------------------------------
  'thing':
      ':create thing { id: String => '
      'type: String, name: String?, url: String?, '
      'createdAt: Int, updatedAt: Int }',
  'thingVocabEdge':
      ':create thingVocabEdge { subject: String, predicate: String, '
      'object: String }',
  'thingAuthoredEdge':
      ':create thingAuthoredEdge { subject: String, predicate: String, '
      'object: String => provenance: String, confidence: Float?, note: String? }',
};

/// The `:create` scripts for every relation in [graphSchema] not present in
/// [existing] (the names returned by `::relations`). Used by `ensureSchema()`
/// to create only what's missing, so it's idempotent across restarts.
List<String> missingSchemaScripts(Set<String> existing) => [
  for (final entry in graphSchema.entries)
    if (!existing.contains(entry.key)) entry.value,
];

/// Column order (keys then values) for each relation's row tuples — must match
/// the `:create` specs above. Used to build `:replace`/count scripts and to
/// order projected rows (see `graph_projection.dart`).
const Map<String, List<String>> graphRelationColumns = {
  'media': [
    'id',
    'title',
    'site',
    'type',
    'createdAt',
    'isFavorite',
    'contentHash',
    'filePath',
  ],
  'uploader': ['uploaderId', 'name', 'channelId'],
  'site': ['site'],
  'playlist': ['playlistId', 'title'],
  'tag': ['name'],
  'collection': ['collectionId', 'name'],
  'folder': ['folderId', 'name', 'parentId'],
  'postedBy': ['mediaId', 'uploaderId'],
  'onPlatform': ['mediaId', 'site'],
  'inPlaylist': ['mediaId', 'playlistId'],
  'taggedWith': ['mediaId', 'tag'],
  'inCollection': ['mediaId', 'collectionId'],
  'inFolder': ['mediaId', 'folderId'],
  'folderParent': ['folderId', 'parentId'],
  'duplicateOf': ['mediaId', 'otherId'],
  'coDownloadedWith': ['mediaId', 'otherId', 'gapSec'],
  'thing': ['id', 'type', 'name', 'url', 'createdAt', 'updatedAt'],
  'thingVocabEdge': ['subject', 'predicate', 'object'],
  'thingAuthoredEdge': [
    'subject',
    'predicate',
    'object',
    'provenance',
    'confidence',
    'note',
  ],
};

/// Edge relations (vs. node relations) — used for the media `edges` stat.
const Set<String> graphEdgeRelations = {
  'postedBy',
  'onPlatform',
  'inPlaylist',
  'taggedWith',
  'inCollection',
  'inFolder',
  'folderParent',
  'duplicateOf',
  'coDownloadedWith',
};

/// Thing→Thing edge relations (P14e) — counted separately from media edges.
const Set<String> graphThingEdgeRelations = {
  'thingVocabEdge',
  'thingAuthoredEdge',
};

/// A `:replace` script that recreates [relation] with exactly the rows bound to
/// the `$rows` parameter — clearing stale rows, so a rebuild reflects deletes.
/// Reuses the `:create` schema (only the operator changes).
String replaceScript(String relation) {
  final cols = graphRelationColumns[relation]!.join(', ');
  final body = graphSchema[relation]!.replaceFirst(':create', ':replace');
  return '?[$cols] <- \$rows\n$body';
}

/// Counts rows in [relation] (result has a single row `[n]`).
String countScript(String relation) {
  final key = graphRelationColumns[relation]!.first;
  return '?[count($key)] := *$relation{$key}';
}

// --- vector index (P10b-2b) ----------------------------------------------
//
// The HNSW `embedding` relation is intentionally **not** in [graphSchema]: it's
// expensive (one inference per item) and cached, so it must be excluded from the
// deterministic `:replace` rebuild loop and maintained incrementally instead (see
// graph_sync_service.dart `backfillEmbeddings`). Its dimension is fixed by the
// embedder, so these are functions of `dim` rather than const entries. The store
// schema (`ensureSchema`) stays dim-agnostic; the sync service creates these on
// demand once the embedder is ready.

/// The stored embedding relation: a per-item vector plus the hash of the text it
/// was embedded from (the cache key — an unchanged hash means no re-embed).
String embeddingCreateScript(int dim) =>
    ':create embedding { id: String => v: <F32; $dim>, textHash: String }';

/// The HNSW index over the embedding vectors (cosine distance). Created once,
/// right after [embeddingCreateScript]; vector search (`~embedding:idx`) lands in
/// P10c — this PR only builds and maintains the index.
String embeddingHnswScript(int dim) =>
    '::hnsw create embedding:idx { dim: $dim, dtype: F32, '
    'fields: [v], distance: Cosine, m: 16, ef_construction: 50 }';

/// Upserts the rows bound to `\$rows` (`[id, v, textHash]`) into the embedding
/// relation, updating the HNSW index in place.
String embeddingPutScript() =>
    '?[id, v, textHash] <- \$rows\n:put embedding { id => v, textHash }';

/// Removes the ids bound to `\$rows` (`[id]`) — prunes embeddings for items
/// deleted from the library.
String embeddingRemoveScript() => '?[id] <- \$rows\n:rm embedding { id }';

/// Reads the cache: `[id, textHash]` for every stored embedding, so the backfill
/// can diff against the desired set and re-embed only what changed.
String embeddingPairsScript() => '?[id, textHash] := *embedding{id, textHash}';

/// Counts stored embeddings (result has a single row `[n]`).
String embeddingCountScript() => '?[count(id)] := *embedding{id}';

/// Sidecar that records which embedder (`model`, `dim`) the `embedding` relation
/// was built with, so a model/dimension change can drop + recreate it rather
/// than silently mixing vector spaces. Kept out of [graphSchema] like `embedding`.
String embeddingMetaCreateScript() =>
    ':create embedding_meta { key: String => value: String }';

/// Reads the sidecar as `[key, value]` rows.
String embeddingMetaReadScript() =>
    '?[key, value] := *embedding_meta{key, value}';

/// Upserts the rows bound to `\$rows` (`[key, value]`) into the sidecar.
String embeddingMetaPutScript() =>
    '?[key, value] <- \$rows\n:put embedding_meta { key => value }';

/// Drops the stored embedding relation (and its HNSW index) — used when the
/// embedder model/dimension changes, so it's recreated fresh.
String embeddingDropScript() => '::remove embedding';

// --- Thing-level vector index (P16f) -------------------------------------
//
// A parallel HNSW relation keyed by `things.id`, built from each Thing's JSON-LD
// text, so **non-MediaObject** Things (Recipe/Event/Place/… — a MediaObject's
// vector already lives in `embedding` under the same id) are recalled by "Ask
// your library". Same shape/dimension as `embedding`; it shares `embedding_meta`
// (one embedder governs both), and `backfillEmbeddings` maintains it incrementally.

/// The stored Thing-embedding relation (keyed by `things.id`), mirroring
/// [embeddingCreateScript].
String thingEmbeddingCreateScript(int dim) =>
    ':create thing_embedding { id: String => v: <F32; $dim>, textHash: String }';

/// The HNSW index over the Thing-embedding vectors (cosine distance).
String thingEmbeddingHnswScript(int dim) =>
    '::hnsw create thing_embedding:idx { dim: $dim, dtype: F32, '
    'fields: [v], distance: Cosine, m: 16, ef_construction: 50 }';

/// Upserts `[id, v, textHash]` rows into the Thing-embedding relation.
String thingEmbeddingPutScript() =>
    '?[id, v, textHash] <- \$rows\n:put thing_embedding { id => v, textHash }';

/// Removes the ids bound to `\$rows` (`[id]`) from the Thing-embedding relation.
String thingEmbeddingRemoveScript() =>
    '?[id] <- \$rows\n:rm thing_embedding { id }';

/// Reads the Thing-embedding cache: `[id, textHash]` for every stored vector.
String thingEmbeddingPairsScript() =>
    '?[id, textHash] := *thing_embedding{id, textHash}';

/// Counts stored Thing embeddings (result has a single row `[n]`).
String thingEmbeddingCountScript() => '?[count(id)] := *thing_embedding{id}';

/// Drops the stored Thing-embedding relation (and its HNSW index).
String thingEmbeddingDropScript() => '::remove thing_embedding';
