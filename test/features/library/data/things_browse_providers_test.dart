import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';

Thing _thing(String id, String type) => Thing(
  id: id,
  type: type,
  jsonld: '{"@type":"$type"}',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  group('thingDestinationRoute', () {
    test(
      'MediaObject types route to the media item (id == media_items.id)',
      () {
        for (final type in const [
          'VideoObject',
          'AudioObject',
          'ImageObject',
        ]) {
          expect(thingDestinationRoute(_thing('m1', type)), '/item/m1');
        }
      },
    );

    test('non-media Things route to the standalone Thing render', () {
      expect(
        thingDestinationRoute(_thing('thing_1', 'Recipe')),
        '/thing/thing_1',
      );
      expect(
        thingDestinationRoute(_thing('thing_2', 'Event')),
        '/thing/thing_2',
      );
    });
  });
}
