import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/near_duplicate_clustering.dart';

({String id, List<double> v}) _e(String id, List<double> v) => (id: id, v: v);

void main() {
  group('cosineDistance', () {
    test('identical vectors are distance 0', () {
      expect(cosineDistance([1, 2, 3], [1, 2, 3]), closeTo(0, 1e-9));
    });
    test('orthogonal vectors are distance 1', () {
      expect(cosineDistance([1, 0], [0, 1]), closeTo(1, 1e-9));
    });
    test('a zero vector is maximally distant, not NaN', () {
      expect(cosineDistance([0, 0], [1, 1]), 1.0);
    });
  });

  group('clusterBySimilarity', () {
    test('groups near vectors and drops sub-min-size groups', () {
      // a/b/c cluster around [1,0]; d/e are a near pair around [0,1] (size 2).
      final clusters = clusterBySimilarity([
        _e('a', [1, 0]),
        _e('b', [1, 0.02]),
        _e('c', [1, 0.04]),
        _e('d', [0, 1]),
        _e('e', [0, 1]),
      ]);
      expect(clusters, hasLength(1));
      expect(clusters.single.toSet(), {'a', 'b', 'c'});
    });

    test('orders clusters largest-first', () {
      final clusters = clusterBySimilarity([
        _e('a', [1, 0]),
        _e('b', [1, 0.02]),
        _e('c', [1, 0.04]),
        _e('d', [1, 0.06]),
        _e('e', [0, 1]),
        _e('f', [0.02, 1]),
        _e('g', [0.04, 1]),
      ]);
      expect(clusters.map((c) => c.length), [4, 3]);
    });

    test('excludePairs can break a component below min size', () {
      // a-b-c are mutually near; removing a|c and b|c isolates c, leaving {a,b}.
      final clusters = clusterBySimilarity(
        [
          _e('a', [1, 0]),
          _e('b', [1, 0.02]),
          _e('c', [1, 0.04]),
        ],
        excludePairs: {pairKey('a', 'c'), pairKey('b', 'c')},
      );
      expect(clusters, isEmpty); // {a,b}=2 and {c}=1 both below minSize 3
    });

    test('discards over-large blob components', () {
      final clusters = clusterBySimilarity([
        _e('a', [1, 0]),
        _e('b', [1, 0.01]),
        _e('c', [1, 0.02]),
        _e('d', [1, 0.03]),
      ], maxSize: 3);
      expect(clusters, isEmpty);
    });
  });
}
