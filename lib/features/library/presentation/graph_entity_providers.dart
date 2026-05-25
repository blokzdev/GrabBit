import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/graph/graph_query_provider.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';

// Plain providers (not riverpod_generator): small `.family` futures over the
// graph query service. They return tag names, so codegen isn't required.

/// Suggested tags for an item — co-occurring tags from the graph, minus the tags
/// the item already carries (watched live, so a just-added tag drops out before
/// the graph re-syncs). Empty when the graph is unavailable, so the editor shows
/// no suggestion row.
final tagSuggestionsProvider = FutureProvider.family<List<String>, String>((
  ref,
  itemId,
) async {
  final counts = await ref
      .watch(graphQueryServiceProvider)
      .coOccurringTags(itemId);
  if (counts.isEmpty) return const [];
  final existing = {
    for (final t in await ref.watch(tagsForItemProvider(itemId).future)) t.name,
  };
  return [
    for (final c in counts)
      if (!existing.contains(c.tag)) c.tag,
  ];
});

/// Tags that co-occur with an entity hub (`uploader` | `site` | `playlist` |
/// `tag`), as names for navigable chips. Empty when the graph is unavailable, so
/// the hub shows no related-tags strip.
final relatedTagsProvider =
    FutureProvider.family<List<String>, ({String type, String value})>((
      ref,
      key,
    ) async {
      final counts = await ref
          .watch(graphQueryServiceProvider)
          .relatedTags(key.type, key.value);
      return [for (final c in counts) c.tag];
    });
