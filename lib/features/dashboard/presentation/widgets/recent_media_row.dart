import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// A horizontal strip of recent media tiles for the Dashboard, fed by any
/// `List<MediaItem>` stream provider (recently added / recently opened). Auto-
/// hides when the source is empty so a fresh library shows only the stats/charts.
class RecentMediaRow extends ConsumerWidget {
  const RecentMediaRow({
    required this.title,
    required this.provider,
    this.onSeeAll,
    this.cap = 12,
    super.key,
  });

  final String title;
  final StreamProvider<List<MediaItem>> provider;
  final VoidCallback? onSeeAll;
  final int cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final items = ref.watch(provider).asData?.value ?? const <MediaItem>[];
    if (items.isEmpty) return const SizedBox.shrink();

    final shown = items.take(cap).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionHeader(title)),
            if (onSeeAll != null)
              Padding(
                padding: EdgeInsets.only(right: tokens.spaceSm),
                child: TextButton(
                  onPressed: onSeeAll,
                  child: const Text('See all'),
                ),
              ),
          ],
        ),
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
