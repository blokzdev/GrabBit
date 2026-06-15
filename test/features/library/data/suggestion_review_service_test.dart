import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/library/data/suggestion_review_service.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';

// A curator-shaped suggestion: a Recipe carrying the single-tool provenance the
// curator stamps into the JSON-LD (must survive the assert untouched).
const _recipeJsonld =
    '{"@context":"https://schema.org","@type":"Recipe","name":"Carbonara",'
    '"recipeIngredient":["eggs","guanciale"],'
    '"grabbit:provenance":{"provenance":"single-tool","modelId":"qwen3-0-6b",'
    '"capturedAt":"2026-01-02T00:00:00.000Z","confidence":0.8}}';

void main() {
  late AppDatabase db;
  late ThingRepository things;
  late ThingEdgeRepository edges;
  late ThingSuggestionRepository suggestions;
  late SuggestionReviewService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
    edges = ThingEdgeRepository(db);
    suggestions = ThingSuggestionRepository(db);
    service = SuggestionReviewService(
      things,
      edges,
      suggestions,
      now: () => DateTime.utc(2026, 1, 2),
      newThingId: () => 'thing_test',
    );
  });
  tearDown(() => db.close());

  Future<ThingSuggestion> seed({double? confidence = 0.8}) async {
    await suggestions.insert(
      ThingSuggestionsCompanion.insert(
        id: 'sug_1',
        sourceItemId: 'item-1',
        type: 'Recipe',
        jsonld: _recipeJsonld,
        confidence: Value(confidence),
        createdAt: DateTime.utc(2026),
      ),
    );
    return (await suggestions.byId('sug_1'))!;
  }

  group('accept', () {
    test('asserts the Thing, links it, and deletes the suggestion', () async {
      final s = await seed();

      await service.accept(s);

      final thing = await things.thingById('thing_test');
      expect(thing, isNotNull);
      expect(thing!.type, 'Recipe');
      expect(thing.name, 'Carbonara');
      // The curator provenance baked into the JSON-LD is preserved verbatim.
      expect(thing.jsonld, contains('single-tool'));
      expect(thing.jsonld, contains('qwen3-0-6b'));

      final outgoing = await edges.edgesFrom('thing_test');
      expect(outgoing, hasLength(1));
      final edge = outgoing.single;
      expect(edge.object, 'item-1');
      expect(edge.predicate, kIsBasedOnPredicate);
      // The edge itself is the user's assertion.
      expect(edge.provenance, 'user-authored');
      expect(edge.confidence, 0.8);

      expect(await suggestions.byId('sug_1'), isNull);
    });

    test('with an edited doc persists the edit', () async {
      final s = await seed();

      await service.accept(
        s,
        edited: const ThingDoc({'@type': 'Recipe', 'name': 'Spaghetti'}),
      );

      final thing = await things.thingById('thing_test');
      expect(thing!.name, 'Spaghetti');
      expect(await suggestions.byId('sug_1'), isNull);
    });

    test('defaults the new Thing id to thing_<micros>', () async {
      final s = await seed();
      final defaulted = SuggestionReviewService(
        things,
        edges,
        suggestions,
        now: () => DateTime.utc(2026, 1, 2),
      );

      await defaulted.accept(s);

      expect(await things.countThings(), 1);
      final edge = (await edges.edgesTo('item-1')).single;
      expect(edge.subject, startsWith('thing_'));
    });
  });

  test('reject deletes the suggestion and writes nothing', () async {
    final s = await seed();

    await service.reject(s.id);

    expect(await suggestions.byId('sug_1'), isNull);
    expect(await things.countThings(), 0);
    expect(await edges.countEdges(), 0);
  });

  test('postSuggestionNotification writes an ai entry deep-linking to the '
      'review surface', () async {
    final repo = NotificationsRepository(db);
    final center = NotificationCenter(repo, () async => const SettingsModel());

    await postSuggestionNotification(
      center,
      itemId: 'item-1',
      title: 'Easy Carbonara',
      type: 'Recipe',
    );

    final entry = (await repo.watchFeed().first).single;
    expect(entry.category, NotificationCategory.ai);
    expect(entry.title, 'Confirm extracted Recipe?');
    expect(entry.body, 'Easy Carbonara');
    expect(entry.targetRoute, '/item/item-1/suggestions');
    expect(entry.itemId, 'item-1');
    expect(entry.dedupeKey, 'thing_suggest_item-1');
  });
}
