import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';

import '../../support/graph_fakes.dart';

void main() {
  group('GraphQueryService.vectorSearch', () {
    test('returns ordered hits decoded from the result', () async {
      final store = FakeGraphStore(
        responder: (_) => {
          'headers': ['id', 'dist'],
          'rows': [
            ['a', 0.05],
            ['b', 0.42],
          ],
        },
      );
      final hits = await GraphQueryService(
        store,
      ).vectorSearch(List<double>.filled(768, 0), k: 10);

      expect(hits.map((h) => h.id), ['a', 'b']);
      expect(hits.first.distance, 0.05);
      // The query vector, k and ef are passed through as params.
      expect(store.calls.single.params['k'], 10);
      expect(store.calls.single.params, contains('q'));
      expect(store.calls.single.params, contains('ef'));
    });

    test(
      'returns empty when the store is unavailable (no query run)',
      () async {
        final store = FakeGraphStore(available: false);
        final hits = await GraphQueryService(
          store,
        ).vectorSearch(List<double>.filled(768, 0));

        expect(hits, isEmpty);
        expect(store.calls, isEmpty);
      },
    );

    test('returns empty when the index yields no rows', () async {
      final store = FakeGraphStore(
        responder: (_) => const {'headers': [], 'rows': []},
      );
      final hits = await GraphQueryService(
        store,
      ).vectorSearch(List<double>.filled(768, 0));

      expect(hits, isEmpty);
    });
  });

  group('GraphQueryService.relatedTo', () {
    Map<String, Object?> route(String script) {
      if (script.contains('~embedding')) {
        return {
          'headers': ['id', 'dist'],
          'rows': [
            ['b', 0.1],
            ['c', 0.4],
            ['d', 0.05], // closest, but a duplicate → must be excluded
          ],
        };
      }
      if (script.contains('*embedding{')) {
        return {
          'headers': ['v'],
          'rows': [
            [List<double>.filled(768, 0)],
          ],
        };
      }
      if (script.contains('postedBy')) {
        return {
          'headers': ['other', 'kind', 'val'],
          'rows': [
            ['b', 'uploader', 'u1'],
            ['e', 'tag', 't1'],
          ],
        };
      }
      if (script.contains('duplicateOf')) {
        return {
          'headers': ['other'],
          'rows': [
            ['d'],
          ],
        };
      }
      return const {'rows': <List<Object?>>[]};
    }

    test('blends vector + graph signals and excludes duplicates', () async {
      final related = await GraphQueryService(
        FakeGraphStore(responder: route),
      ).relatedTo('a');

      // b: vector(0.9) + uploader(0.5); c: vector(0.6); e: tag(0.15); d excluded.
      expect(related, ['b', 'c', 'e']);
    });

    test('works graph-only when the item has no stored embedding', () async {
      final store = FakeGraphStore(
        responder: (script) {
          if (script.contains('*embedding{')) {
            return const {'headers': [], 'rows': []}; // not embedded
          }
          if (script.contains('postedBy')) {
            return {
              'headers': ['other', 'kind', 'val'],
              'rows': [
                ['x', 'playlist', 'p1'],
              ],
            };
          }
          return const {'rows': <List<Object?>>[]};
        },
      );

      final related = await GraphQueryService(store).relatedTo('a');

      expect(related, ['x']);
      // No vector search is attempted without a source vector.
      expect(store.calls.any((c) => c.script.contains('~embedding')), isFalse);
    });

    test('returns empty when the store is unavailable', () async {
      final store = FakeGraphStore(available: false);
      expect(await GraphQueryService(store).relatedTo('a'), isEmpty);
      expect(store.calls, isEmpty);
    });
  });

  group('GraphQueryService.coOccurringTags', () {
    test('ranks co-occurring tags by distinct supporting items', () async {
      final store = FakeGraphStore(
        responder: (_) => {
          'headers': ['other', 'tag'],
          'rows': [
            ['b', 'music'],
            ['c', 'music'],
            ['b', 'live'],
          ],
        },
      );
      final tags = await GraphQueryService(store).coOccurringTags('a');
      expect(tags.map((t) => t.tag), ['music', 'live']);
      expect(tags.first.count, 2);
      expect(store.calls.single.params['id'], 'a');
    });

    test('returns empty when the store is unavailable', () async {
      final store = FakeGraphStore(available: false);
      expect(await GraphQueryService(store).coOccurringTags('a'), isEmpty);
      expect(store.calls, isEmpty);
    });
  });

  group('GraphQueryService.relatedTags', () {
    test('passes the entity value and ranks the result', () async {
      final store = FakeGraphStore(
        responder: (_) => {
          'headers': ['other', 'tag'],
          'rows': [
            ['x', 'remix'],
            ['y', 'remix'],
            ['x', 'demo'],
          ],
        },
      );
      final tags = await GraphQueryService(
        store,
      ).relatedTags('uploader', 'Rick');
      expect(tags.map((t) => t.tag), ['remix', 'demo']);
      expect(store.calls.single.params['v'], 'Rick');
    });

    test('a tag hub excludes its own tag', () async {
      final store = FakeGraphStore(
        responder: (_) => {
          'headers': ['other', 'tag'],
          'rows': [
            ['x', 'funny'], // the hub's own tag
            ['x', 'cats'],
          ],
        },
      );
      final tags = await GraphQueryService(store).relatedTags('tag', 'funny');
      expect(tags.map((t) => t.tag), ['cats']);
    });

    test('returns empty for an unknown entity type (no query run)', () async {
      final store = FakeGraphStore();
      expect(
        await GraphQueryService(store).relatedTags('folder', '1'),
        isEmpty,
      );
      expect(store.calls, isEmpty);
    });
  });

  group('GraphQueryService.similarityClusters', () {
    Map<String, Object?> route(String script) {
      if (script.contains('*embedding{id, v}')) {
        return {
          'headers': ['id', 'v'],
          'rows': [
            [
              'a',
              <double>[1, 0],
            ],
            [
              'b',
              <double>[1, 0.02],
            ],
            [
              'c',
              <double>[1, 0.04],
            ],
            [
              'z',
              <double>[0, 1],
            ], // far away → not clustered
          ],
        };
      }
      if (script.contains('duplicateOf')) {
        return const {'headers': <String>[], 'rows': <List<Object?>>[]};
      }
      return const {'rows': <List<Object?>>[]};
    }

    test('clusters near vectors, ignoring distant ones', () async {
      final clusters = await GraphQueryService(
        FakeGraphStore(responder: route),
      ).similarityClusters();
      expect(clusters, hasLength(1));
      expect(clusters.single.toSet(), {'a', 'b', 'c'});
    });

    test('returns empty when the store is unavailable', () async {
      final store = FakeGraphStore(available: false);
      expect(await GraphQueryService(store).similarityClusters(), isEmpty);
      expect(store.calls, isEmpty);
    });
  });

  group('GraphQueryService.neighborhood', () {
    test('decodes [rel, id, label] rows into GraphNeighbors', () async {
      final store = FakeGraphStore(
        responder: (_) => {
          'headers': ['rel', 'id', 'label'],
          'rows': [
            ['uploader', 'u1', 'Rick'],
            ['tag', 't1', 'funny'],
          ],
        },
      );
      final n = await GraphQueryService(store).neighborhood('a');
      expect(n.map((e) => e.relation), ['uploader', 'tag']);
      expect(n.first.id, 'u1');
      expect(n.first.label, 'Rick');
      expect(store.calls.single.params['id'], 'a');
    });

    test('returns empty when the store is unavailable', () async {
      final store = FakeGraphStore(available: false);
      expect(await GraphQueryService(store).neighborhood('a'), isEmpty);
      expect(store.calls, isEmpty);
    });
  });
}
