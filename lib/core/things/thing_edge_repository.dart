import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/provenance.dart';

/// The default loosely-typed predicate for authored edges (ADR-0004 kind 2).
const String kRelatedToPredicate = 'relatedTo';

/// The canonical store API over the `thing_edges` table (P14d) — the durable
/// authored-edge moat. Mirrors `ThingRepository`: a thin, store-only Drift wrapper
/// (no validation, no graph wiring). Edges are keyed by the composite
/// `(subject, predicate, object)`; an upsert updates `provenance`/`confidence`/
/// `note` and preserves the original `createdAt`. Drift stays canonical; the future
/// Cozo projection (P14e) is derived.
class ThingEdgeRepository {
  ThingEdgeRepository(this._db);

  final AppDatabase _db;

  /// Asserts (or updates) the [subject]→[object] edge labelled [predicate]
  /// (defaults to `relatedTo`), stamped with [provenance] and an optional
  /// [confidence] (0.0–1.0) / [note]. `createdAt` is preserved across updates.
  Future<void> upsertEdge({
    required String subject,
    required String object,
    required Provenance provenance,
    String predicate = kRelatedToPredicate,
    double? confidence,
    String? note,
  }) async {
    final existing = await _edge(subject, predicate, object);
    await _db
        .into(_db.thingEdges)
        .insertOnConflictUpdate(
          ThingEdgesCompanion.insert(
            subject: subject,
            predicate: predicate,
            object: object,
            provenance: provenance.wire,
            confidence: Value(confidence),
            note: Value(note),
            createdAt: existing?.createdAt ?? DateTime.now(),
          ),
        );
  }

  /// Deletes the [subject]→[object] edge labelled [predicate] (no-op if absent).
  Future<void> deleteEdge(
    String subject,
    String predicate,
    String object,
  ) async {
    await (_db.delete(_db.thingEdges)..where(
          (t) =>
              t.subject.equals(subject) &
              t.predicate.equals(predicate) &
              t.object.equals(object),
        ))
        .go();
  }

  /// Outgoing edges from [subject], newest first.
  Future<List<ThingEdge>> edgesFrom(String subject) =>
      (_db.select(_db.thingEdges)
            ..where((t) => t.subject.equals(subject))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Live outgoing edges from [subject], newest first.
  Stream<List<ThingEdge>> watchEdgesFrom(String subject) =>
      (_db.select(_db.thingEdges)
            ..where((t) => t.subject.equals(subject))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Incoming edges to [object], newest first.
  Future<List<ThingEdge>> edgesTo(String object) =>
      (_db.select(_db.thingEdges)
            ..where((t) => t.object.equals(object))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// One-shot count of all authored edges.
  Future<int> countEdges() async {
    final c = _db.thingEdges.subject.count();
    final q = _db.selectOnly(_db.thingEdges)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Live count of all authored edges (for the P14f diagnostic).
  Stream<int> watchEdgeCount() {
    final c = _db.thingEdges.subject.count();
    final q = _db.selectOnly(_db.thingEdges)..addColumns([c]);
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }

  Future<ThingEdge?> _edge(String subject, String predicate, String object) =>
      (_db.select(_db.thingEdges)..where(
            (t) =>
                t.subject.equals(subject) &
                t.predicate.equals(predicate) &
                t.object.equals(object),
          ))
          .getSingleOrNull();
}

final thingEdgeRepositoryProvider = Provider<ThingEdgeRepository>(
  (ref) => ThingEdgeRepository(ref.watch(appDatabaseProvider)),
);
