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

    test('targets the given relation index (P16f thing_embedding)', () {
      expect(
        vectorSearchScript(relation: 'thing_embedding'),
        contains('~thing_embedding:idx'),
      );
      expect(vectorSearchScript(), contains('~embedding:idx'));
    });
  });

  group('itemVectorScript', () {
    test('reads the stored vector for the bound id', () {
      expect(itemVectorScript(), contains(r'*embedding{id: $id, v}'));
    });
  });

  group('relatedNeighborsScript', () {
    test('unions the four shared signals as [other, kind, val] rows', () {
      final script = relatedNeighborsScript();
      expect(script, contains('?[other, kind, val]'));
      expect(script, contains('*postedBy'));
      expect(script, contains('*inPlaylist'));
      expect(script, contains('*taggedWith'));
      expect(script, contains('*coDownloadedWith'));
      expect(script, contains('kind = "uploader"'));
      expect(script, contains('kind = "tag"'));
      expect(script, contains('kind = "codownload"'));
      expect(script, contains(r'other != $id'));
    });
  });

  group('duplicateIdsScript', () {
    test('matches duplicateOf in both directions', () {
      final script = duplicateIdsScript();
      expect(script, contains(r'*duplicateOf{mediaId: $id, otherId: other}'));
      expect(script, contains(r'*duplicateOf{mediaId: other, otherId: $id}'));
    });
  });

  group('coOccurringTagsScript', () {
    test('collects related-item tags and excludes the item\'s own', () {
      final script = coOccurringTagsScript();
      expect(script, contains('related[other] :='));
      expect(script, contains('*postedBy'));
      expect(script, contains('*inPlaylist'));
      expect(script, contains('*coDownloadedWith'));
      expect(script, contains(r'own[t] := *taggedWith{mediaId: $id, tag: t}'));
      expect(
        script,
        contains(
          '?[other, tag] := related[other], '
          '*taggedWith{mediaId: other, tag}, not own[tag]',
        ),
      );
    });
  });

  group('coOccurringTagsForEntityScript', () {
    test('binds the right member relation per entity type', () {
      expect(
        coOccurringTagsForEntityScript('tag'),
        contains(r'member[other] := *taggedWith{mediaId: other, tag: $v}'),
      );
      expect(
        coOccurringTagsForEntityScript('site'),
        contains(r'member[other] := *onPlatform{mediaId: other, site: $v}'),
      );
      expect(
        coOccurringTagsForEntityScript('playlist'),
        contains(r'*inPlaylist{mediaId: other, playlistId: $v}'),
      );
      // Uploader hubs key by name, bridged via the uploader node to uploaderId.
      final uploader = coOccurringTagsForEntityScript('uploader')!;
      expect(uploader, contains(r'*uploader{uploaderId: uid, name: $v}'));
      expect(uploader, contains('*postedBy{mediaId: other, uploaderId: uid}'));
    });

    test('every type emits [other, tag] rows', () {
      for (final t in ['tag', 'site', 'playlist', 'uploader']) {
        expect(
          coOccurringTagsForEntityScript(t),
          contains(
            '?[other, tag] := member[other], '
            '*taggedWith{mediaId: other, tag}',
          ),
        );
      }
    });

    test('returns null for an unknown type', () {
      expect(coOccurringTagsForEntityScript('folder'), isNull);
    });
  });

  group('similarity-clustering reads', () {
    test('allEmbeddingsScript pulls every stored vector', () {
      expect(allEmbeddingsScript(), '?[id, v] := *embedding{id, v}');
    });
    test('allDuplicatePairsScript reads exact-duplicate pairs', () {
      expect(
        allDuplicatePairsScript(),
        contains('*duplicateOf{mediaId: a, otherId: b}'),
      );
    });
  });

  group('neighborhoodScript', () {
    test('unions entity + linked-media relations as [rel, id, label]', () {
      final s = neighborhoodScript();
      expect(s, contains('?[rel, id, label]'));
      for (final r in [
        'postedBy',
        'inPlaylist',
        'onPlatform',
        'taggedWith',
        'duplicateOf',
        'coDownloadedWith',
      ]) {
        expect(s, contains('*$r'));
      }
      expect(s, contains('rel = "uploader"'));
      expect(s, contains('rel = "codownload"'));
      expect(s, contains('*media{id: o, title: label}'));
    });
  });

  group('mediaForEntityScript', () {
    test('selects the right edge per entity type and limits', () {
      expect(
        mediaForEntityScript('uploader'),
        contains(r'*postedBy{mediaId: id, uploaderId: $v}'),
      );
      expect(
        mediaForEntityScript('site'),
        contains(r'*onPlatform{mediaId: id, site: $v}'),
      );
      expect(
        mediaForEntityScript('tag'),
        contains(r'*taggedWith{mediaId: id, tag: $v}'),
      );
      expect(
        mediaForEntityScript('playlist'),
        contains(r'*inPlaylist{mediaId: id, playlistId: $v}'),
      );
      expect(mediaForEntityScript('uploader'), contains(':limit 30'));
      expect(mediaForEntityScript('tag', limit: 5), contains(':limit 5'));
    });

    test('returns null for a non-entity relation', () {
      expect(mediaForEntityScript('duplicate'), isNull);
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

  group('entityMembershipScript', () {
    test('emits [mediaId, kind, key] for uploader/playlist/tag, no site', () {
      final script = entityMembershipScript();
      expect(script, contains('?[mediaId, kind, key]'));
      expect(script, contains('*postedBy{mediaId, uploaderId: key}'));
      expect(script, contains('*inPlaylist{mediaId, playlistId: key}'));
      expect(script, contains('*taggedWith{mediaId, tag: key}'));
      expect(script, contains('kind = "u"'));
      expect(script, contains('kind = "p"'));
      expect(script, contains('kind = "t"'));
      expect(script, isNot(contains('onPlatform'))); // site excluded
    });
  });

  group('coDownloadPairsScript', () {
    test('emits [a, b] co-download pairs', () {
      final script = coDownloadPairsScript();
      expect(script, contains('?[a, b]'));
      expect(script, contains('*coDownloadedWith{mediaId: a, otherId: b}'));
    });
  });
}
