import 'dart:async';

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

  /// First emitted count from a live count provider (subscribes to drive it).
  Future<int> firstCount(ProviderContainer c, StreamProvider<int> p) {
    final completer = Completer<int>();
    final sub = c.listen(p, (_, next) {
      if (next is AsyncData<int> && !completer.isCompleted) {
        completer.complete(next.value);
      }
    }, fireImmediately: true);
    return completer.future.whenComplete(sub.close);
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

  test('reports the live Things + authored-edge counts', () async {
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
    expect(await firstCount(c, thingCountProvider), 2);
    expect(await firstCount(c, thingEdgeCountProvider), 1);
  });

  test('zero on an empty library', () async {
    final c = container();
    expect(await firstCount(c, thingCountProvider), 0);
    expect(await firstCount(c, thingEdgeCountProvider), 0);
  });
}
