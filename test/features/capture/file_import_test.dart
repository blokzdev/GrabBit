import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/utils/media_type.dart';
import 'package:grabbit/features/capture/data/file_import.dart';

void main() {
  group('mediaTypeForExtOrNull', () {
    test('maps known media extensions', () {
      expect(mediaTypeForExtOrNull('jpg'), 'image');
      expect(mediaTypeForExtOrNull('PNG'), 'image');
      expect(mediaTypeForExtOrNull('mp3'), 'audio');
      expect(mediaTypeForExtOrNull('mp4'), 'video');
      expect(mediaTypeForExtOrNull('mkv'), 'video');
    });

    test('returns null for non-media extensions', () {
      expect(mediaTypeForExtOrNull('pdf'), isNull);
      expect(mediaTypeForExtOrNull('txt'), isNull);
      expect(mediaTypeForExtOrNull(''), isNull);
      expect(mediaTypeForExtOrNull('exe'), isNull);
    });
  });

  group('encodingFormatForExt', () {
    test('maps common document types', () {
      expect(encodingFormatForExt('pdf'), 'application/pdf');
      expect(encodingFormatForExt('TXT'), 'text/plain');
      expect(encodingFormatForExt('json'), 'application/json');
    });

    test('returns null for unknown extensions', () {
      expect(encodingFormatForExt('xyz'), isNull);
    });
  });

  group('buildDocumentThing', () {
    test('builds a DigitalDocument with file metadata + provenance', () {
      final doc = buildDocumentThing(
        name: 'report.pdf',
        filePath: '/data/import_1/report.pdf',
        encodingFormat: 'application/pdf',
        sizeBytes: 2048,
        now: () => DateTime.utc(2026, 6, 15),
      );

      expect(doc.json['@type'], 'DigitalDocument');
      expect(doc.json['name'], 'report.pdf');
      expect(doc.json['url'], '/data/import_1/report.pdf');
      expect(doc.json['contentUrl'], '/data/import_1/report.pdf');
      expect(doc.json['encodingFormat'], 'application/pdf');
      expect(doc.json['contentSize'], '2048');

      final prov = doc.json['grabbit:provenance'] as Map;
      expect(prov['provenance'], 'user-authored');
      expect(prov['sourceRef'], 'file-import');
    });

    test('drops a blank encodingFormat', () {
      final doc = buildDocumentThing(
        name: 'data',
        filePath: '/data/data',
        encodingFormat: null,
      );
      expect(doc.json.containsKey('encodingFormat'), isFalse);
    });
  });
}
