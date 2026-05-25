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
}
