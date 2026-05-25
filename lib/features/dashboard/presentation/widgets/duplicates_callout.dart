import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/dedupe_actions.dart';

/// Dashboard duplicates callout: a distinct, actionable card shown only when
/// exact duplicates exist. **Review** opens the Duplicates screen (cleanup lives
/// there / in Collections). Pure Drift — present on every device.
class DuplicatesCallout extends ConsumerWidget {
  const DuplicatesCallout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups =
        ref.watch(duplicatesProvider).asData?.value ??
        const <List<MediaItem>>[];
    if (groups.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final extra = duplicatesToRemove(groups).length;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceSm,
      ),
      child: Card(
        color: scheme.tertiaryContainer,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.content_copy_outlined,
                    color: scheme.onTertiaryContainer,
                  ),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Duplicates',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          '${groups.length} group${groups.length == 1 ? '' : 's'} · '
                          '$extra extra cop${extra == 1 ? 'y' : 'ies'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceSm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => context.push('/duplicates'),
                  child: const Text('Review'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
