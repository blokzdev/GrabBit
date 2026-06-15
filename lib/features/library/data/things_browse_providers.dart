import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/media_object_projection.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';

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

/// Where tapping a [thing] in the Browser goes: a projected **MediaObject**
/// (`VideoObject`/`AudioObject`/`ImageObject`, whose Thing id == `media_items.id`)
/// opens its media item; any other Thing opens the standalone generic render.
String thingDestinationRoute(Thing thing) =>
    kMediaObjectTypes.contains(thing.type)
    ? '/item/${thing.id}'
    : '/thing/${thing.id}';
