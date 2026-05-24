import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/cozo_schema.dart';
import 'package:grabbit/core/graph/graph_projection.dart';
import 'package:grabbit/core/graph/graph_store.dart';

class GraphStats {
  const GraphStats({
    required this.available,
    this.mediaNodes = 0,
    this.edges = 0,
  });

  final bool available;
  final int mediaNodes;
  final int edges;
}

/// Projects the canonical Drift library into the derived Cozo graph and keeps it
/// current. Drift stays the source of truth; the graph is rebuildable from it at
/// any time (see docs/GRAPH-SPEC.md §3, §6). All operations no-op gracefully when
/// the engine isn't available (non-arm64 device / CI host).
class GraphSyncService {
  GraphSyncService(
    this._store,
    this._db, {
    this._debounce = const Duration(seconds: 2),
  });

  final GraphStore _store;
  final AppDatabase _db;
  final Duration _debounce;

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
    } catch (_) {
      // Sync is best-effort; a failure must never surface to the user.
    } finally {
      _rebuilding = false;
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
    return GraphStats(available: true, mediaNodes: mediaNodes, edges: edges);
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
