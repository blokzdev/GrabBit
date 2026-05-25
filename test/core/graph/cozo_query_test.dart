import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/cozo_query.dart';

void main() {
  group('vectorSearchScript', () {
    test('binds the query vector, k and ef and orders by distance', () {
      final script = vectorSearchScript();
      expect(script, contains('~embedding:idx'));
      expect(script, contains(r'query: vec($q)'));
      expect(script, contains(r'k: $k'));
      expect(script, contains(r'ef: $ef'));
      expect(script, contains('bind_distance: dist'));
      expect(script, contains(':order dist'));
      expect(script, contains(r':limit $k'));
    });
  });

  group('decodeRows', () {
    test('maps header/row tuples into column-keyed maps', () {
      final rows = decodeRows({
        'headers': ['id', 'dist'],
        'rows': [
          ['a', 0.1],
          ['b', 0.2],
        ],
      });
      expect(rows, [
        {'id': 'a', 'dist': 0.1},
        {'id': 'b', 'dist': 0.2},
      ]);
    });

    test('returns empty for missing or empty headers/rows', () {
      expect(decodeRows(const {}), isEmpty);
      expect(decodeRows(const {'headers': [], 'rows': []}), isEmpty);
      expect(
        decodeRows(const {
          'headers': ['id'],
          'rows': [],
        }),
        isEmpty,
      );
    });

    test('tolerates a row shorter than the header list', () {
      final rows = decodeRows({
        'headers': ['id', 'dist'],
        'rows': [
          ['a'],
        ],
      });
      expect(rows, [
        {'id': 'a'},
      ]);
    });
  });
}
