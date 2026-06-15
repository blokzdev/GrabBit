import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';

/// The canonical store API over the `thing_suggestions` table (P15c) — the
/// **pending-extraction** store ("suggest-don't-assert", ADR-0004). Mirrors
/// `ThingEdgeRepository`: a thin, store-only Drift wrapper. A suggestion lives
/// here until the user confirms it (P15d upserts it into `things` + links it) or
/// rejects it (delete). Drift stays canonical.
class ThingSuggestionRepository {
  ThingSuggestionRepository(this._db);

  final AppDatabase _db;

  /// Replaces the pending suggestions for [itemId] with [suggestions] in one
  /// transaction (delete-then-insert) — re-running extraction on the same item
  /// supersedes its prior suggestions rather than accumulating them.
  Future<void> replaceForItem(
    String itemId,
    List<ThingSuggestionsCompanion> suggestions,
  ) async {
    await _db.transaction(() async {
      await deleteForItem(itemId);
      for (final s in suggestions) {
        await _db.into(_db.thingSuggestions).insert(s);
      }
    });
  }

  /// Inserts a single pending [suggestion].
  Future<void> insert(ThingSuggestionsCompanion suggestion) =>
      _db.into(_db.thingSuggestions).insert(suggestion);

  /// One-shot read of [id], or null when absent.
  Future<ThingSuggestion?> byId(String id) => (_db.select(
    _db.thingSuggestions,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Pending suggestions for [itemId], newest first.
  Future<List<ThingSuggestion>> pendingForItem(String itemId) =>
      (_db.select(_db.thingSuggestions)
            ..where((t) => t.sourceItemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .get();

  /// Live pending suggestions for [itemId], newest first.
  Stream<List<ThingSuggestion>> watchForItem(String itemId) =>
      (_db.select(_db.thingSuggestions)
            ..where((t) => t.sourceItemId.equals(itemId))
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  /// Deletes the suggestion [id] (no-op if absent) — the reject / post-accept path.
  Future<void> delete(String id) async {
    await (_db.delete(
      _db.thingSuggestions,
    )..where((t) => t.id.equals(id))).go();
  }

  /// Deletes all pending suggestions for [itemId] (no-op if none).
  Future<void> deleteForItem(String itemId) async {
    await (_db.delete(
      _db.thingSuggestions,
    )..where((t) => t.sourceItemId.equals(itemId))).go();
  }

  /// One-shot count of all pending suggestions.
  Future<int> countPending() async {
    final c = _db.thingSuggestions.id.count();
    final q = _db.selectOnly(_db.thingSuggestions)..addColumns([c]);
    return (await q.getSingle()).read(c) ?? 0;
  }

  /// Live count of all pending suggestions.
  Stream<int> watchPendingCount() {
    final c = _db.thingSuggestions.id.count();
    final q = _db.selectOnly(_db.thingSuggestions)..addColumns([c]);
    return q.watchSingle().map((r) => r.read(c) ?? 0);
  }
}

final thingSuggestionRepositoryProvider = Provider<ThingSuggestionRepository>(
  (ref) => ThingSuggestionRepository(ref.watch(appDatabaseProvider)),
);
