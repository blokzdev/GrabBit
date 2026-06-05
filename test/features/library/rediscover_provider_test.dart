import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/features/library/presentation/rediscover_provider.dart';

import '../../support/graph_fakes.dart';

void main() {
  // A triangle a–b–c (all share one tag) so all three are equally central.
  Map<String, Object?> respond(String script) {
    if (script.contains('coDownloadedWith')) {
      return const {
        'headers': ['a', 'b'],
        'rows': <List<Object?>>[],
      };
    }
    return const {
      'headers': ['mediaId', 'kind', 'key'],
      'rows': [
        ['a', 't', 'rock'],
        ['b', 't', 'rock'],
        ['c', 't', 'rock'],
      ],
    };
  }

  Future<void> seed(AppDatabase db, String id, {DateTime? lastAccessed}) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: 'Clip $id',
          sourceUrl: 'https://y/$id',
          site: 'youtube',
          filePath: '/m/$id',
          type: 'video',
          createdAt: DateTime.utc(2025), // old -> stale by default
          storageState: 'private',
          lastAccessedAt: Value(lastAccessed),
        ),
      );

  test('surfaces central-but-stale items, excluding freshly opened', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await seed(db, 'a'); // never opened, old -> stale
    await seed(db, 'b', lastAccessed: DateTime.now()); // fresh -> excluded
    await seed(db, 'c'); // stale

    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        graphQueryServiceProvider.overrideWithValue(
          GraphQueryService(FakeGraphStore(responder: respond)),
        ),
      ],
    );
    addTearDown(c.dispose);

    final items = await c.read(rediscoverProvider.future);
    final ids = items.map((m) => m.id).toList();
    expect(ids, containsAll(['a', 'c']));
    expect(ids, isNot(contains('b')));
  });

  test('empty when the graph store is unavailable', () async {
    final c = ProviderContainer(
      overrides: [
        graphQueryServiceProvider.overrideWithValue(
          GraphQueryService(FakeGraphStore(available: false)),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(rediscoverProvider.future), isEmpty);
  });
}
