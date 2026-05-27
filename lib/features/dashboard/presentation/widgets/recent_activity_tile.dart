import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/notifications/presentation/notification_style.dart';

/// A compact Dashboard tile showing the most recent activity-inbox entries
/// (P11b). Auto-hides when the feed is empty so a quiet app shows only stats.
class RecentActivityTile extends ConsumerWidget {
  const RecentActivityTile({this.cap = 4, super.key});

  final int cap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final entries =
        ref.watch(notificationFeedProvider).asData?.value ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final shown = entries.take(cap).toList();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: SectionHeader(
                'Recent activity',
                icon: Icons.bolt_outlined,
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: tokens.spaceSm),
              child: TextButton(
                onPressed: () => context.push('/inbox'),
                child: const Text('See all'),
              ),
            ),
          ],
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceSm,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final n in shown)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      severityStyle(scheme, n.severity).icon,
                      color: severityStyle(scheme, n.severity).fg,
                    ),
                    title: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(
                      relativeTime(n.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    onTap: () => context.push(n.targetRoute ?? '/inbox'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
