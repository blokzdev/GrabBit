import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/things/curator/priority_types.dart';
import 'package:grabbit/core/things/curator/thing_classifier.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_validation.dart';

/// The injected structured-generation call — matches
/// `GenerationEngine.generateStructured` so the curator stays pure (no engine or
/// plugin import); P15c passes `engine.generateStructured`.
typedef GenerateStructured =
    Future<StructuredResult> Function(
      List<StructuredToolDef> toolDefs,
      String prompt, {
      String? systemPrompt,
    });

/// A curated extraction: the candidate [doc] (a validated, provenance-stamped
/// `ThingDoc` — **not yet asserted**), its [type], the classifier [confidence],
/// and the narrow-then-fill [provenance] branch.
class CuratorResult {
  const CuratorResult({
    required this.doc,
    required this.type,
    required this.confidence,
    required this.provenance,
  });

  final ThingDoc doc;
  final String type;
  final double confidence;
  final Provenance provenance;
}

/// System instruction for the fill: keep the small model honest.
const String kExtractionSystemPrompt =
    'You extract structured data from media descriptions and transcripts. '
    'Call the single most appropriate tool for the content. Fill only fields you '
    'are confident about and leave the rest empty. Never invent facts.';

/// The pure, on-device **Curator** (ADR-0002 narrow-then-fill): classify a
/// download's text into candidate schema.org types, build a small fill tool-schema
/// per candidate, ask the model to fill one (single-tool when confident, a
/// narrowed-set otherwise), and assemble + validate the result into a candidate
/// `ThingDoc`. No I/O: the model call is injected, so the whole flow is unit-testable.
class Curator {
  const Curator(this._vocab);

  final SchemaOrgVocabulary _vocab;

  /// Runs the curator over [input], filling via [generate]. Returns a candidate
  /// result, or `null` when there's nothing to extract (empty text, the model
  /// declines / returns no tool call, the chosen type is unknown, or nothing
  /// substantive was filled). Rethrows an [InferenceException] that isn't
  /// `generateFailed` (e.g. `unavailable`) so the caller can surface a friendly
  /// "needs model" reason.
  Future<CuratorResult?> curate({
    required ClassificationInput input,
    required GenerateStructured generate,
    required String sourceRef,
    String? modelId,
    DateTime Function() now = DateTime.now,
  }) async {
    if (input.text.trim().isEmpty) return null;

    final classification = classify(input);
    if (classification.candidates.isEmpty) return null;
    final tools = classification.candidates.map(buildToolDef).toList();

    final StructuredResult result;
    try {
      result = await generate(
        tools,
        buildExtractionPrompt(input.text),
        systemPrompt: kExtractionSystemPrompt,
      );
    } on InferenceException catch (e) {
      // The model answered with text / no tool call — nothing to extract.
      if (e.code == InferenceErrorCode.generateFailed) return null;
      rethrow;
    }

    return _assemble(
      result,
      classification,
      sourceRef: sourceRef,
      modelId: modelId,
      now: now(),
    );
  }

  CuratorResult? _assemble(
    StructuredResult result,
    Classification classification, {
    required String sourceRef,
    required String? modelId,
    required DateTime now,
  }) {
    final type = schemaLocalName(result.toolName);
    final offered = classification.candidates.any((t) => t.type == type);
    if (!offered || !_vocab.isKnownType(type)) return null;

    // Build sparse JSON-LD from the filled args (drop null / blank / empty).
    final json = <String, dynamic>{
      '@context': 'https://schema.org',
      '@type': type,
    };
    result.arguments.forEach((key, value) {
      final cleaned = _clean(value);
      if (cleaned != null) json[schemaLocalName(key)] = cleaned;
    });

    // Drop properties not defined on the type (boundary validation, ADR-0001).
    final validation = validateThingDoc(ThingDoc(json), _vocab);
    for (final prop in validation.unknownProperties) {
      json.remove(prop);
    }

    // Need at least one substantive (non-`@`) property to be worth suggesting.
    if (!json.keys.any((k) => !k.startsWith('@'))) return null;

    final provenance = classification.isSingle
        ? Provenance.singleTool
        : Provenance.narrowedSet;
    final confidence = classification.confidenceFor(type);
    json[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
      provenance: provenance,
      capturedAt: now,
      sourceRef: sourceRef,
      modelId: modelId,
      confidence: confidence,
    );

    return CuratorResult(
      doc: ThingDoc(json),
      type: type,
      confidence: confidence,
      provenance: provenance,
    );
  }
}

/// Builds the fill tool-schema for [t]: name = `@type`, description guides the
/// model, parameters are a flat JSON-schema object over the curated fields.
StructuredToolDef buildToolDef(PriorityType t) => StructuredToolDef(
  name: t.type,
  description: t.description,
  parameters: {
    'type': 'object',
    'properties': {
      for (final f in t.fields)
        f.name: {
          'type': _jsonType(f.type),
          if (f.type == CuratorFieldType.stringArray)
            'items': {'type': 'string'},
          if (f.type == CuratorFieldType.dateTime) 'format': 'date-time',
          if (f.description != null) 'description': f.description,
        },
    },
  },
);

/// The fill prompt: the content, clipped to [maxChars] (small models have small
/// contexts; char-clipping is a crude but dependency-free budget).
String buildExtractionPrompt(String text, {int maxChars = 4000}) {
  final clipped = text.length > maxChars ? text.substring(0, maxChars) : text;
  return 'Extract structured information from the content below by calling the '
      'most appropriate tool. Fill only the fields you are confident about.\n\n'
      'Content:\n$clipped';
}

String _jsonType(CuratorFieldType type) => switch (type) {
  CuratorFieldType.string => 'string',
  CuratorFieldType.stringArray => 'array',
  CuratorFieldType.number => 'number',
  CuratorFieldType.dateTime => 'string',
};

/// Drops null / blank / empty values; trims strings; filters blank list entries.
Object? _clean(Object? value) {
  if (value == null) return null;
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is List) {
    final cleaned = value.map(_clean).where((e) => e != null).toList();
    return cleaned.isEmpty ? null : cleaned;
  }
  return value;
}
