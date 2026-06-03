import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Dashboard entry into the "Ask your library" GraphRAG chat (P13d-2a). Shown
/// only when generation is eligible for this device tier, the graph index is
/// available, and the library is non-empty — i.e. the full generate-and-cite
/// path can run (or be set up). Low/ineligible tiers get the retrieval-only
/// fallback in d-3; until then the entry simply auto-hides there.
class AskEntryTile extends ConsumerWidget {
  const AskEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(activeGenerationModelProvider) == null) {
      return const SizedBox.shrink();
    }
    if (!ref.watch(graphStoreProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final items = ref.watch(libraryItemsProvider).asData?.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

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
                'Ask a question about your ${items.length} '
                '${items.length == 1 ? 'item' : 'items'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/ask'),
            ),
          ),
        ),
      ],
    );
  }
}
