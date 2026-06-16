import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/media_object_projection.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_hydration.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/core/things/vocabulary_edges.dart';

/// Read providers for the P15e Things Browser. Hand-written — they return Drift
/// generated row types (`Thing`/`ThingEdge`) and the `ThingTypeCount` record
/// (CLAUDE.md §8).

/// Things per distinct `@type`, most-populous first — the Browser's facet chips.
final thingTypeCountsProvider = StreamProvider<List<ThingTypeCount>>(
  (ref) => ref.watch(thingRepositoryProvider).watchTypeCounts(),
);

/// All Things, most-recently-updated first — the Browser's "All" facet.
final allThingsProvider = StreamProvider<List<Thing>>(
  (ref) => ref.watch(thingRepositoryProvider).watchAllThings(),
);

/// Things of one schema.org `@type`, most-recently-updated first.
final thingsByTypeProvider = StreamProvider.family<List<Thing>, String>(
  (ref, type) => ref.watch(thingRepositoryProvider).watchThingsByType(type),
);

/// Things matching a case-insensitive substring of their `name`/`type` (P16d),
/// most-recently-updated first — the Browser's search results.
final thingsSearchProvider = StreamProvider.family<List<Thing>, String>(
  (ref, query) => ref.watch(thingRepositoryProvider).watchThingsSearch(query),
);

/// One Thing by id (one-shot; autoDispose so it refreshes each open and leaves no
/// pending Drift query timer).
final thingByIdProvider = FutureProvider.autoDispose.family<Thing?, String>(
  (ref, id) => ref.watch(thingRepositoryProvider).thingById(id),
);

/// Outgoing authored edges from a Thing (e.g. a Recipe's `isBasedOn` link to its
/// source media leaf) — the Thing-detail "Based on" section. One-shot, autoDispose.
final thingEdgesFromProvider = FutureProvider.autoDispose
    .family<List<ThingEdge>, String>(
      (ref, subject) =>
          ref.watch(thingEdgeRepositoryProvider).edgesFrom(subject),
    );

/// One linked node in a Thing's relationships (P16d/P16e): the [predicate] of the
/// edge and the hydrated target/source [node]. [authored] marks a stored authored
/// edge (deletable; vocabulary edges are derived and not), with its raw
/// [subjectId]/[objectId] for unambiguous deletion and any authored [note].
class ThingRelation {
  const ThingRelation(
    this.predicate,
    this.node, {
    this.authored = false,
    this.subjectId,
    this.objectId,
    this.note,
  });
  final String predicate;
  final HydratedNode node;
  final bool authored;
  final String? subjectId;
  final String? objectId;
  final String? note;
}

/// A Thing's relationships for the detail screen (P16d): its outgoing/incoming
/// **authored** edges and its derived **vocabulary** (`mentions`) edges, each with
/// its target hydrated to a real name/type.
class ThingRelationships {
  const ThingRelationships({
    required this.outgoing,
    required this.incoming,
    required this.mentions,
  });
  final List<ThingRelation> outgoing;
  final List<ThingRelation> incoming;
  final List<ThingRelation> mentions;

  bool get isEmpty => outgoing.isEmpty && incoming.isEmpty && mentions.isEmpty;
}

/// Hydrated relationships for the Thing [id] (P16d): authored `edgesFrom`
/// (outgoing) + `edgesTo` (incoming) + derived vocabulary edges, resolved through
/// [NodeHydration] in a single batch. Targets that resolve to neither a Thing nor
/// a media item are dropped.
final thingRelationshipsProvider = FutureProvider.autoDispose
    .family<ThingRelationships, String>((ref, id) async {
      final edges = ref.watch(thingEdgeRepositoryProvider);
      final from = await edges.edgesFrom(id);
      final to = await edges.edgesTo(id);

      final thing = await ref.watch(thingRepositoryProvider).thingById(id);
      var vocab = const <VocabularyEdge>[];
      if (thing != null) {
        try {
          vocab = deriveVocabularyEdges(
            id,
            ThingDoc.fromJsonString(thing.jsonld),
          );
        } on FormatException {
          vocab = const [];
        }
      }

      final nodes = {
        for (final n in await ref.watch(nodeHydrationProvider).hydrateNodes([
          ...from.map((e) => e.object),
          ...to.map((e) => e.subject),
          ...vocab.map((e) => e.object),
        ]))
          n.id: n,
      };

      return ThingRelationships(
        // Outgoing authored: this Thing is the subject.
        outgoing: [
          for (final e in from)
            if (nodes[e.object] != null)
              ThingRelation(
                e.predicate,
                nodes[e.object]!,
                authored: true,
                subjectId: id,
                objectId: e.object,
                note: e.note,
              ),
        ],
        // Incoming authored: this Thing is the object.
        incoming: [
          for (final e in to)
            if (nodes[e.subject] != null)
              ThingRelation(
                e.predicate,
                nodes[e.subject]!,
                authored: true,
                subjectId: e.subject,
                objectId: id,
                note: e.note,
              ),
        ],
        // Derived vocabulary references — not deletable.
        mentions: [
          for (final e in vocab)
            if (nodes[e.object] != null)
              ThingRelation(e.predicate, nodes[e.object]!),
        ],
      );
    });

/// Where tapping a [thing] in the Browser goes: a projected **MediaObject**
/// (`VideoObject`/`AudioObject`/`ImageObject`, whose Thing id == `media_items.id`)
/// opens its media item; any other Thing opens the standalone generic render.
String thingDestinationRoute(Thing thing) =>
    kMediaObjectTypes.contains(thing.type)
    ? '/item/${thing.id}'
    : '/thing/${thing.id}';
