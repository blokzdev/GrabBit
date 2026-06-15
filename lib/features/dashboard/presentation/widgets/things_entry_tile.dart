import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';

/// Dashboard entry into the P15e Things Browser — the typed graph of schema.org
/// Things (projected media + confirmed extractions). Auto-hides until at least one
/// Thing exists. Available in both UI modes (mirrors `GraphEntryTile`).
class ThingsEntryTile extends ConsumerWidget {
  const ThingsEntryTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeCounts =
        ref.watch(thingTypeCountsProvider).asData?.value ?? const [];
    if (typeCounts.isEmpty) return const SizedBox.shrink();

    final total = typeCounts.fold<int>(0, (sum, c) => sum + c.count);
    final types = typeCounts.length;
    final scheme = Theme.of(context).colorScheme;
    final tokens = GrabBitTokens.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Things', icon: Icons.category_outlined),
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
                child: const Icon(Icons.category_outlined),
              ),
              title: const Text('Browse your Things'),
              subtitle: Text(
                '$total thing${total == 1 ? '' : 's'} across '
                '$types type${types == 1 ? '' : 's'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/things'),
            ),
          ),
        ),
      ],
    );
  }
}
