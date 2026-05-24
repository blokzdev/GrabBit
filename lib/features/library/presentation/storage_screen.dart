import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Storage usage breakdown + cleanup (delete largest, find duplicates) (P9b-3).
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final byType = ref.watch(sizeByTypeProvider).asData?.value ?? const {};
    final bySite = ref.watch(sizeBySiteProvider).asData?.value ?? const {};
    final largest = ref.watch(largestItemsProvider).asData?.value ?? const [];
    final total = byType.values.fold<int>(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & cleanup')),
      body: ContentBounds(
        child: ListView(
          children: [
            Padding(
              padding: EdgeInsets.all(tokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total used', style: theme.textTheme.labelMedium),
                  Text(
                    formatBytes(total),
                    style: theme.textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            const SectionHeader('By type', icon: Icons.category_outlined),
            for (final e in byType.entries)
              _UsageBar(label: e.key, bytes: e.value, total: total),
            const SectionHeader('By platform', icon: Icons.public),
            for (final e in bySite.entries)
              _UsageBar(label: e.key, bytes: e.value, total: total),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined),
              title: const Text('Find duplicates'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/duplicates'),
            ),
            if (largest.isNotEmpty)
              const SectionHeader('Largest items', icon: Icons.data_usage),
            for (final item in largest) _LargestRow(item: item),
            SizedBox(height: tokens.spaceLg),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({
    required this.label,
    required this.bytes,
    required this.total,
  });
  final String label;
  final int bytes;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final fraction = total == 0 ? 0.0 : bytes / total;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(formatBytes(bytes), style: theme.textTheme.bodySmall),
            ],
          ),
          SizedBox(height: tokens.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: LinearProgressIndicator(value: fraction, minHeight: 6),
          ),
        ],
      ),
    );
  }
}

class _LargestRow extends ConsumerWidget {
  const _LargestRow({required this.item});
  final MediaItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    return ListTile(
      leading: SizedBox(
        width: 56,
        height: 40,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: MediaThumb(item: item),
        ),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(formatBytes(item.sizeBytes)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          final ok = await confirm(
            context,
            title: 'Delete this item?',
            message:
                'Permanently removes "${item.title}". This cannot be undone.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (!ok) return;
          final secure =
              ref.read(settingsControllerProvider).asData?.value.secureDelete ??
              false;
          await ref
              .read(libraryRepositoryProvider)
              .deleteItem(item, secure: secure);
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Deleted')));
        },
      ),
      onTap: () => context.push('/item/${item.id}'),
    );
  }
}
