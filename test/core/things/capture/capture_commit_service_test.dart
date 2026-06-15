import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_repository.dart';

void main() {
  late AppDatabase db;
  late ThingRepository things;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
  });

  tearDown(() => db.close());

  ThingDoc note() => const ThingDoc({
    '@context': 'https://schema.org',
    '@type': 'NoteDigitalDocument',
    'name': 'Buy milk',
    kGrabbitProvenanceKey: {
      'provenance': 'user-authored',
      'sourceRef': 'manual',
      'capturedAt': '2026-06-15T00:00:00.000Z',
    },
  });

  test(
    'commitThing mints an id, asserts the Thing, and returns the id',
    () async {
      final service = CaptureCommitService(
        things,
        newThingId: () => 'thing_42',
      );

      final id = await service.commitThing(note());

      expect(id, 'thing_42');
      final row = await things.thingById('thing_42');
      expect(row, isNotNull);
      expect(row!.type, 'NoteDigitalDocument');
      expect(row.name, 'Buy milk');
    },
  );

  test(
    'commitThing preserves the user-authored provenance in the JSON-LD',
    () async {
      final service = CaptureCommitService(things, newThingId: () => 'thing_1');

      await service.commitThing(note());

      final row = await things.thingById('thing_1');
      final stored = ThingDoc.fromJsonString(row!.jsonld);
      expect(provenanceOf(stored), Provenance.userAuthored);
    },
  );

  test('default id minting is unique and time-based', () async {
    final service = CaptureCommitService(things);
    final a = await service.commitThing(note());
    final b = await service.commitThing(note());
    expect(a, startsWith('thing_'));
    expect(a, isNot(b));
  });
}
