import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_engine.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/graph_sync_service.dart';

/// Captures the CozoScript calls a rebuild would issue, without a real engine.
/// [responder] lets a test supply canned `{headers, rows}` for read scripts
/// (`::relations`, the embedding cache) — default is an empty result.
class _FakeGraphStore implements GraphStore {
  _FakeGraphStore({this.available = true, this.responder});
  bool available;
  final Map<String, Object?> Function(String script)? responder;
  final List<({String script, Map<String, Object?> params})> calls = [];

  @override
  bool get isAvailable => available;
  @override
  Future<bool> open() async => available;
  @override
  Future<void> ensureSchema() async {}
  @override
  Future<void> close() async {}
  @override
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((script: script, params: params));
    return responder?.call(script) ?? const {'rows': <List<Object?>>[]};
  }
}

/// Embedder that's always ready and returns a fixed-length zero vector.
class _FakeInferenceEngine implements InferenceEngine {
  int embedCalls = 0;

  @override
  EmbedderModel get model => geckoEmbedder;
  @override
  bool get isAvailable => true;
  @override
  int get dimension => geckoEmbedder.dimension;
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<void> downloadModel({
    void Function(double progress)? onProgress,
  }) async {}
  @override
  Future<List<double>> embed(String text) async {
    embedCalls++;
    return List<double>.filled(dimension, 0);
  }

  @override
  Future<void> close() async {}
}

void main() {
  AppDatabase newDb() => AppDatabase(NativeDatabase.memory());

  Future<void> seedItem(AppDatabase db, String id, {String site = 'youtube'}) =>
      db
          .into(db.mediaItems)
          .insert(
            MediaItemsCompanion.insert(
              id: id,
              title: 'T',
              sourceUrl: 'u',
              site: site,
              filePath: '/p/$id',
              type: 'video',
              createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
              storageState: 'private',
            ),
          );

  test('rebuild :replaces each relation with the projected rows', () async {
    final db = newDb();
    addTearDown(db.close);
    await seedItem(db, 'a');
    final fake = _FakeGraphStore();

    final stats = await GraphSyncService(fake, db).rebuild();

    expect(stats.available, isTrue);
    final media = fake.calls.firstWhere(
      (c) => c.script.contains(':replace media'),
    );
    expect((media.params['rows']! as List).length, 1);
    expect(((media.params['rows']! as List).first as List).first, 'a');
    final onPlatform = fake.calls.firstWhere(
      (c) => c.script.contains(':replace onPlatform'),
    );
    expect((onPlatform.params['rows']! as List).single, ['a', 'youtube']);
  });

  test('syncIfStale rebuilds + stamps on mismatch, skips on match', () async {
    final db = newDb();
    addTearDown(db.close);
    final fake = _FakeGraphStore();
    final svc = GraphSyncService(fake, db);

    var stamped = '';
    await svc.syncIfStale(
      storedVersion: 'stale',
      stamp: (v) async => stamped = v,
    );
    expect(stamped, svc.fingerprint);
    expect(fake.calls, isNotEmpty);

    fake.calls.clear();
    stamped = '';
    await svc.syncIfStale(
      storedVersion: svc.fingerprint,
      stamp: (v) async => stamped = v,
    );
    expect(fake.calls, isEmpty);
    expect(stamped, '');
  });

  test('no-op when the store is unavailable', () async {
    final db = newDb();
    addTearDown(db.close);
    await seedItem(db, 'a');
    final fake = _FakeGraphStore(available: false);

    final stats = await GraphSyncService(fake, db).rebuild();

    expect(stats.available, isFalse);
    expect(fake.calls, isEmpty);
  });

  test('a library mutation triggers a debounced rebuild', () async {
    final db = newDb();
    addTearDown(db.close);
    final fake = _FakeGraphStore();
    final svc = GraphSyncService(
      fake,
      db,
      debounce: const Duration(milliseconds: 20),
    );
    svc.start();
    addTearDown(svc.dispose);

    await seedItem(db, 'a');
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(fake.calls.any((c) => c.script.contains(':replace media')), isTrue);
  });

  test('rebuild never mutates the embedding relation', () async {
    final db = newDb();
    addTearDown(db.close);
    await seedItem(db, 'a');
    final fake = _FakeGraphStore();

    await GraphSyncService(fake, db).rebuild();

    // Reading the count for stats is fine; creating/replacing/putting is not —
    // the cached vector index is owned by backfillEmbeddings, not the rebuild.
    final mutates = fake.calls.any(
      (c) =>
          c.script.contains(':replace embedding') ||
          c.script.contains(':create embedding') ||
          c.script.contains(':put embedding') ||
          c.script.contains(':rm embedding'),
    );
    expect(mutates, isFalse);
  });

  group('backfillEmbeddings', () {
    test('no-op (no scripts) when the embedder is unavailable', () async {
      final db = newDb();
      addTearDown(db.close);
      await seedItem(db, 'a');
      final fake = _FakeGraphStore();

      // Default engine is the unavailable stub.
      final stats = await GraphSyncService(fake, db).backfillEmbeddings();

      expect(stats.available, isFalse);
      expect(fake.calls, isEmpty);
    });

    test('creates the schema once and puts only the changed items', () async {
      final db = newDb();
      addTearDown(db.close);
      await seedItem(db, 'a');
      await seedItem(db, 'b');
      final engine = _FakeInferenceEngine();
      final fake = _FakeGraphStore(); // ::relations + pairs both empty

      final stats = await GraphSyncService(
        fake,
        db,
        engine: engine,
      ).backfillEmbeddings();

      // Both items embedded; schema created (relation has no rows yet).
      expect(engine.embedCalls, 2);
      expect(stats.embedded, 2);
      expect(
        fake.calls.any((c) => c.script.contains(':create embedding')),
        isTrue,
      );
      expect(
        fake.calls.any((c) => c.script.contains('::hnsw create embedding:idx')),
        isTrue,
      );
      final put = fake.calls.firstWhere(
        (c) => c.script.contains(':put embedding'),
      );
      expect((put.params['rows']! as List).length, 2);
    });

    test('skips create when the relation already exists', () async {
      final db = newDb();
      addTearDown(db.close);
      await seedItem(db, 'a');
      final fake = _FakeGraphStore(
        responder: (script) {
          if (script == '::relations') {
            return {
              'headers': ['name'],
              'rows': [
                ['media'],
                ['embedding'],
              ],
            };
          }
          return const {'rows': <List<Object?>>[]};
        },
      );

      await GraphSyncService(
        fake,
        db,
        engine: _FakeInferenceEngine(),
      ).backfillEmbeddings();

      expect(
        fake.calls.any((c) => c.script.contains(':create embedding')),
        isFalse,
      );
    });

    test('prunes embeddings for items no longer in the library', () async {
      final db = newDb();
      addTearDown(db.close);
      await seedItem(db, 'a');
      final fake = _FakeGraphStore(
        responder: (script) {
          if (script.contains('*embedding{id, textHash}')) {
            // 'a' (current) + 'gone' (deleted) — but textHash differs for 'a'
            // so it re-embeds, and 'gone' is pruned.
            return {
              'rows': [
                ['a', 'stale'],
                ['gone', 'whatever'],
              ],
            };
          }
          return const {'rows': <List<Object?>>[]};
        },
      );

      final stats = await GraphSyncService(
        fake,
        db,
        engine: _FakeInferenceEngine(),
      ).backfillEmbeddings();

      expect(stats.pruned, 1);
      final rm = fake.calls.firstWhere(
        (c) => c.script.contains(':rm embedding'),
      );
      expect((rm.params['rows']! as List).single, ['gone']);
    });
  });
}
