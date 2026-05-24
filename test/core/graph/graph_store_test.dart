import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/android_cozo_graph_store.dart';
import 'package:grabbit/core/graph/graph_error.dart';
import 'package:grabbit/core/graph/graph_store.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/graph/unavailable_graph_store.dart';

/// Deterministic fake for testing GraphStore consumers without the native lib
/// (mirrors `_FakeEngine` in the downloader tests).
class _FakeGraphStore implements GraphStore {
  bool _open = false;
  final List<String> scripts = [];

  @override
  bool get isAvailable => _open;

  @override
  Future<bool> open() async {
    _open = true;
    return true;
  }

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<Map<String, Object?>> runScript(
    String script, [
    Map<String, Object?> params = const {},
  ]) async {
    scripts.add(script);
    return const {'headers': <String>[], 'rows': <List<Object?>>[]};
  }

  @override
  Future<void> close() async => _open = false;
}

void main() {
  group('graphRelationNames', () {
    test('extracts the name column from a ::relations result', () {
      final res = {
        'headers': ['name', 'arity'],
        'rows': [
          ['media', 1],
          ['tag', 1],
        ],
      };
      expect(graphRelationNames(res), {'media', 'tag'});
    });

    test('is empty when there is no name column or rows', () {
      expect(
        graphRelationNames({
          'headers': ['x'],
          'rows': [<Object?>[]],
        }),
        isEmpty,
      );
      expect(graphRelationNames(const {}), isEmpty);
    });
  });

  group('UnavailableGraphStore', () {
    test('is never available and degrades without crashing', () async {
      const store = UnavailableGraphStore();
      expect(store.isAvailable, isFalse);
      expect(await store.open(), isFalse);
      await store.close(); // no-op
      expect(
        () => store.runScript('?[x] <- [[1]]'),
        throwsA(
          isA<GraphException>().having(
            (e) => e.code,
            'code',
            GraphErrorCode.unavailable,
          ),
        ),
      );
      expect(store.ensureSchema, throwsA(isA<GraphException>()));
    });
  });

  group('graphStoreProvider', () {
    test('falls back to UnavailableGraphStore off Android (CI host)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(graphStoreProvider), isA<UnavailableGraphStore>());
    });

    test('can be overridden with a fake for consumer tests', () async {
      final fake = _FakeGraphStore();
      final container = ProviderContainer(
        overrides: [graphStoreProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      final store = container.read(graphStoreProvider);
      expect(store, same(fake));
      expect(await store.open(), isTrue);
      expect(store.isAvailable, isTrue);
    });
  });
}
