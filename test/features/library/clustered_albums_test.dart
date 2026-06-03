import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/features/library/presentation/clustered_albums_provider.dart';

import '../../support/graph_fakes.dart';

MediaItem _item(String id, {String site = 'youtube', String? title}) =>
    MediaItem(
      id: id,
      title: title ?? 'Clip $id',
      sourceUrl: 'https://y/$id',
      site: site,
      filePath: '/m/$id.mp4',
      type: 'video',
      createdAt: DateTime.utc(2026, 1, id.codeUnitAt(0)),
      storageState: 'private',
      isFavorite: false,
    );

void main() {
  group('clusterLabel', () {
    test('prefers the dominant tag', () {
      expect(
        clusterLabel([_item('a'), _item('b')], dominantTag: 'rock'),
        "Around 'rock'",
      );
    });

    test('falls back to the most common uploader', () {
      expect(
        clusterLabel(
          [_item('a'), _item('b')],
          uploaderById: {'a': 'Veritasium', 'b': 'Veritasium'},
        ),
        'Mostly Veritasium',
      );
    });

    test('falls back to the most common site', () {
      expect(clusterLabel([_item('a'), _item('b')]), 'Mostly youtube');
    });

    test('falls back to the newest title when nothing dominates', () {
      final label = clusterLabel([
        _item('a', site: 'youtube', title: 'Older'),
        _item('b', site: 'vimeo', title: 'Newer'),
      ]);
      expect(label, "Like 'Newer'");
    });
  });

  group('clusteredAlbumsProvider', () {
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

    test('hydrates communities into labeled albums', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      for (final id in ['a', 'b', 'c']) {
        await db
            .into(db.mediaItems)
            .insert(
              MediaItemsCompanion.insert(
                id: id,
                title: 'Clip $id',
                sourceUrl: 'https://y/$id',
                site: 'youtube',
                filePath: '/m/$id',
                type: 'video',
                createdAt: DateTime.utc(2026, 1, id.codeUnitAt(0)),
                storageState: 'private',
              ),
            );
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

      final albums = await c.read(clusteredAlbumsProvider.future);
      expect(albums, hasLength(1));
      expect(albums.single.items.map((m) => m.id).toSet(), {'a', 'b', 'c'});
      expect(albums.single.label, "Around 'rock'");
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
      expect(await c.read(clusteredAlbumsProvider.future), isEmpty);
    });
  });
}
