import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/storage/disk_space_service.dart';
import 'package:grabbit/core/storage/media_storage.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/data/library_repository.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/data/storage_maintenance.dart';
import 'package:grabbit/features/library/presentation/media_actions.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Device free/total bytes for the volume holding the private media dir (P9f).
final deviceDiskSpaceProvider = FutureProvider<DiskSpace>((ref) async {
  final dir = await ref.watch(mediaStorageProvider).mediaDirectory();
  return ref.watch(diskSpaceServiceProvider).query(dir.path);
});

/// Storage usage breakdown + cleanup (delete largest, find duplicates) (P9b-3).
class StorageScreen extends ConsumerWidget {
  const StorageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final byType = ref.watch(sizeByTypeProvider);
    final bySite = ref.watch(sizeBySiteProvider);
    final largest = ref.watch(largestItemsProvider);

    final Widget body;
    if (byType.hasError || bySite.hasError || largest.hasError) {
      body = ErrorView(
        message:
            'Failed to load storage usage: '
            '${byType.error ?? bySite.error ?? largest.error}',
        onRetry: () {
          ref.invalidate(sizeByTypeProvider);
          ref.invalidate(sizeBySiteProvider);
          ref.invalidate(largestItemsProvider);
          ref.invalidate(deviceDiskSpaceProvider);
        },
      );
    } else if (!byType.hasValue || !bySite.hasValue || !largest.hasValue) {
      body = const _StorageSkeleton();
    } else {
      body = _content(
        context,
        ref,
        byType.value!,
        bySite.value!,
        largest.value!,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Storage & cleanup')),
      body: ContentBounds(
        child: AnimatedSwitcher(duration: tokens.motionMedium, child: body),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    WidgetRef ref,
    Map<String, int> byType,
    Map<String, int> bySite,
    List<MediaItem> largest,
  ) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final total = byType.values.fold<int>(0, (a, b) => a + b);
    final device = ref.watch(deviceDiskSpaceProvider).asData?.value;

    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('GrabBit uses', style: theme.textTheme.labelMedium),
              Text(formatBytes(total), style: theme.textTheme.headlineMedium),
              if (device != null) ...[
                SizedBox(height: tokens.spaceMd),
                _DeviceSpace(
                  freeBytes: device.freeBytes,
                  totalBytes: device.totalBytes,
                ),
              ],
            ],
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services_outlined),
          title: const Text('Clean up leftover files'),
          subtitle: const Text('Remove orphaned files left by past deletions'),
          onTap: () => _cleanup(context, ref),
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
    );
  }

  Future<void> _cleanup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: 'Clean up leftover files?',
      message:
          'Removes files left on disk by past deletions. Your library items '
          'are not affected.',
      confirmLabel: 'Clean up',
    );
    if (!ok) return;
    final result = await ref.read(storageMaintenanceProvider).cleanupOrphans();
    ref.invalidate(deviceDiskSpaceProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.files == 0
                ? 'No leftover files found'
                : 'Reclaimed ${formatBytes(result.bytes)} '
                      'from ${result.files} file'
                      '${result.files == 1 ? '' : 's'}',
          ),
        ),
      );
  }
}

/// Loading placeholder mirroring the usage screen: a "GrabBit uses" header and
/// a handful of usage-bar rows.
class _StorageSkeleton extends StatelessWidget {
  const _StorageSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: ListView(
        children: [
          Padding(
            padding: EdgeInsets.all(tokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(width: 80, height: 12),
                SizedBox(height: tokens.spaceSm),
                const Skeleton(width: 160, height: 28),
              ],
            ),
          ),
          for (var i = 0; i < 6; i++)
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                tokens.spaceSm,
                tokens.spaceLg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Skeleton(width: 100, height: 12),
                      Skeleton(width: 48, height: 12),
                    ],
                  ),
                  SizedBox(height: tokens.spaceXs),
                  const Skeleton(height: 6, radius: 3),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "X used of Y (Z free)" with a usage bar for the whole device volume.
class _DeviceSpace extends StatelessWidget {
  const _DeviceSpace({required this.freeBytes, required this.totalBytes});
  final int freeBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final used = (totalBytes - freeBytes).clamp(0, totalBytes);
    final fraction = totalBytes == 0 ? 0.0 : used / totalBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device: ${formatBytes(used)} used of ${formatBytes(totalBytes)} '
          '(${formatBytes(freeBytes)} free)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: tokens.spaceXs),
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          child: LinearProgressIndicator(
            value: fraction.toDouble(),
            minHeight: 6,
          ),
        ),
      ],
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
      onLongPress: () => showMediaActions(context, ref, item),
    );
  }
}
