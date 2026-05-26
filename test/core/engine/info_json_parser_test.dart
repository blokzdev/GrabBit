import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/engine/info_json_parser.dart';

void main() {
  group('parseInfoJson', () {
    test('extracts the rich field set', () {
      final info = parseInfoJson({
        'id': 'dQw4w9WgXcQ',
        'uploader': 'Rick Astley',
        'uploader_id': '@rickastley',
        'channel_id': 'UC123',
        'upload_date': '20091025',
        'description': 'A clip',
        'tags': ['80s', 'pop', ''],
        'extractor_key': 'Youtube',
      });
      expect(info.sourceId, 'dQw4w9WgXcQ');
      expect(info.uploader, 'Rick Astley');
      expect(info.uploaderId, '@rickastley');
      expect(info.channelId, 'UC123');
      expect(info.uploadDate, '20091025');
      expect(info.description, 'A clip');
      expect(info.tags, '80s, pop');
      expect(info.extractor, 'Youtube');
    });

    test('falls back uploader→channel and tolerates missing fields', () {
      final info = parseInfoJson({
        'channel': 'Some Channel',
        'tags': <String>[],
      });
      expect(info.uploader, 'Some Channel');
      expect(info.uploaderId, isNull);
      expect(info.sourceId, isNull);
      expect(info.tags, isNull); // empty list → null
    });

    test('treats empty strings as null', () {
      final info = parseInfoJson({'uploader': '   ', 'id': ''});
      expect(info.uploader, isNull);
      expect(info.sourceId, isNull);
    });

    test('extracts positive integer width/height', () {
      final info = parseInfoJson({'width': 1920, 'height': 1080});
      expect(info.width, 1920);
      expect(info.height, 1080);
    });

    test('treats missing or non-positive dimensions as null', () {
      expect(parseInfoJson({'height': 720}).width, isNull);
      final zero = parseInfoJson({'width': 0, 'height': -5});
      expect(zero.width, isNull);
      expect(zero.height, isNull);
    });
  });

  group('parseInfoJsonString', () {
    test('parses valid JSON text', () {
      final info = parseInfoJsonString(jsonEncode({'id': 'abc'}));
      expect(info?.sourceId, 'abc');
    });

    test('returns null on malformed or non-object input', () {
      expect(parseInfoJsonString('not json'), isNull);
      expect(parseInfoJsonString('[1,2,3]'), isNull);
    });
  });
}
