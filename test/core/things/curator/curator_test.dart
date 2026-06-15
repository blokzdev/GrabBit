import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/curator/priority_types.dart';
import 'package:grabbit/core/things/curator/thing_classifier.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

GenerateStructured _returns(StructuredResult r) =>
    (tools, prompt, {systemPrompt}) async => r;

GenerateStructured _throws(InferenceErrorCode code) =>
    (tools, prompt, {systemPrompt}) async =>
        throw InferenceException(code, 'boom');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Curator curator;

  setUpAll(() async {
    final vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
    curator = Curator(vocab);
  });

  const recipeInput = ClassificationInput(
    title: 'Easy Carbonara Recipe',
    text: 'Add the ingredients, stir the sauce, simmer, and serve.',
  );

  test(
    'single-tool recipe → validated, provenance-stamped Recipe doc',
    () async {
      final result = await curator.curate(
        input: recipeInput,
        sourceRef: 'item-1',
        modelId: 'qwen3-0-6b',
        now: () => DateTime.utc(2026, 1, 2),
        generate: _returns(
          const StructuredResult(
            toolName: 'Recipe',
            arguments: {
              'name': 'Carbonara',
              'recipeIngredient': ['eggs', 'guanciale'],
              'prepTime': '  ', // blank → dropped
              'emptyList': <String>[], // empty → dropped
              'bogusProp': 'nope', // unknown → dropped
            },
          ),
        ),
      );

      expect(result, isNotNull);
      final json = result!.doc.json;
      expect(json['@context'], 'https://schema.org');
      expect(json['@type'], 'Recipe');
      expect(json['name'], 'Carbonara');
      expect(json['recipeIngredient'], ['eggs', 'guanciale']);
      expect(json.containsKey('prepTime'), isFalse);
      expect(json.containsKey('emptyList'), isFalse);
      expect(json.containsKey('bogusProp'), isFalse);

      expect(result.type, 'Recipe');
      expect(result.provenance, Provenance.singleTool);
      final prov = json[kGrabbitProvenanceKey] as Map;
      expect(prov['provenance'], 'single-tool');
      expect(prov['sourceRef'], 'item-1');
      expect(prov['modelId'], 'qwen3-0-6b');
      expect(prov['confidence'], result.confidence);
      expect(prov['capturedAt'], '2026-01-02T00:00:00.000Z');
    },
  );

  test('narrowed-set path stamps narrowed-set provenance', () async {
    final result = await curator.curate(
      // Balanced recipe + product cues → neither dominates → narrowed-set.
      input: const ClassificationInput(
        text: 'recipe ingredient cook — also a great product to buy on sale.',
      ),
      sourceRef: 'item-2',
      generate: _returns(
        const StructuredResult(
          toolName: 'Product',
          arguments: {'name': 'Widget', 'brand': 'Acme'},
        ),
      ),
    );

    expect(result, isNotNull);
    expect(result!.type, 'Product');
    expect(result.provenance, Provenance.narrowedSet);
    expect(
      (result.doc.json[kGrabbitProvenanceKey] as Map)['provenance'],
      'narrowed-set',
    );
  });

  test('empty text → no extraction', () async {
    final result = await curator.curate(
      input: const ClassificationInput(text: '   '),
      sourceRef: 'item-3',
      generate: _returns(
        const StructuredResult(toolName: 'Recipe', arguments: {'name': 'x'}),
      ),
    );
    expect(result, isNull);
  });

  test('model returns only blank/unknown args → no extraction', () async {
    final result = await curator.curate(
      input: recipeInput,
      sourceRef: 'item-4',
      generate: _returns(
        const StructuredResult(
          toolName: 'Recipe',
          arguments: {'bogusProp': 'x', 'name': '   '},
        ),
      ),
    );
    expect(result, isNull);
  });

  test('tool name not among offered candidates → no extraction', () async {
    final result = await curator.curate(
      input: recipeInput, // single-tool Recipe
      sourceRef: 'item-5',
      generate: _returns(
        const StructuredResult(toolName: 'Event', arguments: {'name': 'x'}),
      ),
    );
    expect(result, isNull);
  });

  test('generateFailed (no tool call) → no extraction', () async {
    final result = await curator.curate(
      input: recipeInput,
      sourceRef: 'item-6',
      generate: _throws(InferenceErrorCode.generateFailed),
    );
    expect(result, isNull);
  });

  test(
    'unavailable rethrows so the caller can surface "needs model"',
    () async {
      expect(
        () => curator.curate(
          input: recipeInput,
          sourceRef: 'item-7',
          generate: _throws(InferenceErrorCode.unavailable),
        ),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
    },
  );

  group('buildToolDef', () {
    test('emits a flat JSON-schema object over the curated fields', () {
      final recipe = kPriorityTypes.firstWhere((t) => t.type == 'Recipe');
      final def = buildToolDef(recipe);
      expect(def.name, 'Recipe');
      expect(def.description, isNotEmpty);

      final params = def.parameters;
      expect(params['type'], 'object');
      final props = params['properties']! as Map<String, Object?>;
      // String field.
      expect((props['name']! as Map)['type'], 'string');
      // Array field carries an items schema.
      final ingredient = props['recipeIngredient']! as Map;
      expect(ingredient['type'], 'array');
      expect(ingredient['items'], {'type': 'string'});
      // Date field carries a format hint.
      expect((props['datePublished']! as Map)['format'], 'date-time');
    });
  });
}
