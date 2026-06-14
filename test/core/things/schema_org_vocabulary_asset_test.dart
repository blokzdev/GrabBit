import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

/// Smoke test that the **real bundled** schema.org vocabulary (pinned v30.0) loads
/// from the asset bundle and parses into a sane index — this is what discharges P14a
/// on-device (the asset loads the same way at runtime), so no APK check is owed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled schema.org vocabulary loads and parses', () async {
    final json = await rootBundle.loadString(schemaOrgVocabularyAsset);
    final vocab = SchemaOrgVocabulary.parse(json);

    expect(vocab.typeCount, greaterThan(800));
    for (final type in const [
      'Thing',
      'CreativeWork',
      'MediaObject',
      'AudioObject',
      'ImageObject',
      'VideoObject',
      'Recipe',
      'Event',
      'Place',
      'Article',
      'Product',
    ]) {
      expect(vocab.isKnownType(type), isTrue, reason: '$type should be known');
    }

    // Inherited + direct property resolution over the real graph.
    expect(vocab.isDefined('Recipe', 'name'), isTrue); // inherited from Thing
    expect(vocab.isDefined('Recipe', 'recipeIngredient'), isTrue);
    expect(vocab.isDefined('VideoObject', 'contentUrl'), isTrue); // MediaObject
  });
}
