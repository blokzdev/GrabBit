import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// The canonical store API over the Drift `things` table (P14b) — the seam every
/// Thing writer (the P14c MediaObject projection, later imports) goes through and
/// every reader (the P14f diagnostic, browsers) reads.
///
/// The `jsonld` column is the single source of truth (ADR-0001); `name`/`url` are a
/// **re-derived promoted cache** for query/sort, never a second source of truth — on
/// every write they are recomputed from the [ThingDoc], so the JSON-LD always wins.
/// The repo is **store-only**: it does not validate (that's the writer's job at true
/// ingest, via `thing_validation.dart`), which keeps it synchronous and
/// dependency-free. Drift stays canonical; Cozo stays the derived index.
class ThingRepository {
  ThingRepository(this._db);

  final AppDatabase _db;

  /// Upserts the Thing identified by [id] from its canonical [doc]. [id] is
  /// GrabBit-owned and explicit (the P14c projection passes `media_items.id`), not
  /// the JSON-LD `@id` (ADR-0003). `type`/`name`/`url` are always re-derived from
  /// [doc] — the JSON-LD wins (ADR-0001). `createdAt` is preserved across updates
  /// (read-then-write, since the codebase doesn't use Drift's `DoUpdate`);
  /// `updatedAt` is bumped on every write.
  Future<void> upsertThing(String id, ThingDoc doc) async {
    final existing = await thingById(id);
    final now = DateTime.now();
    await _db
        .into(_db.things)
        .insertOnConflictUpdate(
          ThingsCompanion.insert(
            id: id,
            type: doc.type,
            jsonld: doc.toJsonString(),
            name: Value(doc.name),
            url: Value(doc.url),
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  /// One-shot read of the Thing with [id], or null when absent.
  Future<Thing?> thingById(String id) =>
      (_db.select(_db.things)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Live list of all Things, most-recently-updated first (the P15e Browser's
  /// "All" facet).
  Stream<List<Thing>> watchAllThings() => (_db.select(
    _db.things,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  /// Live list of Things of the given schema.org [type] (bare, e.g. `Recipe`),
  /// most-recently-updated first.
  Stream<List<Thing>> watchThingsByType(String type) =>
      (_db.select(_db.things)
            ..where((t) => t.type.equals(type))
            ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
          .watch();

  /// Live search over the promoted `name`/`type` (case-insensitive substring,
  /// P16d), most-recently-updated first. A blank [query] yields all Things.
  Stream<List<Thing>> watchThingsSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return watchAllThings();
    final pattern = '%$q%';
    return (_db.select(_db.things)
          ..where(
            (t) => t.name.lower().like(pattern) | t.type.lower().like(pattern),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  /// Live count of Things per distinct schema.org `@type`, most-populous first
  /// (the P15e Browser's facet chips).
  Stream<List<ThingTypeCount>> watchTypeCounts() {
    final typeCol = _db.things.type;
    final countCol = _db.things.id.count();
    final q = _db.selectOnly(_db.things)
      ..addColumns([typeCol, countCol])
      ..groupBy([typeCol])
      ..orderBy([OrderingTerm.desc(countCol), OrderingTerm.asc(typeCol)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          (type: r.read(typeCol)!, count: r.read(countCol) ?? 0),
      ],
    );
  }

  /// One-shot count of all Things.
  Future<int> countThings() async {
    final c = _db.things.id.count();
    final q = _db.selectOnly(_db.things)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Live count of all Things (for the P14f diagnostic / badges).
  Stream<int> watchThingCount() {
    final c = _db.things.id.count();
    final q = _db.selectOnly(_db.things)..addColumns([c]);
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }

  /// Deletes the Thing with [id] (no-op when absent).
  Future<void> deleteThing(String id) async {
    await (_db.delete(_db.things)..where((t) => t.id.equals(id))).go();
  }

  /// Rebuildable, idempotent backfill of the promoted columns from the canonical
  /// `jsonld` (ADR-0001's re-derivation discipline) — re-runs cheaply and future-
  /// proofs adding promoted columns without a migration. Rewrites only the rows
  /// whose cached `name`/`url` drifted from the JSON-LD (leaving `updatedAt`
  /// untouched — a cache refresh, not a content change) and skips any unparseable
  /// row. Returns the number of rows repaired.
  Future<int> refreshPromotedColumns() async {
    final rows = await _db.select(_db.things).get();
    var repaired = 0;
    for (final row in rows) {
      final ThingDoc doc;
      try {
        doc = ThingDoc.fromJsonString(row.jsonld);
      } on FormatException {
        continue;
      }
      if (doc.name == row.name && doc.url == row.url) continue;
      await (_db.update(_db.things)..where((t) => t.id.equals(row.id))).write(
        ThingsCompanion(name: Value(doc.name), url: Value(doc.url)),
      );
      repaired++;
    }
    return repaired;
  }
}

/// A distinct schema.org `@type` paired with how many Things carry it (P15e).
typedef ThingTypeCount = ({String type, int count});

final thingRepositoryProvider = Provider<ThingRepository>(
  (ref) => ThingRepository(ref.watch(appDatabaseProvider)),
);
