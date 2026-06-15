import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/things/curator/priority_types.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

/// Guards the curated catalog against vocabulary drift (ADR-0001): every priority
/// type is a real schema.org class and every curated field is a property defined
/// on it. Validated against the **real bundled** vocab, so it's CI-discharged.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SchemaOrgVocabulary vocab;

  setUpAll(() async {
    vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
  });

  test('catalog covers the five locked priority types', () {
    expect(kPriorityTypes.map((t) => t.type).toList(), const [
      'Recipe',
      'Event',
      'Place',
      'Article',
      'Product',
    ]);
  });

  for (final t in kPriorityTypes) {
    group(t.type, () {
      test('is a known schema.org type', () {
        expect(vocab.isKnownType(t.type), isTrue);
      });

      test('every curated field is schema.org-defined on the type', () {
        for (final f in t.fields) {
          expect(
            vocab.isDefined(t.type, f.name),
            isTrue,
            reason: '${t.type}.${f.name} is not a defined schema.org property',
          );
        }
      });

      test('has a small (<20), non-empty, duplicate-free field set', () {
        expect(t.fields, isNotEmpty);
        expect(t.fields.length, lessThan(20));
        final names = t.fields.map((f) => f.name).toList();
        expect(names.toSet().length, names.length, reason: 'duplicate field');
      });

      test('has classification signals', () {
        expect(t.keywords, isNotEmpty);
        expect(t.description.trim(), isNotEmpty);
      });
    });
  }
}
