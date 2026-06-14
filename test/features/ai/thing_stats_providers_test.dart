import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/features/ai/data/thing_stats_providers.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> addThing(String id) => db
      .into(db.things)
      .insert(
        ThingsCompanion.insert(
          id: id,
          type: 'VideoObject',
          jsonld: '{"@type":"VideoObject"}',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
      );

  test('reports the Things + authored-edge counts', () async {
    await addThing('a');
    await addThing('b');
    await db
        .into(db.thingEdges)
        .insert(
          ThingEdgesCompanion.insert(
            subject: 'a',
            predicate: 'relatedTo',
            object: 'b',
            provenance: 'user-authored',
            createdAt: DateTime.utc(2026),
          ),
        );
    final c = container();
    expect(await c.read(thingCountProvider.future), 2);
    expect(await c.read(thingEdgeCountProvider.future), 1);
  });

  test('zero on an empty library', () async {
    final c = container();
    expect(await c.read(thingCountProvider.future), 0);
    expect(await c.read(thingEdgeCountProvider.future), 0);
  });
}
