import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/embedding_doc.dart';
import 'package:grabbit/core/graph/graph_projection.dart';

void main() {
  final t0 = DateTime.fromMillisecondsSinceEpoch(1000);

  MediaItem item(String id, {String title = 'Title'}) => MediaItem(
    id: id,
    title: title,
    sourceUrl: 'u$id',
    site: 'youtube',
    filePath: '/p/$id',
    type: 'video',
    createdAt: t0,
    storageState: 'private',
    isFavorite: false,
  );

  group('buildEmbeddingDocs', () {
    test('blends title, uploader, playlist, tags and description', () {
      final docs = buildEmbeddingDocs(
        LibrarySnapshot(
          media: [item('a', title: 'Cooking pasta')],
          metadata: [
            const MediaMetadataData(
              itemId: 'a',
              uploader: 'Chef',
              playlistTitle: 'Italian',
              description: 'How to cook pasta well',
            ),
          ],
          tags: [const Tag(id: 1, name: 'food')],
          tagLinks: [(itemId: 'a', tag: 'food')],
        ),
        modelId: 'm1',
      );
      expect(docs.single.id, 'a');
      expect(docs.single.text, contains('Cooking pasta'));
      expect(docs.single.text, contains('Chef'));
      expect(docs.single.text, contains('Italian'));
      expect(docs.single.text, contains('food'));
      expect(docs.single.text, contains('How to cook pasta well'));
    });

    test('skips an item whose composed text is empty', () {
      final docs = buildEmbeddingDocs(
        LibrarySnapshot(media: [item('a', title: '   ')]),
        modelId: 'm1',
      );
      expect(docs, isEmpty);
    });

    test('textHash is stable for the same text + model', () {
      final snap = LibrarySnapshot(media: [item('a', title: 'Stable')]);
      final h1 = buildEmbeddingDocs(snap, modelId: 'm1').single.textHash;
      final h2 = buildEmbeddingDocs(snap, modelId: 'm1').single.textHash;
      expect(h1, h2);
    });

    test('textHash changes when the content changes', () {
      final a = buildEmbeddingDocs(
        LibrarySnapshot(media: [item('a', title: 'One')]),
        modelId: 'm1',
      ).single.textHash;
      final b = buildEmbeddingDocs(
        LibrarySnapshot(media: [item('a', title: 'Two')]),
        modelId: 'm1',
      ).single.textHash;
      expect(a, isNot(b));
    });

    test('textHash changes when the model changes (forces re-embed)', () {
      final snap = LibrarySnapshot(media: [item('a', title: 'Same')]);
      final m1 = buildEmbeddingDocs(snap, modelId: 'm1').single.textHash;
      final m2 = buildEmbeddingDocs(snap, modelId: 'm2').single.textHash;
      expect(m1, isNot(m2));
    });
  });

  group('diffEmbeddings', () {
    EmbeddingDoc doc(String id, String hash) =>
        EmbeddingDoc(id: id, text: 't', textHash: hash);

    test('embeds new + changed ids, leaves unchanged alone', () {
      final diff = diffEmbeddings(
        current: {'a': 'h1', 'b': 'h2'},
        desired: [doc('a', 'h1'), doc('b', 'CHANGED'), doc('c', 'h3')],
      );
      expect(diff.toEmbed.map((d) => d.id), unorderedEquals(['b', 'c']));
      expect(diff.toRemove, isEmpty);
    });

    test('prunes stored ids no longer desired', () {
      final diff = diffEmbeddings(
        current: {'a': 'h1', 'gone': 'h9'},
        desired: [doc('a', 'h1')],
      );
      expect(diff.toEmbed, isEmpty);
      expect(diff.toRemove, ['gone']);
    });

    test('empty desired prunes everything', () {
      final diff = diffEmbeddings(
        current: {'a': 'h1', 'b': 'h2'},
        desired: const [],
      );
      expect(diff.toEmbed, isEmpty);
      expect(diff.toRemove, unorderedEquals(['a', 'b']));
    });
  });
}
