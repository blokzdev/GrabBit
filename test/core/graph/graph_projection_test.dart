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
  }) => MediaItem(
    id: id,
    title: 'T$id',
    sourceUrl: 'u$id',
    site: site,
    filePath: '/p/$id',
    type: type,
    createdAt: t0,
    storageState: 'private',
    isFavorite: false,
    folderId: folderId,
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
    // Deferred to P10c.
    expect(rels['duplicateOf'], isEmpty);
    expect(rels['coDownloadedWith'], isEmpty);
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
}
