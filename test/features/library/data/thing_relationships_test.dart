import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    final things = ThingRepository(db);
    final edges = ThingEdgeRepository(db);

    // 'src' is a Recipe that vocabulary-references 'tgt' via `about`.
    await things.upsertThing(
      'src',
      const ThingDoc({
        '@type': 'Recipe',
        'name': 'Carbonara',
        'about': {'@id': 'tgt'},
      }),
    );
    await things.upsertThing(
      'tgt',
      const ThingDoc({'@type': 'Article', 'name': 'My Article'}),
    );
    await things.upsertThing(
      'other',
      const ThingDoc({'@type': 'Place', 'name': 'Friend'}),
    );
    await db
        .into(db.mediaItems)
        .insert(
          MediaItemsCompanion.insert(
            id: 'med',
            title: 'Clip',
            sourceUrl: 'https://x/med',
            site: 'youtube',
            filePath: '/tmp/med.mp4',
            type: 'video',
            createdAt: DateTime.utc(2026),
            storageState: 'private',
          ),
        );

    // Outgoing authored → a media leaf; an incoming authored from 'other';
    // and a dangling outgoing edge that must be dropped.
    await edges.upsertEdge(
      subject: 'src',
      object: 'med',
      predicate: 'isBasedOn',
      provenance: Provenance.userAuthored,
    );
    await edges.upsertEdge(
      subject: 'other',
      object: 'src',
      predicate: 'relatedTo',
      provenance: Provenance.userAuthored,
    );
    await edges.upsertEdge(
      subject: 'src',
      object: 'ghost',
      predicate: 'relatedTo',
      provenance: Provenance.userAuthored,
    );
  });

  Future<ThingRelationships> rel(String id) =>
      container.read(thingRelationshipsProvider(id).future);

  test(
    'outgoing authored edges hydrate, dangling targets are dropped',
    () async {
      final r = await rel('src');
      expect(r.outgoing, hasLength(1)); // 'ghost' dropped
      expect(r.outgoing.single.predicate, 'isBasedOn');
      expect(r.outgoing.single.node.id, 'med');
      expect(r.outgoing.single.node.title, 'Clip');
      expect(r.outgoing.single.node.media, isNotNull); // routes to /item/
    },
  );

  test('incoming authored edges hydrate to the source Thing', () async {
    final r = await rel('src');
    expect(r.incoming, hasLength(1));
    expect(r.incoming.single.node.id, 'other');
    expect(r.incoming.single.node.title, 'Friend');
    expect(r.incoming.single.node.media, isNull); // routes to /thing/
  });

  test('vocabulary (@id) references surface as mentions', () async {
    final r = await rel('src');
    expect(r.mentions, hasLength(1));
    expect(r.mentions.single.predicate, 'about');
    expect(r.mentions.single.node.id, 'tgt');
    expect(r.mentions.single.node.title, 'My Article');
  });

  test('a Thing with no edges has empty relationships', () async {
    final r = await rel('tgt');
    expect(r.isEmpty, isTrue);
  });
}
