import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/rediscover_provider.dart';

/// A horizontal strip of **central-but-stale** media — items woven into the
/// library graph that haven't been opened lately (P13e-2). Mirrors
/// `RecentMediaRow`, but fed by the graph-derived `rediscoverProvider`; auto-
/// hides when empty (small/new library, or the graph is unavailable).
class RediscoverRow extends ConsumerWidget {
  const RediscoverRow({this.cap = 12, super.key});

  final int cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final items = ref.watch(rediscoverProvider).asData?.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();

    final shown = items.take(cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Rediscover', icon: Icons.auto_awesome_motion),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
            itemCount: shown.length,
            separatorBuilder: (_, _) => SizedBox(width: tokens.spaceMd),
            itemBuilder: (_, i) =>
                SizedBox(width: 124, child: MediaTile(item: shown[i])),
          ),
        ),
      ],
    );
  }
}
