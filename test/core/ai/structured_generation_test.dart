import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/generation_engine_factory.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/ai/structured_tool_adapter.dart';
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

  group('generateStructured (P15a — function-calling fill)', () {
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

    test('the factory engine on the off-Android CI host is Unavailable → '
        'unavailable', () async {
      // Off-Android the factory yields UnavailableGenerationEngine, so the
      // call degrades gracefully (throws `unavailable`) rather than touching
      // the plugin. The real flutter_gemma fill is exercised on the APK pass.
      final engine = generationEngineFor(qwen3_0_6b);
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
  });

  group('structured-tool adapter (P15a — the plugin seam)', () {
    test('toGemmaTool copies name, description, parameters 1:1', () {
      final tool = toGemmaTool(toolDefs.first);
      expect(tool.name, 'Recipe');
      expect(tool.description, 'A cooking recipe');
      expect(tool.parameters['name'], {'type': 'string'});
    });

    test('toolChoiceFor: single candidate forces the fill (required)', () {
      expect(toolChoiceFor(toolDefs), ToolChoice.required);
    });

    test('toolChoiceFor: a narrowed set lets the model pick (auto)', () {
      const narrowed = [
        StructuredToolDef(name: 'Recipe', description: 'A recipe'),
        StructuredToolDef(name: 'Event', description: 'An event'),
      ];
      expect(toolChoiceFor(narrowed), ToolChoice.auto);
    });

    test('structuredResultFrom maps name → toolName, args → arguments', () {
      const call = FunctionCallResponse(
        name: 'Recipe',
        args: {'name': 'Soup', 'cookTime': 'PT30M'},
      );
      final result = structuredResultFrom(call);
      expect(result.toolName, 'Recipe');
      expect(result.arguments, {'name': 'Soup', 'cookTime': 'PT30M'});
    });
  });

  group('structured_extraction capability row (P15a)', () {
    const matrix = ModelCapabilityMatrix();

    test('low tier is gated off (no eligible model, no recommendation)', () {
      expect(
        matrix.eligibleStructuredExtractionModels(DeviceTier.low),
        isEmpty,
      );
      expect(
        matrix.recommendedStructuredExtractionModel(DeviceTier.low),
        isNull,
      );
    });

    test('mid tier runs Qwen3-0.6B (its only function-calling rung)', () {
      expect(matrix.eligibleStructuredExtractionModels(DeviceTier.mid), [
        qwen3_0_6b,
      ]);
      expect(
        matrix.recommendedStructuredExtractionModel(DeviceTier.mid),
        qwen3_0_6b,
      );
    });

    test('high tier reaches Qwen2.5-1.5B + Gemma 4 E2B (recommended)', () {
      final high = matrix.eligibleStructuredExtractionModels(DeviceTier.high);
      expect(high, contains(qwen3_0_6b));
      expect(high, contains(qwen2_5_1_5b));
      expect(high, contains(gemma4E2b));
      expect(
        matrix.recommendedStructuredExtractionModel(DeviceTier.high),
        gemma4E2b,
      );
    });

    test('the recommendation is always tier-eligible', () {
      for (final tier in [DeviceTier.mid, DeviceTier.high]) {
        final rec = matrix.recommendedStructuredExtractionModel(tier);
        expect(matrix.eligibleStructuredExtractionModels(tier), contains(rec));
      }
    });

    test('SmolLM2-135M is never eligible (it ignores tools — no FC)', () {
      for (final tier in DeviceTier.values) {
        expect(
          matrix.eligibleStructuredExtractionModels(tier),
          isNot(contains(smolLm2_135mInstruct)),
        );
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
