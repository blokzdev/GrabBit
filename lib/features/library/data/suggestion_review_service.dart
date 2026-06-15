import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';

/// schema.org "derived from" — the predicate linking an extracted Thing back to
/// the source MediaObject it was curated out of. Richer than the default
/// `relatedTo`; arbitrary predicates are first-class in `thing_edges`.
const String kIsBasedOnPredicate = 'isBasedOn';

/// Turns a confirmed (or rejected) pending suggestion into a canonical-store write
/// (P15d) — the point where curator output becomes part of the library, **only by
/// user consent** ("suggest-don't-assert", ADR-0004).
///
/// On [accept] the suggestion's JSON-LD is asserted as its **own** Thing (id
/// `thing_<micros>`, distinct from the source MediaObject whose Thing id ==
/// `media_items.id`) and linked back with an authored `isBasedOn` edge. The Thing
/// keeps the curator provenance baked into its JSON-LD; the **edge** is
/// `userAuthored` — the user asserted the link. On [reject] the suggestion is
/// discarded and nothing reaches `things`/`thing_edges`.
class SuggestionReviewService {
  SuggestionReviewService(
    this._things,
    this._edges,
    this._suggestions, {
    DateTime Function() now = DateTime.now,
    String Function()? newThingId,
  }) : _newThingId =
           newThingId ?? (() => 'thing_${now().microsecondsSinceEpoch}');

  final ThingRepository _things;
  final ThingEdgeRepository _edges;
  final ThingSuggestionRepository _suggestions;
  final String Function() _newThingId;

  /// Asserts [suggestion] (or its [edited] form) into the canonical store and
  /// links it to its source item, then removes the pending suggestion.
  Future<void> accept(ThingSuggestion suggestion, {ThingDoc? edited}) async {
    final doc = edited ?? ThingDoc.fromJsonString(suggestion.jsonld);
    final id = _newThingId();
    await _things.upsertThing(id, doc);
    await _edges.upsertEdge(
      subject: id,
      object: suggestion.sourceItemId,
      predicate: kIsBasedOnPredicate,
      provenance: Provenance.userAuthored,
      confidence: suggestion.confidence,
    );
    await _suggestions.delete(suggestion.id);
  }

  /// Discards a pending suggestion without writing anything to the graph.
  Future<void> reject(String id) => _suggestions.delete(id);
}

/// The user-facing properties of a candidate Thing — every key except the JSON-LD
/// keywords (`@type`, `@context`, …) and GrabBit's `grabbit:` extension block.
/// Scalars stringify; lists comma-join. Empty values are dropped. Used both to
/// render the review card and to seed its inline editor.
List<MapEntry<String, String>> suggestionDisplayFields(ThingDoc doc) {
  final out = <MapEntry<String, String>>[];
  doc.json.forEach((key, value) {
    if (key.startsWith('@') || key.startsWith('grabbit:')) return;
    final formatted = _formatValue(value);
    if (formatted.isEmpty) return;
    out.add(MapEntry(key, formatted));
  });
  return out;
}

String _formatValue(Object? value) {
  if (value is List) {
    return value.map(_scalar).where((s) => s.isNotEmpty).join(', ');
  }
  return _scalar(value);
}

String _scalar(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    return (value['name'] ?? value['@id'] ?? '').toString().trim();
  }
  return value.toString().trim();
}

/// Posts the actionable Activity-Inbox entry that deep-links to the confirmation
/// surface for [itemId]. Shared so P15f auto-extract reuses the exact wording and
/// dedupe behavior. Coalesces per item via [dedupeKey] so re-extracting resurfaces
/// the same entry rather than stacking duplicates.
Future<void> postSuggestionNotification(
  NotificationCenter center, {
  required String itemId,
  required String title,
  required String type,
}) async {
  await center.post(
    category: NotificationCategory.ai,
    severity: NotificationSeverity.info,
    title: 'Confirm extracted $type?',
    body: title,
    targetRoute: '/item/$itemId/suggestions',
    itemId: itemId,
    dedupeKey: 'thing_suggest_$itemId',
  );
}

final suggestionReviewServiceProvider = Provider<SuggestionReviewService>(
  (ref) => SuggestionReviewService(
    ref.watch(thingRepositoryProvider),
    ref.watch(thingEdgeRepositoryProvider),
    ref.watch(thingSuggestionRepositoryProvider),
  ),
);

/// Live pending suggestions for an item, newest first. Hand-written — it returns
/// the Drift generated `ThingSuggestion` row type (CLAUDE.md §8).
final suggestionsForItemProvider =
    StreamProvider.family<List<ThingSuggestion>, String>(
      (ref, itemId) =>
          ref.watch(thingSuggestionRepositoryProvider).watchForItem(itemId),
    );
