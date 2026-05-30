import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery, countAll;
import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/unavailable_embedder_engine.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/cozo_schema.dart';
import 'package:grabbit/core/graph/embedding_doc.dart';
import 'package:grabbit/core/graph/graph_projection.dart';
import 'package:grabbit/core/graph/graph_store.dart';

class GraphStats {
  const GraphStats({
    required this.available,
    this.mediaNodes = 0,
    this.edges = 0,
    this.embeddings = 0,
  });

  final bool available;
  final int mediaNodes;
  final int edges;

  /// Stored vector embeddings (0 when semantic search is off / not yet built).
  final int embeddings;
}

/// Outcome of an embedding backfill pass.
class EmbeddingStats {
  const EmbeddingStats({
    required this.available,
    this.embedded = 0,
    this.pruned = 0,
    this.total = 0,
  });

  /// False when the embedder isn't ready (AI off, model not downloaded, or a
  /// non-arm64 / CI host) — the pass was a graceful no-op.
  final bool available;

  /// Items (re-)embedded this pass.
  final int embedded;

  /// Stale embeddings removed (items deleted from the library).
  final int pruned;

  /// Total embeddings stored after the pass.
  final int total;
}

/// Projects the canonical Drift library into the derived Cozo graph and keeps it
/// current. Drift stays the source of truth; the graph is rebuildable from it at
/// any time (see docs/GRAPH-SPEC.md §3, §6). All operations no-op gracefully when
/// the engine isn't available (non-arm64 device / CI host).
class GraphSyncService {
  GraphSyncService(
    this._store,
    this._db, {
    this._engine = const UnavailableEmbedderEngine(),
    this._debounce = const Duration(seconds: 2),
  });

  final GraphStore _store;
  final AppDatabase _db;
  final EmbedderEngine _engine;
  final Duration _debounce;

  /// How many embeddings to `:put` per script (bounds the JSON param size).
  static const _embedChunk = 64;

  StreamSubscription<void>? _sub;
  Timer? _debounceTimer;
  bool _rebuilding = false;

  /// Bump when the projection logic changes so a startup self-heal rebuilds even
  /// though the data hasn't changed. Combined with the Drift schema version.
  /// v2: `duplicateOf` + `coDownloadedWith` are now projected (P10b-3).
  /// v3: the embed doc now includes a transcript slice (P10g-1).
  static const _edgeBuilderVersion = 3;

  /// Identifies the shape of the projected graph; persisted to detect staleness.
  /// Includes the embedder model id so a model change trips the self-heal pass
  /// (the dimension-level guard lives in [_ensureEmbeddingSchema]).
  String get fingerprint =>
      '${_db.schemaVersion}.$_edgeBuilderVersion.${_engine.model.id}';

  /// Full, idempotent rebuild: project every relation from Drift and `:replace`
  /// it (clearing stale rows). Returns post-rebuild counts.
  Future<GraphStats> rebuild() async {
    if (!await _ensureOpen()) return const GraphStats(available: false);
    final relations = buildGraphRelations(await _snapshot());
    for (final name in graphSchema.keys) {
      await _store.runScript(replaceScript(name), {
        'rows': relations[name] ?? const <List<Object?>>[],
      });
    }
    return _computeStats();
  }

  /// Current counts without rebuilding (for the self-test display).
  Future<GraphStats> stats() async {
    if (!await _ensureOpen()) return const GraphStats(available: false);
    return _computeStats();
  }

  /// Rebuilds only when the projection shape changed since [storedVersion]
  /// (or on first run), then stamps the new [fingerprint]. The live listener
  /// handles data changes; this handles logic/schema changes.
  Future<void> syncIfStale({
    required String storedVersion,
    required Future<void> Function(String version) stamp,
  }) async {
    if (storedVersion != fingerprint) {
      final stats = await rebuild();
      if (stats.available) await stamp(fingerprint);
      return;
    }
    // Fingerprint matches, but a prior partial/failed sync could still leave the
    // graph diverged from Drift. Cheaply confirm the media counts agree, and
    // rebuild if they don't (GRAPH-SPEC §3).
    if (!await _ensureOpen()) return;
    if (await _driftMediaCount() != await _count('media')) await rebuild();
  }

  /// Closes the Cozo store (e.g. when the app backgrounds) to release the SQLite
  /// handle/lock and flush. The next rebuild/backfill/stats call reopens lazily
  /// via [_ensureOpen]. Best-effort; skips while a rebuild is in flight.
  Future<void> releaseStore() async {
    _debounceTimer?.cancel();
    if (_rebuilding) return;
    try {
      await _store.close();
    } catch (_) {}
  }

  /// Subscribes to library-table changes and rebuilds (debounced). Zero repo
  /// coupling — Drift's own update stream is the event bus. Cozo writes go to a
  /// separate DB, so they don't re-trigger this.
  void start() {
    _sub ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.mediaItems,
            _db.mediaMetadata,
            _db.folders,
            _db.tags,
            _db.mediaTags,
            _db.collections,
            _db.mediaCollections,
          ]),
        )
        .listen((_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_debounce, () => unawaited(_safeRebuild()));
        });
  }

  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
  }

  Future<void> _safeRebuild() async {
    if (_rebuilding) return;
    _rebuilding = true;
    try {
      await rebuild();
      // Keep the vector index current too. No-op unless the embedder is ready;
      // incremental, so steady-state cost is just reading the cache + diffing.
      await backfillEmbeddings();
    } catch (_) {
      // Sync is best-effort; a failure must never surface to the user.
    } finally {
      _rebuilding = false;
    }
  }

  /// Embeds library items into the Cozo HNSW `embedding` relation, **cached** by
  /// text hash so a pass only embeds new/changed items and prunes deleted ones
  /// (see docs/GRAPH-SPEC.md §6). Gated on the embedder being ready — a cheap
  /// no-op when semantic search is off, the model isn't downloaded, or the host
  /// can't run it. [onProgress] reports 0.0–1.0 over the items being embedded.
  Future<EmbeddingStats> backfillEmbeddings({
    void Function(double progress)? onProgress,
  }) async {
    if (!await _ensureOpen()) return const EmbeddingStats(available: false);
    if (!await _engine.ensureReady()) {
      return const EmbeddingStats(available: false);
    }
    await _ensureEmbeddingSchema(_engine.model.id, _engine.dimension);

    final desired = buildEmbeddingDocs(
      await _snapshot(),
      modelId: _engine.model.id,
    );
    final current = await _embeddingPairs();
    final diff = diffEmbeddings(current: current, desired: desired);

    final toEmbed = diff.toEmbed;
    var done = 0;
    for (var i = 0; i < toEmbed.length; i += _embedChunk) {
      final end = (i + _embedChunk < toEmbed.length)
          ? i + _embedChunk
          : toEmbed.length;
      final chunk = toEmbed.sublist(i, end);
      final vectors = await _engine.embedBatch([for (final d in chunk) d.text]);
      await _store.runScript(embeddingPutScript(), {
        'rows': [
          for (var k = 0; k < chunk.length; k++)
            [chunk[k].id, vectors[k], chunk[k].textHash],
        ],
      });
      done += chunk.length;
      onProgress?.call(done / toEmbed.length);
    }
    if (diff.toRemove.isNotEmpty) {
      await _store.runScript(embeddingRemoveScript(), {
        'rows': [
          for (final id in diff.toRemove) [id],
        ],
      });
    }
    return EmbeddingStats(
      available: true,
      embedded: diff.toEmbed.length,
      pruned: diff.toRemove.length,
      total: await _embeddingCount(),
    );
  }

  /// Ensures the embedding relation + HNSW index exist **for the current model**.
  /// Owned here, not by `GraphStore.ensureSchema`, since the dimension is an
  /// embedder concern and the relation shouldn't exist on devices that never
  /// enable semantic search. A sidecar (`embedding_meta`) records the model+dim
  /// the index was built with; if either changed (or there's no record), the
  /// relation is dropped and recreated so vectors never mix spaces — the cache
  /// reset makes the next backfill re-embed everything.
  Future<void> _ensureEmbeddingSchema(String modelId, int dim) async {
    final relations = await _relationNames();
    if (!relations.contains('embedding_meta')) {
      await _store.runScript(embeddingMetaCreateScript());
    }
    final meta = await _readMeta();
    final matches = meta['model'] == modelId && meta['dim'] == '$dim';
    final hasEmbedding = relations.contains('embedding');
    if (hasEmbedding && matches) return;
    if (hasEmbedding) await _store.runScript(embeddingDropScript());
    await _store.runScript(embeddingCreateScript(dim));
    await _store.runScript(embeddingHnswScript(dim));
    await _store.runScript(embeddingMetaPutScript(), {
      'rows': [
        ['model', modelId],
        ['dim', '$dim'],
      ],
    });
  }

  /// Names of the stored relations (`::relations`), empty on error.
  Future<Set<String>> _relationNames() async {
    try {
      final res = await _store.runScript('::relations');
      final headers = (res['headers'] as List?) ?? const [];
      final nameIdx = headers.indexOf('name');
      if (nameIdx < 0) return {};
      final rows = (res['rows'] as List?) ?? const [];
      return {
        for (final r in rows)
          if (r is List && nameIdx < r.length) '${r[nameIdx]}',
      };
    } catch (_) {
      return {};
    }
  }

  /// Reads the `embedding_meta` sidecar as a `key → value` map, empty on error.
  Future<Map<String, String>> _readMeta() async {
    try {
      final res = await _store.runScript(embeddingMetaReadScript());
      final rows = (res['rows'] as List?) ?? const [];
      return {
        for (final r in rows)
          if (r is List && r.length >= 2) '${r[0]}': '${r[1]}',
      };
    } catch (_) {
      return {};
    }
  }

  /// Canonical media count straight from Drift (no full row load).
  Future<int> _driftMediaCount() async {
    final c = countAll();
    final q = _db.selectOnly(_db.mediaItems)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  Future<Map<String, String>> _embeddingPairs() async {
    try {
      final res = await _store.runScript(embeddingPairsScript());
      final rows = (res['rows'] as List?) ?? const [];
      return {
        for (final r in rows)
          if (r is List && r.length >= 2) '${r[0]}': '${r[1]}',
      };
    } catch (_) {
      return {};
    }
  }

  Future<bool> _ensureOpen() async {
    if (_store.isAvailable) return true;
    try {
      return await _store.open();
    } catch (_) {
      return false;
    }
  }

  Future<GraphStats> _computeStats() async {
    final mediaNodes = await _count('media');
    var edges = 0;
    for (final rel in graphEdgeRelations) {
      edges += await _count(rel);
    }
    return GraphStats(
      available: true,
      mediaNodes: mediaNodes,
      edges: edges,
      embeddings: await _embeddingCount(),
    );
  }

  /// Stored embedding count, or 0 when the relation doesn't exist yet (the query
  /// errors before the first backfill — treat that as zero).
  Future<int> _embeddingCount() async {
    try {
      final res = await _store.runScript(embeddingCountScript());
      final rows = (res['rows'] as List?) ?? const [];
      if (rows.isEmpty) return 0;
      final first = (rows.first as List?) ?? const [];
      final n = first.isEmpty ? 0 : first.first;
      return n is int ? n : (int.tryParse('$n') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _count(String relation) async {
    try {
      final res = await _store.runScript(countScript(relation));
      final rows = (res['rows'] as List?) ?? const [];
      if (rows.isEmpty) return 0;
      final first = (rows.first as List?) ?? const [];
      final n = first.isEmpty ? 0 : first.first;
      return n is int ? n : (int.tryParse('$n') ?? 0);
    } catch (_) {
      return 0;
    }
  }

  Future<LibrarySnapshot> _snapshot() async {
    final tags = await _db.select(_db.tags).get();
    final tagNameById = {for (final t in tags) t.id: t.name};
    final mediaTags = await _db.select(_db.mediaTags).get();
    final collections = await _db.select(_db.collections).get();
    final mediaCollections = await _db.select(_db.mediaCollections).get();
    return LibrarySnapshot(
      media: await _db.select(_db.mediaItems).get(),
      metadata: await _db.select(_db.mediaMetadata).get(),
      folders: await _db.select(_db.folders).get(),
      tags: tags,
      tagLinks: [
        for (final mt in mediaTags)
          if (tagNameById[mt.tagId] != null)
            (itemId: mt.itemId, tag: tagNameById[mt.tagId]!),
      ],
      collections: collections,
      collectionLinks: [
        for (final mc in mediaCollections)
          (itemId: mc.itemId, collectionId: mc.collectionId),
      ],
    );
  }
}
