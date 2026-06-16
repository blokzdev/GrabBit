import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/ai/embedder_engine.dart';
import 'package:grabbit/core/ai/embedder_engine_provider.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/core/graph/graph_query_service.dart';
import 'package:grabbit/core/graph/unavailable_graph_store.dart';
import 'package:grabbit/features/ai/data/rag_retriever.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

/// Embedder that returns a fixed vector; always ready.
class FakeEmbedderEngine implements EmbedderEngine {
  @override
  EmbedderModel get model => defaultEmbedder;
  @override
  bool get isAvailable => true;
  @override
  int get dimension => 3;
  @override
  Future<bool> ensureReady() async => true;
  @override
  Future<void> downloadModel({void Function(double)? onProgress}) async {}
  @override
  Future<List<double>> embed(String text) async => const [0.1, 0.2, 0.3];
  @override
  Future<List<List<double>>> embedBatch(List<String> texts) async => [
    for (final _ in texts) const [0.1, 0.2, 0.3],
  ];
  @override
  Future<void> close() async {}
}

/// GraphQueryService with canned vector + related results (the underlying store
/// is the no-op one; we override the two methods the retriever uses).
class FakeGraphQueryService extends GraphQueryService {
  FakeGraphQueryService(
    this.hits, {
    this.related = const [],
    this.thingHits = const [],
  }) : super(const UnavailableGraphStore());
  final List<VectorHit> hits;
  final List<VectorHit> thingHits;
  final List<String> related;

  @override
  Future<List<VectorHit>> vectorSearch(
    List<double> query, {
    int k = 50,
    int ef = 100,
    String relation = 'embedding',
  }) async => relation == 'thing_embedding' ? thingHits : hits;

  @override
  Future<List<String>> relatedTo(
    String id, {
    int k = 50,
    int limit = 12,
  }) async => related;
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seedItem(String id, String title, {String? description}) async {
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: id,
            title: title,
            sourceUrl: 'u',
            site: 'youtube',
            filePath: '/m/$id',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );
    await db
        .into(db.mediaMetadata)
        .insert(
          MediaMetadataCompanion.insert(
            itemId: id,
            description: Value(description),
          ),
        );
  }

  ProviderContainer makeContainer({
    required FakeGraphQueryService graph,
    bool ready = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        embedderEngineProvider.overrideWithValue(FakeEmbedderEngine()),
        graphQueryServiceProvider.overrideWithValue(graph),
        semanticSearchReadyProvider.overrideWith((ref) async => ready),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('retrieves cited sources + a grounded prompt (P13d-1)', () async {
    await seedItem('a', 'Live in Tokyo', description: 'a great concert');
    await seedItem('b', 'Studio session', description: 'recording');
    final c = makeContainer(
      graph: FakeGraphQueryService([
        const VectorHit('a', 0.1),
        const VectorHit('b', 0.4),
      ]),
    );

    final ctx = await c.read(ragRetrieverProvider).retrieve('what concerts?');

    expect(ctx.hasSources, isTrue);
    expect(ctx.sources.map((s) => s.itemId), ['a', 'b']);
    expect(ctx.sources.first.index, 1);
    expect(ctx.prompt, contains('[1] Live in Tokyo'));
    expect(ctx.prompt, contains('a great concert'));
    expect(ctx.prompt, contains('Question: what concerts?'));
    expect(ctx.systemPrompt, isNotEmpty);
  });

  test('cites the Thing — title from Thing.name + its @type (P14e)', () async {
    await seedItem('a', 'Live in Tokyo', description: 'a great concert');
    // A MediaObject Thing for the same id (thing.id == media_items.id).
    await db
        .into(db.things)
        .insert(
          ThingsCompanion.insert(
            id: 'a',
            type: 'VideoObject',
            jsonld: '{"@type":"VideoObject","name":"Tokyo Concert"}',
            name: const Value('Tokyo Concert'),
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        );
    final c = makeContainer(
      graph: FakeGraphQueryService([const VectorHit('a', 0.1)]),
    );

    final ctx = await c.read(ragRetrieverProvider).retrieve('concerts?');

    expect(ctx.sources.single.title, 'Tokyo Concert'); // Thing name, not media
    expect(ctx.sources.single.type, 'VideoObject');
    expect(ctx.prompt, contains('[1] Tokyo Concert (VideoObject)'));
    expect(
      ctx.prompt,
      contains('a great concert'),
    ); // snippet still from metadata
  });

  test(
    'recalls a non-media Thing via thing_embedding + JSON-LD snippet (P16f)',
    () async {
      // A non-media Recipe Thing — no media row, so its snippet comes from JSON-LD.
      await db
          .into(db.things)
          .insert(
            ThingsCompanion.insert(
              id: 'r',
              type: 'Recipe',
              jsonld:
                  '{"@type":"Recipe","name":"Carbonara","recipeIngredient":["eggs","guanciale"]}',
              name: const Value('Carbonara'),
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          );
      final c = makeContainer(
        // media search empty; the Thing index returns the Recipe.
        graph: FakeGraphQueryService(
          const [],
          thingHits: const [VectorHit('r', 0.1)],
        ),
      );

      final ctx = await c.read(ragRetrieverProvider).retrieve('pasta?');

      expect(ctx.sources.single.itemId, 'r');
      expect(ctx.sources.single.title, 'Carbonara');
      expect(ctx.sources.single.type, 'Recipe');
      expect(ctx.prompt, contains('[1] Carbonara (Recipe)'));
      expect(ctx.prompt, contains('eggs')); // snippet from the Thing's JSON-LD
    },
  );

  test('empty question or unready retrieval → no sources (P13d-1)', () async {
    await seedItem('a', 'X');
    final graph = FakeGraphQueryService([const VectorHit('a', 0.1)]);

    final c1 = makeContainer(graph: graph);
    expect(
      (await c1.read(ragRetrieverProvider).retrieve('  ')).hasSources,
      isFalse,
    );

    final c2 = makeContainer(graph: graph, ready: false);
    expect(
      (await c2.read(ragRetrieverProvider).retrieve('q')).hasSources,
      isFalse,
    );
  });

  test('empty vector index → no sources (P13d-1)', () async {
    final c = makeContainer(graph: FakeGraphQueryService(const []));
    expect(
      (await c.read(ragRetrieverProvider).retrieve('q')).hasSources,
      isFalse,
    );
  });
}
