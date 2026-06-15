import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';

void main() {
  late AppDatabase db;
  late ThingSuggestionRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ThingSuggestionRepository(db);
  });
  tearDown(() => db.close());

  ThingSuggestionsCompanion suggestion(
    String id,
    String itemId,
    String type, {
    double? confidence,
  }) => ThingSuggestionsCompanion.insert(
    id: id,
    sourceItemId: itemId,
    type: type,
    jsonld: '{"@type":"$type","name":"x"}',
    confidence: Value(confidence),
    createdAt: DateTime.utc(2026),
  );

  test('insert + pendingForItem round-trips', () async {
    await repo.insert(suggestion('s1', 'item-1', 'Recipe', confidence: 0.7));
    final pending = await repo.pendingForItem('item-1');
    expect(pending, hasLength(1));
    expect(pending.single.type, 'Recipe');
    expect(pending.single.confidence, 0.7);
  });

  test(
    'replaceForItem supersedes prior suggestions (idempotent re-run)',
    () async {
      await repo.insert(suggestion('s1', 'item-1', 'Recipe'));
      await repo.insert(suggestion('s2', 'item-1', 'Event'));
      expect(await repo.pendingForItem('item-1'), hasLength(2));

      await repo.replaceForItem('item-1', [
        suggestion('s3', 'item-1', 'Product'),
      ]);
      final pending = await repo.pendingForItem('item-1');
      expect(pending, hasLength(1));
      expect(pending.single.type, 'Product');
    },
  );

  test('replaceForItem only touches the given item', () async {
    await repo.insert(suggestion('s1', 'item-1', 'Recipe'));
    await repo.insert(suggestion('s2', 'item-2', 'Article'));

    await repo.replaceForItem('item-1', [suggestion('s3', 'item-1', 'Place')]);
    expect(await repo.pendingForItem('item-1'), hasLength(1));
    expect(await repo.pendingForItem('item-2'), hasLength(1));
  });

  test('delete + deleteForItem remove rows', () async {
    await repo.insert(suggestion('s1', 'item-1', 'Recipe'));
    await repo.insert(suggestion('s2', 'item-1', 'Event'));

    await repo.delete('s1');
    expect(await repo.pendingForItem('item-1'), hasLength(1));

    await repo.deleteForItem('item-1');
    expect(await repo.pendingForItem('item-1'), isEmpty);
  });

  test('countPending counts across items', () async {
    await repo.insert(suggestion('s1', 'item-1', 'Recipe'));
    await repo.insert(suggestion('s2', 'item-2', 'Article'));
    expect(await repo.countPending(), 2);
  });

  test('watchForItem emits the item rows', () async {
    await repo.insert(suggestion('s1', 'item-1', 'Recipe'));
    final first = await repo.watchForItem('item-1').first;
    expect(first.single.type, 'Recipe');
  });
}
