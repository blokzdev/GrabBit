import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/playlist_parser.dart';

void main() {
  group('parsePlaylistJson', () {
    test('parses a flat playlist into entries', () {
      const json = '''
      {
        "_type": "playlist",
        "title": "My Playlist",
        "entries": [
          {"_type": "url", "ie_key": "Youtube", "id": "aaa", "url": "https://y/aaa", "title": "First"},
          {"_type": "url", "ie_key": "Youtube", "id": "bbb", "url": "https://y/bbb", "title": "Second"}
        ]
      }''';
      final result = parsePlaylistJson(json);
      expect(result.isPlaylist, isTrue);
      expect(result.title, 'My Playlist');
      expect(result.entries.map((e) => e.url), [
        'https://y/aaa',
        'https://y/bbb',
      ]);
      expect(result.entries.first.title, 'First');
    });

    test('collapses a single video to one entry', () {
      const json = '''
      {
        "_type": "video",
        "id": "vid1",
        "title": "Just one",
        "webpage_url": "https://y/vid1",
        "duration": 100
      }''';
      final result = parsePlaylistJson(json);
      expect(result.isPlaylist, isFalse);
      expect(result.entries.single.url, 'https://y/vid1');
      expect(result.entries.single.durationSec, 100);
    });

    test('flags image entries in a mixed carousel', () {
      const json = '''
      {
        "_type": "playlist",
        "title": "Carousel",
        "entries": [
          {"id": "p1", "url": "https://ig/p1", "title": "Photo", "ext": "jpg", "vcodec": "none", "acodec": "none"},
          {"id": "v1", "url": "https://ig/v1", "title": "Clip", "ext": "mp4", "vcodec": "h264", "duration": 12}
        ]
      }''';
      final result = parsePlaylistJson(json);
      expect(result.entries[0].isImage, isTrue);
      expect(result.entries[1].isImage, isFalse);
    });

    test('throws FormatException on malformed output', () {
      expect(() => parsePlaylistJson('not json'), throwsFormatException);
      expect(() => parsePlaylistJson('[]'), throwsFormatException);
    });

    test('skips entries without a usable url', () {
      const json = '''
      {"_type": "playlist", "entries": [{"title": "no url"}, {"url": "https://y/ok", "title": "ok"}]}''';
      final result = parsePlaylistJson(json);
      expect(result.entries.map((e) => e.url), ['https://y/ok']);
    });
  });
}
