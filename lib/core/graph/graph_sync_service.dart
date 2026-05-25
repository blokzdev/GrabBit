import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/unavailable_inference_engine.dart';
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
    this._engine = const UnavailableInferenceEngine(),
    this._debounce = const Duration(seconds: 2),
  });

  final GraphStore _store;
  final AppDatabase _db;
  final InferenceEngine _engine;
  final Duration _debounce;

  /// How many embeddings to `:put` per script (bounds the JSON param size).
  static const _embedChunk = 64;

  StreamSubscription<void>? _sub;
  Timer? _debounceTimer;
  bool _rebuilding = false;

  /// Bump when the projection logic changes so a startup self-heal rebuilds even
  /// though the data hasn't changed. Combined with the Drift schema version.
  static const _edgeBuilderVersion = 1;

  /// Identifies the shape of the projected graph; persisted to detect staleness.
  String get fingerprint => '${_db.schemaVersion}.$_edgeBuilderVersion';

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
    if (storedVersion == fingerprint) return;
    final stats = await rebuild();
    if (stats.available) await stamp(fingerprint);
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
    await _ensureEmbeddingSchema(_engine.dimension);

    final desired = buildEmbeddingDocs(
      await _snapshot(),
      modelId: _engine.model.id,
    );
    final current = await _embeddingPairs();
    final diff = diffEmbeddings(current: current, desired: desired);

    var done = 0;
    final rows = <List<Object?>>[];
    for (final doc in diff.toEmbed) {
      final vector = await _engine.embed(doc.text);
      rows.add([doc.id, vector, doc.textHash]);
      done++;
      onProgress?.call(diff.toEmbed.isEmpty ? 1 : done / diff.toEmbed.length);
      if (rows.length >= _embedChunk) {
        await _store.runScript(embeddingPutScript(), {'rows': List.of(rows)});
        rows.clear();
      }
    }
    if (rows.isNotEmpty) {
      await _store.runScript(embeddingPutScript(), {'rows': rows});
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

  /// Creates the embedding relation + HNSW index if absent (idempotent — mirrors
  /// `missingSchemaScripts`). Owned here, not by `GraphStore.ensureSchema`, since
  /// the dimension is an embedder concern and the relation shouldn't exist on
  /// devices that never enable semantic search.
  Future<void> _ensureEmbeddingSchema(int dim) async {
    final res = await _store.runScript('::relations');
    final headers = (res['headers'] as List?) ?? const [];
    final nameIdx = headers.indexOf('name');
    final rows = (res['rows'] as List?) ?? const [];
    final exists =
        nameIdx >= 0 &&
        rows.any(
          (r) => r is List && nameIdx < r.length && r[nameIdx] == 'embedding',
        );
    if (exists) return;
    await _store.runScript(embeddingCreateScript(dim));
    await _store.runScript(embeddingHnswScript(dim));
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
