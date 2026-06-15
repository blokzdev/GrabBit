import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';

/// P15e — the Things Browser. Browses + filters the on-device graph of schema.org
/// Things by `@type` (facet chips with counts) and opens each Thing's render: a
/// projected MediaObject opens its media item, any other Thing opens the standalone
/// generic render. Available in both UI modes.
class ThingsBrowserScreen extends ConsumerStatefulWidget {
  const ThingsBrowserScreen({super.key});

  @override
  ConsumerState<ThingsBrowserScreen> createState() =>
      _ThingsBrowserScreenState();
}

class _ThingsBrowserScreenState extends ConsumerState<ThingsBrowserScreen> {
  // null = the "All" facet.
  String? _selectedType;

  @override
  Widget build(BuildContext context) {
    final counts = ref.watch(thingTypeCountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Things')),
      body: ContentBounds(
        child: AsyncFade(
          value: counts,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: 'Failed to load Things: $e',
            onRetry: () => ref.invalidate(thingTypeCountsProvider),
          ),
          data: (typeCounts) {
            if (typeCounts.isEmpty) {
              return const EmptyState(
                icon: Icons.category_outlined,
                title: 'No Things yet',
                message:
                    'Download media and extract Things from an item, or rebuild '
                    'the library, and your typed graph will show up here.',
              );
            }
            // Drop a stale selection (e.g. its last Thing was removed).
            final selected =
                _selectedType != null &&
                    typeCounts.any((c) => c.type == _selectedType)
                ? _selectedType
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _FacetChips(
                  typeCounts: typeCounts,
                  selected: selected,
                  onSelect: (type) => setState(() => _selectedType = type),
                ),
                Expanded(child: _ThingList(type: selected)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FacetChips extends StatelessWidget {
  const _FacetChips({
    required this.typeCounts,
    required this.selected,
    required this.onSelect,
  });

  final List<ThingTypeCount> typeCounts;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final total = typeCounts.fold<int>(0, (sum, c) => sum + c.count);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceSm,
      ),
      child: Row(
        children: [
          ChoiceChip(
            label: Text('All ($total)'),
            selected: selected == null,
            onSelected: (_) => onSelect(null),
          ),
          for (final c in typeCounts) ...[
            SizedBox(width: tokens.spaceSm),
            ChoiceChip(
              label: Text('${c.type} (${c.count})'),
              selected: selected == c.type,
              onSelected: (_) => onSelect(c.type),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThingList extends ConsumerWidget {
  const _ThingList({required this.type});

  final String? type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final things = type == null
        ? ref.watch(allThingsProvider)
        : ref.watch(thingsByTypeProvider(type!));
    return AsyncFade(
      value: things,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(message: 'Failed to load Things: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.category_outlined,
            title: 'Nothing here',
            message: 'No Things of this type.',
          );
        }
        return ListView.builder(
          padding: EdgeInsets.symmetric(vertical: tokens.spaceSm),
          itemCount: list.length,
          itemBuilder: (context, i) => _ThingTile(thing: list[i]),
        );
      },
    );
  }
}

class _ThingTile extends StatelessWidget {
  const _ThingTile({required this.thing});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(iconForThingType(thing.type)),
      ),
      title: Text(
        thing.name ?? thing.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(thing.type),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(thingDestinationRoute(thing)),
    );
  }
}

/// A schema.org `@type` → Material icon mapping for the Browser (the curated
/// priority types + MediaObject leaves; a neutral default for the long tail).
IconData iconForThingType(String type) => switch (type) {
  'VideoObject' => Icons.movie_outlined,
  'AudioObject' => Icons.audiotrack_outlined,
  'ImageObject' => Icons.image_outlined,
  'Recipe' => Icons.restaurant_outlined,
  'Event' => Icons.event_outlined,
  'Place' => Icons.place_outlined,
  'Article' => Icons.article_outlined,
  'Product' => Icons.shopping_bag_outlined,
  'Book' => Icons.menu_book_outlined,
  'Person' => Icons.person_outlined,
  _ => Icons.category_outlined,
};
