import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/media_object_projection.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';
import 'package:grabbit/core/things/thing_validation.dart';

MediaItem _item({
  String id = 'm1',
  String title = 'My Clip',
  String sourceUrl = 'https://example.com/watch?v=1',
  String site = 'example',
  String filePath = '/data/app/files/m1.mp4',
  String type = 'video',
  int? durationSec,
  int? sizeBytes,
  int? width,
  int? height,
  String? thumbPath,
}) => MediaItem(
  id: id,
  title: title,
  sourceUrl: sourceUrl,
  site: site,
  filePath: filePath,
  type: type,
  durationSec: durationSec,
  sizeBytes: sizeBytes,
  width: width,
  height: height,
  thumbPath: thumbPath,
  createdAt: DateTime.utc(2026, 1, 1),
  storageState: 'private',
  isFavorite: false,
);

MediaMetadataData _meta({
  String itemId = 'm1',
  String? uploader,
  DateTime? uploadDate,
  String? description,
  String? channelId,
  String? tags,
  String? transcript,
  String? playlistTitle,
  String? playlistId,
}) => MediaMetadataData(
  itemId: itemId,
  uploader: uploader,
  uploadDate: uploadDate,
  description: description,
  channelId: channelId,
  tags: tags,
  transcript: transcript,
  playlistTitle: playlistTitle,
  playlistId: playlistId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('iso8601Duration', () {
    test('formats seconds as PTnHnMnS, zero as PT0S', () {
      expect(iso8601Duration(0), 'PT0S');
      expect(iso8601Duration(1), 'PT1S');
      expect(iso8601Duration(61), 'PT1M1S');
      expect(iso8601Duration(3600), 'PT1H');
      expect(iso8601Duration(3661), 'PT1H1M1S');
      expect(iso8601Duration(-5), 'PT0S'); // clamped
    });
  });

  group('projectMediaObject', () {
    test('maps a video item + full metadata field-by-field', () {
      final doc = projectMediaObject(
        _item(
          type: 'video',
          durationSec: 3661,
          sizeBytes: 1024,
          width: 1920,
          height: 1080,
          thumbPath: '/data/app/files/m1.jpg',
        ),
        _meta(
          uploader: 'A Channel',
          channelId: 'UC123',
          uploadDate: DateTime.utc(2025, 6, 1),
          description: 'A clip.',
          tags: 'one,two',
          transcript: 'hello world',
          playlistTitle: 'My List',
          playlistId: 'PL9',
        ),
      );
      final j = doc.json;

      expect(doc.type, 'VideoObject');
      expect(j['@context'], 'https://schema.org');
      expect(doc.name, 'My Clip');
      expect(doc.url, 'https://example.com/watch?v=1');
      expect(j['contentUrl'], '/data/app/files/m1.mp4');
      expect(j['thumbnailUrl'], '/data/app/files/m1.jpg');
      expect(j['description'], 'A clip.');
      expect(j['uploadDate'], '2025-06-01T00:00:00.000Z');
      expect(j['duration'], 'PT1H1M1S');
      expect(j['width'], 1920);
      expect(j['height'], 1080);
      expect(j['contentSize'], '1024');
      expect(j['keywords'], 'one,two');
      expect(j['transcript'], 'hello world');
      expect(j['author'], {
        '@type': 'Person',
        'name': 'A Channel',
        'identifier': 'UC123',
      });
      expect(j['isPartOf'], {
        '@type': 'CreativeWork',
        'name': 'My List',
        'identifier': 'PL9',
      });
      expect(j['grabbit:provenance'], {
        'method': 'direct-parse',
        'projectionVersion': kMediaObjectProjectionVersion,
      });
    });

    test(
      'audio → AudioObject (no dims), image → ImageObject (no duration/transcript)',
      () {
        final audio = projectMediaObject(
          _item(type: 'audio', durationSec: 120),
          _meta(transcript: 'spoken'),
        );
        expect(audio.type, 'AudioObject');
        expect(audio.json['duration'], 'PT2M');
        expect(audio.json['transcript'], 'spoken');
        expect(audio.json.containsKey('width'), isFalse);

        final image = projectMediaObject(
          _item(type: 'image', durationSec: 99, width: 800, height: 600),
          _meta(transcript: 'ignored'),
        );
        expect(image.type, 'ImageObject');
        expect(image.json.containsKey('duration'), isFalse);
        expect(image.json.containsKey('transcript'), isFalse);
        expect(image.json['width'], 800);
      },
    );

    test('a bare item (no metadata) emits only the present, required keys', () {
      final doc = projectMediaObject(_item(durationSec: null), null);
      expect(
        doc.json.keys,
        containsAll(<String>['@type', 'name', 'url', 'contentUrl']),
      );
      for (final absent in const [
        'description',
        'thumbnailUrl',
        'uploadDate',
        'duration',
        'width',
        'height',
        'contentSize',
        'keywords',
        'transcript',
        'author',
        'isPartOf',
      ]) {
        expect(
          doc.json.containsKey(absent),
          isFalse,
          reason: '$absent should be omitted',
        );
      }
    });

    test('is deterministic — same input yields identical JSON-LD', () {
      final a = projectMediaObject(
        _item(durationSec: 10),
        _meta(uploader: 'x'),
      );
      final b = projectMediaObject(
        _item(durationSec: 10),
        _meta(uploader: 'x'),
      );
      expect(a.toJsonString(), b.toJsonString());
    });
  });

  test(
    'projected Things validate against the real bundled schema.org vocabulary',
    () async {
      final vocab = SchemaOrgVocabulary.parse(
        await rootBundle.loadString(schemaOrgVocabularyAsset),
      );
      final docs = [
        projectMediaObject(
          _item(
            type: 'video',
            durationSec: 60,
            width: 1,
            height: 1,
            sizeBytes: 1,
            thumbPath: '/t.jpg',
          ),
          _meta(
            uploader: 'c',
            channelId: 'id',
            uploadDate: DateTime.utc(2025),
            description: 'd',
            tags: 't',
            transcript: 'x',
            playlistTitle: 'p',
            playlistId: 'pid',
          ),
        ),
        projectMediaObject(
          _item(type: 'audio', durationSec: 1),
          _meta(transcript: 'x'),
        ),
        projectMediaObject(
          _item(type: 'image', width: 1, height: 1),
          _meta(description: 'd'),
        ),
      ];
      for (final doc in docs) {
        final result = validateThingDoc(doc, vocab);
        expect(
          result.isValid,
          isTrue,
          reason:
              '${doc.type} invalid; unknown props: ${result.unknownProperties}',
        );
      }
    },
  );
}
