import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';

void main() {
  late AppDatabase db;
  late ThingEdgeRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ThingEdgeRepository(db);
  });
  tearDown(() => db.close());

  test('upsertEdge stores an authored edge (relatedTo by default)', () async {
    await repo.upsertEdge(
      subject: 'a',
      object: 'b',
      provenance: Provenance.userAuthored,
      confidence: 0.9,
      note: 'these go together',
    );

    final edges = await repo.edgesFrom('a');
    expect(edges, hasLength(1));
    final e = edges.single;
    expect(e.predicate, kRelatedToPredicate);
    expect(e.object, 'b');
    expect(e.provenance, Provenance.userAuthored.wire);
    expect(e.confidence, 0.9);
    expect(e.note, 'these go together');
  });

  test(
    're-upsert updates provenance/confidence/note, preserves createdAt',
    () async {
      await repo.upsertEdge(
        subject: 'a',
        object: 'b',
        provenance: Provenance.aiSuggested,
        confidence: 0.4,
      );
      final first = (await repo.edgesFrom('a')).single;

      await repo.upsertEdge(
        subject: 'a',
        object: 'b',
        provenance: Provenance.userAuthored,
        confidence: 1,
        note: 'confirmed',
      );
      final second = (await repo.edgesFrom('a')).single;

      expect(await repo.countEdges(), 1); // same composite key, not a duplicate
      expect(second.provenance, Provenance.userAuthored.wire);
      expect(second.confidence, 1.0);
      expect(second.note, 'confirmed');
      expect(second.createdAt, first.createdAt); // preserved
    },
  );

  test('a different predicate is a distinct edge', () async {
    await repo.upsertEdge(
      subject: 'a',
      object: 'b',
      provenance: Provenance.userAuthored,
    );
    await repo.upsertEdge(
      subject: 'a',
      object: 'b',
      predicate: 'about',
      provenance: Provenance.userAuthored,
    );
    expect(await repo.countEdges(), 2);
  });

  test(
    'edgesTo finds incoming edges; watchEdgeCount tracks the total',
    () async {
      await repo.upsertEdge(
        subject: 'a',
        object: 'c',
        provenance: Provenance.userAuthored,
      );
      await repo.upsertEdge(
        subject: 'b',
        object: 'c',
        provenance: Provenance.aiInferred,
      );
      expect((await repo.edgesTo('c')).map((e) => e.subject).toSet(), {
        'a',
        'b',
      });
      expect(await repo.watchEdgeCount().first, 2);
    },
  );

  test('deleteEdge removes exactly the addressed edge', () async {
    await repo.upsertEdge(
      subject: 'a',
      object: 'b',
      provenance: Provenance.userAuthored,
    );
    await repo.deleteEdge('a', kRelatedToPredicate, 'b');
    expect(await repo.edgesFrom('a'), isEmpty);
  });
}
