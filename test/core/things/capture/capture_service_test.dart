import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/things/capture/capture_service.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';

/// A fake fill that must never run (branch a).
GenerateStructured _explodes() =>
    (tools, prompt, {systemPrompt}) async =>
        fail('generate must not be called on the direct-parse branch');

GenerateStructured _returns(StructuredResult r) =>
    (tools, prompt, {systemPrompt}) async => r;

GenerateStructured _throws(InferenceErrorCode code) =>
    (tools, prompt, {systemPrompt}) async =>
        throw InferenceException(code, 'boom');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CaptureService service;

  setUpAll(() async {
    final vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
    service = CaptureService(vocab);
  });

  test('html with structured markup → branch (a), no model call', () async {
    const html = '''
<script type="application/ld+json">
{"@context":"https://schema.org","@type":"Recipe","name":"Soup",
 "recipeIngredient":["water"]}
</script>''';

    final outcome = await service.capture(
      const CaptureRequest(sourceRef: 'cap-1', html: html),
      generate: _explodes(),
      now: () => DateTime.utc(2026, 6, 15),
    );

    expect(outcome.branch, CaptureBranch.directParse);
    expect(outcome.type, 'Recipe');
    expect(outcome.provenance, Provenance.directParse);
    expect(outcome.confidence, 1);
    expect(outcome.doc!.json['name'], 'Soup');
  });

  test(
    'html with no structure but text → falls to the curator (branch b/c)',
    () async {
      final outcome = await service.capture(
        const CaptureRequest(
          sourceRef: 'cap-2',
          title: 'Easy Carbonara Recipe',
          text: 'Add the ingredients, stir the sauce, simmer, and serve.',
        ),
        modelId: 'qwen3-0-6b',
        generate: _returns(
          const StructuredResult(
            toolName: 'Recipe',
            arguments: {'name': 'Carbonara'},
          ),
        ),
        now: () => DateTime.utc(2026, 6, 15),
      );

      expect(outcome.branch, CaptureBranch.model);
      expect(outcome.type, 'Recipe');
      expect(outcome.doc!.json['name'], 'Carbonara');
      expect(outcome.provenance, isNotNull);
    },
  );

  test('an unparseable page with no text → branch none', () async {
    final outcome = await service.capture(
      const CaptureRequest(
        sourceRef: 'cap-3',
        html: '<html><body><p>nothing structured</p></body></html>',
      ),
      generate: _explodes(),
    );
    expect(outcome.branch, CaptureBranch.none);
    expect(outcome.doc, isNull);
  });

  test('a model-unavailable failure propagates', () async {
    await expectLater(
      service.capture(
        const CaptureRequest(
          sourceRef: 'cap-4',
          text: 'some content to extract',
        ),
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
  });
}
