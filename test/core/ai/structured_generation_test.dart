import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_engine_factory.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/ai/unavailable_generation_engine.dart';
import 'package:grabbit/core/device/device_profile.dart';

void main() {
  const toolDefs = [
    StructuredToolDef(
      name: 'Recipe',
      description: 'A cooking recipe',
      parameters: {
        'name': {'type': 'string'},
      },
    ),
  ];

  group('generateStructured seam (P12f forward seam — inert in v1)', () {
    test('UnavailableGenerationEngine throws unavailable', () async {
      const engine = UnavailableGenerationEngine();
      await expectLater(
        engine.generateStructured(toolDefs, 'prompt'),
        throwsA(
          isA<InferenceException>().having(
            (e) => e.code,
            'code',
            InferenceErrorCode.unavailable,
          ),
        ),
      );
    });

    test(
      'the factory engine (off-Android CI host) throws, never returns',
      () async {
        // On the CI host the factory yields Unavailable → unavailable. On a real
        // device the flutter_gemma engine throws `unsupported` (not implemented).
        // Either way the seam is inert: it must throw, never silently succeed.
        final engine = generationEngineFor(qwen3_0_6b);
        await expectLater(
          engine.generateStructured(toolDefs, 'prompt'),
          throwsA(
            isA<InferenceException>().having(
              (e) => e.code,
              'code',
              anyOf(
                InferenceErrorCode.unavailable,
                InferenceErrorCode.unsupported,
              ),
            ),
          ),
        );
      },
    );
  });

  group('structured_extraction capability row (gated to no model)', () {
    const matrix = ModelCapabilityMatrix();

    test('no tier has an eligible structured-extraction model yet', () {
      for (final tier in DeviceTier.values) {
        expect(matrix.eligibleStructuredExtractionModels(tier), isEmpty);
        expect(matrix.recommendedStructuredExtractionModel(tier), isNull);
      }
    });
  });

  group('structured-generation types', () {
    test('StructuredToolDef carries name, description, parameters', () {
      const def = StructuredToolDef(
        name: 'Event',
        description: 'A scheduled event',
        parameters: {
          'startDate': {'type': 'string'},
        },
      );
      expect(def.name, 'Event');
      expect(def.description, 'A scheduled event');
      expect(def.parameters['startDate'], {'type': 'string'});
    });

    test('StructuredToolDef defaults parameters to empty', () {
      const def = StructuredToolDef(name: 'Place', description: 'A location');
      expect(def.parameters, isEmpty);
    });

    test('StructuredResult carries the chosen tool + filled arguments', () {
      const result = StructuredResult(
        toolName: 'Recipe',
        arguments: {'name': 'Soup'},
      );
      expect(result.toolName, 'Recipe');
      expect(result.arguments['name'], 'Soup');
    });
  });
}
