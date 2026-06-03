import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Dashboard entry into "Ask your library". Shown whenever the graph index is
/// available and the library is non-empty. On a generation-capable tier it opens
/// the full GraphRAG chat (`/ask`); on a low/ineligible tier (no generation
/// model) it opens the retrieval-only **"most relevant items"** fallback
/// (`/ask/relevant`, P13d-3). Auto-hides when the graph is unavailable or the
/// library is empty.
class AskEntryTile extends ConsumerWidget {
  const AskEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(graphStoreProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final items = ref.watch(libraryItemsProvider).asData?.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final canGenerate = ref.watch(activeGenerationModelProvider) != null;
    final count = items.length;
    final noun = count == 1 ? 'item' : 'items';
    final subtitle = canGenerate
        ? 'Ask a question about your $count $noun'
        : 'Find the most relevant items in your $count $noun';

    final scheme = Theme.of(context).colorScheme;
    final tokens = GrabBitTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Ask', icon: Icons.auto_awesome_outlined),
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
                child: const Icon(Icons.auto_awesome_outlined),
              ),
              title: const Text('Ask your library'),
              subtitle: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(canGenerate ? '/ask' : '/ask/relevant'),
            ),
          ),
        ),
      ],
    );
  }
}
