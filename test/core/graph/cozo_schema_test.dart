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

    test('defers the HNSW embedding relation to P10b', () {
      expect(graphSchema.containsKey('embedding'), isFalse);
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
}
