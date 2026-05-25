import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Dashboard entry into the on-device relationship graph. The graph is per-item,
/// so this seeds on the newest library item and opens the full graph screen.
/// Auto-hides when the graph store is unavailable (non-Android / unsupported
/// ABI) or the library is empty.
class GraphEntryTile extends ConsumerWidget {
  const GraphEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(graphStoreProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final items = ref.watch(libraryItemsProvider).asData?.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final tokens = GrabBitTokens.of(context);
    final MediaItem seed = items.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Explore', icon: Icons.hub_outlined),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceSm,
          ),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: scheme.secondaryContainer,
                foregroundColor: scheme.onSecondaryContainer,
                child: const Icon(Icons.hub_outlined),
              ),
              title: const Text('Explore your library graph'),
              subtitle: Text(
                "See how '${seed.title}' connects",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/item/${seed.id}/graph'),
            ),
          ),
        ),
      ],
    );
  }
}
