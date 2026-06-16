import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/library/data/authored_edge_service.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';

void main() {
  late AppDatabase db;
  late ThingRepository things;
  late ThingEdgeRepository edges;
  late AuthoredEdgeService service;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    things = ThingRepository(db);
    edges = ThingEdgeRepository(db);
    service = AuthoredEdgeService(edges, CaptureCommitService(things));
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    addTearDown(db.close);

    await things.upsertThing(
      'a',
      const ThingDoc({'@type': 'Recipe', 'name': 'Carbonara'}),
    );
    await things.upsertThing(
      'b',
      const ThingDoc({'@type': 'Place', 'name': 'Trattoria'}),
    );
  });

  group('buildNoteThing', () {
    test('is a Comment with text + a snippet name + provenance', () {
      final doc = buildNoteThing('  Learned this here  ');
      expect(doc.type, 'Comment');
      expect(doc.json['text'], 'Learned this here');
      expect(doc.json['name'], 'Learned this here');
      final prov = doc.json['grabbit:provenance'] as Map;
      expect(prov['provenance'], 'user-authored');
      expect(prov['sourceRef'], 'authored-note');
    });

    test('truncates a long name to a snippet', () {
      final doc = buildNoteThing('x' * 100);
      expect((doc.json['name'] as String).length, lessThanOrEqualTo(60));
      expect(doc.json['text'], 'x' * 100);
    });
  });

  test('addLink writes a user-authored edge with a note', () async {
    await service.addLink(
      subject: 'a',
      object: 'b',
      predicate: 'similarTo',
      note: 'both Roman',
    );
    final e = (await edges.edgesFrom('a')).single;
    expect(e.object, 'b');
    expect(e.predicate, 'similarTo');
    expect(e.provenance, 'user-authored');
    expect(e.note, 'both Roman');
  });

  test('deleteLink removes the edge', () async {
    await service.addLink(subject: 'a', object: 'b', predicate: 'relatedTo');
    await service.deleteLink('a', 'relatedTo', 'b');
    expect(await edges.edgesFrom('a'), isEmpty);
  });

  test('addNote reifies a Comment linked to both participants', () async {
    final id = await service.addNote(
      subjectId: 'a',
      objectId: 'b',
      text: 'These pair well',
    );

    final comment = await things.thingById(id);
    expect(comment!.type, 'Comment');

    // The note shows on both participants (incoming authored edge from Comment).
    final relA = await container.read(thingRelationshipsProvider('a').future);
    final relB = await container.read(thingRelationshipsProvider('b').future);
    expect(relA.incoming.map((r) => r.node.id), contains(id));
    expect(relB.incoming.map((r) => r.node.id), contains(id));
    expect(relA.incoming.single.predicate, 'about');

    // And the Comment links out to both.
    final relC = await container.read(thingRelationshipsProvider(id).future);
    expect(relC.outgoing.map((r) => r.node.id).toSet(), {'a', 'b'});
  });
}
