import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/capture/data/barcode_capture.dart';

void main() {
  late AppDatabase db;
  late ThingRepository things;
  late CaptureCommitService commit;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
    commit = CaptureCommitService(things);
  });
  tearDown(() => db.close());

  test(
    'a scanned Product skeleton asserts a Product Thing with its gtin',
    () async {
      final match = classifyBarcode('036000291452')!;
      final id = await commit.commitThing(buildBarcodeThing(match));

      final thing = await things.thingById(id);
      expect(thing, isNotNull);
      expect(thing!.type, 'Product');
      expect(thing.jsonld, contains('036000291452'));
      expect(await things.countThings(), 1);
    },
  );

  test('a scanned Book skeleton asserts a Book Thing with its isbn', () async {
    final match = classifyBarcode('9780306406157')!;
    final id = await commit.commitThing(buildBarcodeThing(match));

    final thing = await things.thingById(id);
    expect(thing!.type, 'Book');
    expect(thing.jsonld, contains('"isbn"'));
  });
}
