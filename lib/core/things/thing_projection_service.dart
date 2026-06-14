import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/media_object_projection.dart';
import 'package:grabbit/core/things/thing_repository.dart';

/// Projects the canonical library (`media_items` + `media_metadata`) into derived,
/// rebuildable `MediaObject` Things and keeps them current (P14c, ADR-0003).
/// Mirrors `GraphSyncService`: the media tables stay the source of truth, and a
/// debounced Drift `tableUpdates` listener is the event bus — zero repo coupling,
/// no hooks scattered across mutation sites. Projection writes hit the `things`
/// table (not the watched tables), so they never re-trigger the listener.
class ThingProjectionService {
  ThingProjectionService(
    this._repo,
    this._db, {
    this._debounce = const Duration(seconds: 2),
  });

  final ThingRepository _repo;
  final AppDatabase _db;
  final Duration _debounce;

  StreamSubscription<void>? _sub;
  Timer? _debounceTimer;
  bool _running = false;

  /// Subscribes to library-table changes and re-projects (debounced).
  void start() {
    _sub ??= _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([_db.mediaItems, _db.mediaMetadata]),
        )
        .listen((_) {
          _debounceTimer?.cancel();
          _debounceTimer = Timer(_debounce, () => unawaited(_safeBackfill()));
        });
  }

  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_sub?.cancel());
    _sub = null;
  }

  Future<void> _safeBackfill() async {
    try {
      await backfillMediaObjects();
    } catch (_) {
      // Projection is best-effort; a failure must never surface to the user.
      // Drift stays canonical, so the next pass rebuilds from it.
    }
  }

  /// Rebuildable, idempotent backfill: project every media item into its
  /// `MediaObject` Thing, writing only the ones whose canonical `jsonld` changed
  /// (the diff — like `backfillEmbeddings`), and pruning `MediaObject` Things whose
  /// media row is gone. Re-runs cheaply; re-derives automatically when the
  /// projection logic changes (the projected `jsonld` differs from the stored one).
  /// Returns how many Things were written / pruned.
  Future<({int upserted, int pruned})> backfillMediaObjects() async {
    if (_running) return (upserted: 0, pruned: 0);
    _running = true;
    try {
      final items = await _db.select(_db.mediaItems).get();
      final metas = await _db.select(_db.mediaMetadata).get();
      final metaById = {for (final m in metas) m.itemId: m};
      final existing = await _db.select(_db.things).get();
      final storedJson = {for (final t in existing) t.id: t.jsonld};

      final desiredIds = <String>{};
      var upserted = 0;
      for (final item in items) {
        await Future<void>.delayed(Duration.zero); // yield between items
        desiredIds.add(item.id);
        final doc = projectMediaObject(item, metaById[item.id]);
        if (storedJson[item.id] == doc.toJsonString()) continue; // unchanged
        await _repo.upsertThing(item.id, doc);
        upserted++;
      }

      var pruned = 0;
      for (final t in existing) {
        if (!kMediaObjectTypes.contains(t.type)) continue; // leave other Things
        if (desiredIds.contains(t.id)) continue;
        await _repo.deleteThing(t.id);
        pruned++;
      }
      return (upserted: upserted, pruned: pruned);
    } finally {
      _running = false;
    }
  }
}

/// Started for the app's lifetime; reading it begins the debounced projection
/// listener. Hand-written (mirrors `thingRepositoryProvider`); a plain `Provider`
/// is container-lived, so no codegen.
final thingProjectionServiceProvider = Provider<ThingProjectionService>((ref) {
  final service = ThingProjectionService(
    ref.watch(thingRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
  service.start();
  ref.onDispose(service.dispose);
  return service;
});
