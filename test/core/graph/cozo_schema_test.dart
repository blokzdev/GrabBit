import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/graph/cozo_schema.dart';

void main() {
  group('graphSchema', () {
    test('defines the deterministic node + edge relations', () {
      expect(
        graphSchema.keys,
        containsAll(<String>[
          'media',
          'uploader',
          'site',
          'playlist',
          'tag',
          'collection',
          'folder',
          'postedBy',
          'onPlatform',
          'inPlaylist',
          'taggedWith',
          'inCollection',
          'inFolder',
          'folderParent',
          'duplicateOf',
          'coDownloadedWith',
        ]),
      );
    });

    test('excludes the embedding relation from the deterministic set', () {
      // `embedding` is cached + maintained incrementally (P10b-2b), so it must
      // never be in graphSchema — that's what keeps it out of the `:replace`
      // rebuild loop and the dim-agnostic ensureSchema.
      expect(graphSchema.containsKey('embedding'), isFalse);
      expect(graphEdgeRelations.contains('embedding'), isFalse);
    });

    test('each script is a :create for its own relation', () {
      for (final entry in graphSchema.entries) {
        expect(entry.value, startsWith(':create ${entry.key} '));
      }
    });
  });

  group('missingSchemaScripts', () {
    test('returns every script when nothing exists yet', () {
      expect(missingSchemaScripts(const {}).length, graphSchema.length);
    });

    test('omits relations that already exist (idempotent ensureSchema)', () {
      final scripts = missingSchemaScripts({'media', 'tag'});
      expect(scripts.length, graphSchema.length - 2);
      expect(scripts, isNot(contains(graphSchema['media'])));
      expect(scripts, isNot(contains(graphSchema['tag'])));
    });

    test('returns nothing when all relations already exist', () {
      expect(missingSchemaScripts(graphSchema.keys.toSet()), isEmpty);
    });
  });

  group('embedding scripts (P10b-2b)', () {
    test('create script fixes the dimension + carries the cache key', () {
      final script = embeddingCreateScript(768);
      expect(script, startsWith(':create embedding '));
      expect(script, contains('v: <F32; 768>'));
      expect(script, contains('textHash: String'));
    });

    test('hnsw script names the index with the dim + cosine distance', () {
      final script = embeddingHnswScript(768);
      expect(script, startsWith('::hnsw create embedding:idx '));
      expect(script, contains('dim: 768'));
      expect(script, contains('dtype: F32'));
      expect(script, contains('fields: [v]'));
      expect(script, contains('distance: Cosine'));
    });

    test('put/remove scripts bind \$rows in column order', () {
      expect(embeddingPutScript(), contains(r'?[id, v, textHash] <- $rows'));
      expect(
        embeddingPutScript(),
        contains(':put embedding { id => v, textHash }'),
      );
      expect(embeddingRemoveScript(), contains(r'?[id] <- $rows'));
      expect(embeddingRemoveScript(), contains(':rm embedding { id }'));
    });

    test('pairs + count scripts read the cache', () {
      expect(embeddingPairsScript(), contains('*embedding{id, textHash}'));
      expect(embeddingCountScript(), contains('count(id)'));
    });

    test('meta + drop scripts track the model/dim and reset the index', () {
      expect(
        embeddingMetaCreateScript(),
        startsWith(':create embedding_meta '),
      );
      expect(
        embeddingMetaReadScript(),
        contains('*embedding_meta{key, value}'),
      );
      expect(embeddingMetaPutScript(), contains(':put embedding_meta'));
      expect(embeddingDropScript(), '::remove embedding');
    });
  });
}
