import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/graph_sync_service.dart';

/// Captures the CozoScript calls a rebuild would issue, without a real engine.
class _FakeGraphStore implements GraphStore {
  _FakeGraphStore({this.available = true});
  bool available;
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
    return const {'rows': <List<Object?>>[]};
  }
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
}
