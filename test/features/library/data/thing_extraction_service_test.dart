import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/schema_org_vocabulary_provider.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/data/thing_extraction_service.dart';

GenerateStructured _returns(StructuredResult r) =>
    (tools, prompt, {systemPrompt}) async => r;

GenerateStructured _throws(InferenceErrorCode code) =>
    (tools, prompt, {systemPrompt}) async =>
        throw InferenceException(code, 'boom');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SchemaOrgVocabulary vocab;
  late AppDatabase db;
  late ThingExtractionService service;
  late ThingSuggestionRepository suggestions;

  setUpAll(() async {
    vocab = SchemaOrgVocabulary.parse(
      await rootBundle.loadString(schemaOrgVocabularyAsset),
    );
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    suggestions = ThingSuggestionRepository(db);
    service = ThingExtractionService(MetadataRepository(db), suggestions);
  });
  tearDown(() => db.close());

  Future<MediaItem> seed({String? description}) async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'item-1',
            title: 'Easy Carbonara Recipe',
            sourceUrl: 'https://www.allrecipes.com/carbonara',
            site: 'allrecipes',
            filePath: '/tmp/x.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    if (description != null) {
      await db
          .into(db.mediaMetadata)
          .insert(
            MediaMetadataCompanion.insert(
              itemId: 'item-1',
              description: Value(description),
            ),
          );
    }
    return (db.select(
      db.mediaItems,
    )..where((t) => t.id.equals('item-1'))).getSingle();
  }

  const recipeResult = StructuredResult(
    toolName: 'Recipe',
    arguments: {
      'name': 'Carbonara',
      'recipeIngredient': ['eggs', 'guanciale'],
    },
  );

  test('extracts + persists a pending suggestion', () async {
    final item = await seed(description: 'Add the ingredients, stir, simmer.');
    final outcome = await service.extract(
      item: item,
      vocab: vocab,
      generate: _returns(recipeResult),
      modelId: 'qwen3-0-6b',
      now: () => DateTime.utc(2026, 1, 2),
    );

    expect(outcome.status, ExtractionStatus.extracted);
    expect(outcome.type, 'Recipe');

    final pending = await suggestions.pendingForItem('item-1');
    expect(pending, hasLength(1));
    expect(pending.single.type, 'Recipe');
    expect(pending.single.confidence, isNotNull);
    expect(pending.single.jsonld, contains('grabbit:provenance'));
    expect(pending.single.jsonld, contains('qwen3-0-6b'));
  });

  test('re-running replaces the prior suggestion (no accumulation)', () async {
    final item = await seed(description: 'Add the ingredients, stir, simmer.');
    await service.extract(
      item: item,
      vocab: vocab,
      generate: _returns(recipeResult),
    );
    await service.extract(
      item: item,
      vocab: vocab,
      generate: _returns(recipeResult),
    );
    expect(await suggestions.pendingForItem('item-1'), hasLength(1));
  });

  test('no usable text → noText, nothing persisted', () async {
    final item = await seed(); // no metadata row
    final outcome = await service.extract(
      item: item,
      vocab: vocab,
      generate: _returns(recipeResult),
    );
    expect(outcome.status, ExtractionStatus.noText);
    expect(await suggestions.countPending(), 0);
  });

  test('curator finds nothing (model declines) → nothingFound', () async {
    final item = await seed(description: 'Add the ingredients, stir, simmer.');
    final outcome = await service.extract(
      item: item,
      vocab: vocab,
      generate: _throws(InferenceErrorCode.generateFailed),
    );
    expect(outcome.status, ExtractionStatus.nothingFound);
    expect(await suggestions.countPending(), 0);
  });

  test('model unavailable → needsModel', () async {
    final item = await seed(description: 'Add the ingredients, stir, simmer.');
    final outcome = await service.extract(
      item: item,
      vocab: vocab,
      generate: _throws(InferenceErrorCode.unavailable),
    );
    expect(outcome.status, ExtractionStatus.needsModel);
    expect(await suggestions.countPending(), 0);
  });
}
