import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/curator/thing_classifier.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

/// The outcome of an on-demand extraction, mapped to user feedback by the caller.
enum ExtractionStatus {
  /// A suggestion was extracted + persisted (see [ExtractionOutcome.type]).
  extracted,

  /// The item has no usable text to extract from.
  noText,

  /// The curator ran but found nothing worth suggesting (model declined / no tool
  /// call / unknown type / nothing substantive filled).
  nothingFound,

  /// The generation model isn't ready (not downloaded / can't load).
  needsModel,
}

/// The result of [ThingExtractionService.extract].
class ExtractionOutcome {
  const ExtractionOutcome(this.status, [this.type]);

  final ExtractionStatus status;

  /// The extracted Thing's `@type` (only set when [status] is
  /// [ExtractionStatus.extracted]).
  final String? type;
}

/// Runs the P15b [Curator] over a downloaded item's text and persists the result
/// as a **pending suggestion** (P15c) — never asserted into `things` (ADR-0004).
/// The `generate` fn, `vocab`, and `modelId` are injected (resolved from providers
/// by the caller), so the service is unit-testable with a fake engine.
class ThingExtractionService {
  ThingExtractionService(this._metadata, this._suggestions);

  final MetadataRepository _metadata;
  final ThingSuggestionRepository _suggestions;

  /// Extracts a Thing from [item]'s best available text and, on success, replaces
  /// the item's prior pending suggestions with it. Returns an [ExtractionOutcome]
  /// describing what happened (for user feedback).
  Future<ExtractionOutcome> extract({
    required MediaItem item,
    required SchemaOrgVocabulary vocab,
    required GenerateStructured generate,
    String? modelId,
    DateTime Function() now = DateTime.now,
  }) async {
    final meta = await _metadata.metadataForItem(item.id);
    final text = _bestText(meta);
    if (text == null) return const ExtractionOutcome(ExtractionStatus.noText);

    final input = ClassificationInput(
      title: item.title,
      text: text,
      host: Uri.tryParse(item.sourceUrl)?.host,
      mediaType: item.type,
      tags: _splitTags(meta?.tags),
    );

    final CuratorResult? result;
    try {
      result = await Curator(vocab).curate(
        input: input,
        generate: generate,
        sourceRef: item.id,
        modelId: modelId,
        now: now,
      );
    } on InferenceException catch (e) {
      if (e.code == InferenceErrorCode.unavailable) {
        return const ExtractionOutcome(ExtractionStatus.needsModel);
      }
      rethrow;
    }

    if (result == null) {
      return const ExtractionOutcome(ExtractionStatus.nothingFound);
    }

    await _suggestions.replaceForItem(item.id, [
      ThingSuggestionsCompanion.insert(
        id: 'sug_${now().microsecondsSinceEpoch}',
        sourceItemId: item.id,
        type: result.type,
        jsonld: result.doc.toJsonString(),
        confidence: Value(result.confidence),
        createdAt: now(),
      ),
    ]);
    return ExtractionOutcome(ExtractionStatus.extracted, result.type);
  }

  /// The richest available text for extraction (AI summary first, then the raw
  /// sources). Null when there's nothing usable.
  String? _bestText(MediaMetadataData? meta) {
    for (final candidate in [
      meta?.aiSummary,
      meta?.transcript,
      meta?.description,
      meta?.ocrText,
    ]) {
      final t = candidate?.trim();
      if (t != null && t.isNotEmpty) return t;
    }
    return null;
  }

  List<String> _splitTags(String? tags) => (tags ?? '')
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toList();
}

final thingExtractionServiceProvider = Provider<ThingExtractionService>(
  (ref) => ThingExtractionService(
    ref.watch(metadataRepositoryProvider),
    ref.watch(thingSuggestionRepositoryProvider),
  ),
);
