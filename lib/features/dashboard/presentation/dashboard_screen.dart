import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/layout/window_size.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/brand_badge.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/domain/dashboard_summary.dart';
import 'package:grabbit/features/dashboard/presentation/dashboard_providers.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/activity_chart_tile.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/duplicates_callout.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/graph_entry_tile.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/recent_media_row.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/stat_card.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/storage_donut_tile.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/suggestions_tile.dart';
import 'package:grabbit/features/library/data/metadata_repository.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/storage_screen.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';

/// The app home (P10d): an at-a-glance view of the on-device footprint —
/// library/queue/collection counts and storage — that drills into each area.
/// Richer charts (P10d-2) and recent/suggestion/graph tiles (P10d-3) build on it.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const _BrandTitle()),
      body: switch (summary) {
        AsyncError(:final error) => ErrorView(
          message: 'Failed to load your dashboard: $error',
          onRetry: () {
            ref.invalidate(libraryItemsProvider);
            ref.invalidate(queueTasksProvider);
            ref.invalidate(collectionsProvider);
          },
        ),
        AsyncData(:final value) => _DashboardBody(summary: value),
        _ => const _DashboardSkeleton(),
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);

    if (summary.isEmpty) {
      return EmptyState(
        icon: Icons.dashboard_customize_outlined,
        title: 'Your dashboard is empty',
        message: 'Download something and your library stats will show up here.',
        action: FilledButton.icon(
          onPressed: () => context.push('/add'),
          icon: const Icon(Icons.add),
          label: const Text('Add a download'),
        ),
      );
    }

    final device = ref.watch(deviceDiskSpaceProvider).asData?.value;
    final String? deviceSubtitle = (device != null && device.totalBytes > 0)
        ? '${formatBytes(device.freeBytes)} free of ${formatBytes(device.totalBytes)}'
        : null;

    final cards = <Widget>[
      StatCard(
        icon: Icons.video_library_outlined,
        value: '${summary.itemCount}',
        label: 'In library',
        onTap: () => context.go('/library'),
      ),
      StatCard(
        icon: Icons.sd_storage_outlined,
        value: formatBytes(summary.usedBytes),
        label: 'Storage used',
        subtitle: deviceSubtitle,
        onTap: () => context.push('/storage'),
      ),
      StatCard(
        icon: Icons.download_outlined,
        value: '${summary.queuePending}',
        label: 'In queue',
        subtitle: summary.queueRunning > 0
            ? '${summary.queueRunning} downloading'
            : null,
        highlight: summary.queueRunning > 0,
        onTap: () => context.go('/queue'),
      ),
      StatCard(
        icon: Icons.collections_bookmark_outlined,
        value: '${summary.collectionCount}',
        label: 'Collections',
        onTap: () => context.go('/collections'),
      ),
    ];

    final columns = _dashboardColumns(WindowSizeClass.of(context));

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: tokens.spaceXl),
      child: ContentBounds(
        maxWidth: 1100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader('Overview', icon: Icons.dashboard_outlined),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: columns,
                mainAxisSpacing: tokens.spaceMd,
                crossAxisSpacing: tokens.spaceMd,
                childAspectRatio: 1.3,
                children: cards,
              ),
            ),
            _ChartSection(
              title: 'Storage by type',
              icon: Icons.donut_small_outlined,
              child: StorageDonutTile(
                provider: sizeByTypeProvider,
                maxSlices: 3,
                capitalizeLabels: true,
              ),
            ),
            _ChartSection(
              title: 'Storage by platform',
              icon: Icons.public,
              child: StorageDonutTile(
                provider: sizeBySiteProvider,
                maxSlices: 5,
                capitalizeLabels: false,
              ),
            ),
            const _ChartSection(
              title: 'Library activity',
              icon: Icons.show_chart,
              child: ActivityChartTile(),
            ),
            RecentMediaRow(
              title: 'Recently added',
              provider: libraryItemsProvider,
              onSeeAll: () => context.go('/library'),
            ),
            RecentMediaRow(
              title: 'Recently opened',
              provider: recentlyPlayedProvider,
            ),
            const SuggestionsTile(),
            const DuplicatesCallout(),
            const GraphEntryTile(),
          ],
        ),
      ),
    );
  }
}

/// A titled, fixed-height card wrapper for a dashboard chart tile.
class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, icon: icon),
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceSm,
          ),
          child: SizedBox(
            height: 220,
            child: Card(clipBehavior: Clip.antiAlias, child: child),
          ),
        ),
      ],
    );
  }
}

/// Stat-card columns per window size class: 2 on phones, 3 on tablets, 4 on
/// desktop-class widths.
int _dashboardColumns(WindowSizeClass size) => switch (size) {
  WindowSizeClass.compact => 2,
  WindowSizeClass.medium || WindowSizeClass.expanded => 3,
  WindowSizeClass.large || WindowSizeClass.extraLarge => 4,
};

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final columns = _dashboardColumns(WindowSizeClass.of(context));
    return Shimmer(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: GridView.count(
          crossAxisCount: columns,
          mainAxisSpacing: tokens.spaceMd,
          crossAxisSpacing: tokens.spaceMd,
          childAspectRatio: 1.3,
          children: List.generate(4, (_) => Skeleton(radius: tokens.radiusLg)),
        ),
      ),
    );
  }
}

class _BrandTitle extends StatelessWidget {
  const _BrandTitle();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandBadge(),
        SizedBox(width: tokens.spaceSm),
        Text('GrabBit', style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
