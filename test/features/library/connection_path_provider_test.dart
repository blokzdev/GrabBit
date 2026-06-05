import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/features/library/presentation/connection_path_provider.dart';

import '../../support/graph_fakes.dart';

void main() {
  // a–b–c chained: a&b share a channel, b&c share a tag.
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
        ['a', 'u', 'chan1'],
        ['b', 'u', 'chan1'],
        ['b', 't', 'blender'],
        ['c', 't', 'blender'],
      ],
    };
  }

  Future<void> seed(AppDatabase db, String id) => db
      .into(db.mediaItems)
      .insert(
        MediaItemsCompanion.insert(
          id: id,
          title: 'Clip $id',
          sourceUrl: 'https://y/$id',
          site: 'youtube',
          filePath: '/m/$id',
          type: 'video',
          createdAt: DateTime.utc(2026),
          storageState: 'private',
        ),
      );

  test('hydrates the connection chain in order', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final id in ['a', 'b', 'c']) {
      await seed(db, id);
    }
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        graphQueryServiceProvider.overrideWithValue(
          GraphQueryService(FakeGraphStore(responder: respond)),
        ),
      ],
    );
    addTearDown(c.dispose);

    final view = await c.read(connectionPathProvider(('a', 'c')).future);
    expect(view, isNotNull);
    expect(view!.items.map((m) => m.id), ['a', 'b', 'c']);
    expect(view.connectors, ['same channel', "shared tag 'blender'"]);
  });

  test('null when a path node is missing from the library', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    // 'b' (the bridge) is never seeded → the chain can't be hydrated.
    await seed(db, 'a');
    await seed(db, 'c');
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        graphQueryServiceProvider.overrideWithValue(
          GraphQueryService(FakeGraphStore(responder: respond)),
        ),
      ],
    );
    addTearDown(c.dispose);

    expect(await c.read(connectionPathProvider(('a', 'c')).future), isNull);
  });

  test('null when the graph store is unavailable', () async {
    final c = ProviderContainer(
      overrides: [
        graphQueryServiceProvider.overrideWithValue(
          GraphQueryService(FakeGraphStore(available: false)),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(connectionPathProvider(('a', 'b')).future), isNull);
  });
}
