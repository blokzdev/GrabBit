import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_projection.dart';

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

  MediaItem item(
    String id, {
    String site = 'youtube',
    String type = 'video',
    int? folderId,
    String? contentHash,
    DateTime? createdAt,
  }) => MediaItem(
    id: id,
    title: 'T$id',
    sourceUrl: 'u$id',
    site: site,
    filePath: '/p/$id',
    type: type,
    createdAt: createdAt ?? t0,
    storageState: 'private',
    isFavorite: false,
    folderId: folderId,
    contentHash: contentHash,
  );

  test('projects nodes + edges from the snapshot', () {
    final rels = buildGraphRelations(
      LibrarySnapshot(
        media: [
          item('a', folderId: 3),
          item('b', site: 'tiktok'),
        ],
        metadata: [
          const MediaMetadataData(
            itemId: 'a',
            uploaderId: 'u1',
            uploader: 'Alice',
            playlistId: 'p1',
            playlistTitle: 'PL',
          ),
        ],
        folders: [Folder(id: 3, name: 'F', createdAt: t0, parentId: 1)],
        tags: [const Tag(id: 7, name: 'fun')],
        tagLinks: [(itemId: 'a', tag: 'fun')],
        collections: [Collection(id: 5, name: 'C', createdAt: t0)],
        collectionLinks: [(itemId: 'b', collectionId: 5)],
      ),
    );

    expect(rels['media']!.length, 2);
    expect(rels['media']!.first, [
      'a',
      'Ta',
      'youtube',
      'video',
      1000,
      false,
      null,
      '/p/a',
    ]);
    expect(rels['site']!.map((r) => r.first).toSet(), {'youtube', 'tiktok'});
    expect(
      rels['onPlatform'],
      containsAll([
        ['a', 'youtube'],
        ['b', 'tiktok'],
      ]),
    );
    expect(rels['uploader']!.single, ['u1', 'Alice', null]);
    expect(rels['postedBy']!.single, ['a', 'u1']);
    expect(rels['playlist']!.single, ['p1', 'PL']);
    expect(rels['inPlaylist']!.single, ['a', 'p1']);
    expect(rels['inFolder']!.single, ['a', 3]);
    expect(rels['folder']!.single, [3, 'F', 1]);
    expect(rels['folderParent']!.single, [3, 1]);
    expect(rels['tag']!.single, ['fun']);
    expect(rels['taggedWith']!.single, ['a', 'fun']);
    expect(rels['collection']!.single, [5, 'C']);
    expect(rels['inCollection']!.single, ['b', 5]);
    // No contentHash set → no duplicates; both created at t0 → co-downloaded.
    expect(rels['duplicateOf'], isEmpty);
    expect(
      rels['coDownloadedWith'],
      containsAll([
        ['a', 'b', 0],
        ['b', 'a', 0],
      ]),
    );
  });

  test('duplicateOf links items sharing a non-empty contentHash', () {
    final rels = buildGraphRelations(
      LibrarySnapshot(
        media: [
          item('a', contentHash: 'h1'),
          item('b', contentHash: 'h1'),
          item('c', contentHash: 'h2'), // unique → no duplicate
          item('d'), // null hash → ignored
        ],
      ),
    );
    expect(
      rels['duplicateOf'],
      containsAll([
        ['a', 'b'],
        ['b', 'a'],
      ]),
    );
    expect(rels['duplicateOf']!.length, 2); // only the h1 pair, both directions
  });

  test('coDownloadedWith chains items within the window, not beyond it', () {
    final rels = buildGraphRelations(
      LibrarySnapshot(
        media: [
          item('a', createdAt: t0),
          item('b', createdAt: t0.add(const Duration(minutes: 1))),
          item('c', createdAt: t0.add(const Duration(hours: 1))), // far apart
        ],
      ),
    );
    final pairs = rels['coDownloadedWith']!;
    expect(
      pairs,
      containsAll([
        ['a', 'b', 60],
        ['b', 'a', 60],
      ]),
    );
    // 'c' is an hour after 'b' (> 5 min window) → not chained.
    expect(pairs.any((r) => r.contains('c')), isFalse);
  });

  test('an item without metadata yields no uploader/playlist edges', () {
    final rels = buildGraphRelations(LibrarySnapshot(media: [item('a')]));
    expect(rels['onPlatform']!.single, ['a', 'youtube']);
    expect(rels['postedBy'], isEmpty);
    expect(rels['inPlaylist'], isEmpty);
    expect(rels['inFolder'], isEmpty);
  });

  test('empty library yields every relation empty', () {
    final rels = buildGraphRelations(const LibrarySnapshot());
    for (final entry in rels.entries) {
      expect(entry.value, isEmpty, reason: entry.key);
    }
  });

  test('projects thing nodes + vocabulary and authored edges (P14e)', () {
    final rels = buildGraphRelations(
      LibrarySnapshot(
        things: [
          Thing(
            id: 'v1',
            type: 'VideoObject',
            // an @id-bearing object property → one vocabulary edge
            jsonld:
                '{"@type":"VideoObject","name":"V","isPartOf":{"@id":"pl-1"},'
                '"author":{"@type":"Person","name":"NoId"}}',
            name: 'V',
            url: 'https://e/v1',
            createdAt: t0,
            updatedAt: t0,
          ),
        ],
        thingEdges: [
          ThingEdge(
            subject: 'v1',
            predicate: 'relatedTo',
            object: 'r1',
            provenance: 'user-authored',
            confidence: 0.9,
            note: 'linked',
            createdAt: t0,
          ),
        ],
      ),
    );

    expect(rels['thing']!.single, [
      'v1',
      'VideoObject',
      'V',
      'https://e/v1',
      1000,
      1000,
    ]);
    // Only the @id-bearing `isPartOf` yields an edge; the inline `author` (no
    // @id) does not.
    expect(rels['thingVocabEdge']!.single, ['v1', 'isPartOf', 'pl-1']);
    expect(rels['thingAuthoredEdge']!.single, [
      'v1',
      'relatedTo',
      'r1',
      'user-authored',
      0.9,
      'linked',
    ]);
  });
}
