import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/domain/chart_mappers.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/chart_message.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/chart_palette.dart';

/// A storage-breakdown donut for a `{label: bytes}` stream provider. One widget
/// serves both the "by type" and "by platform" donuts; small slices fold into
/// "Other" via [buildDonut]. Renders honest empty / loading / error states.
class StorageDonutTile extends ConsumerWidget {
  const StorageDonutTile({
    required this.provider,
    required this.maxSlices,
    required this.capitalizeLabels,
    super.key,
  });

  final StreamProvider<Map<String, int>> provider;
  final int maxSlices;
  final bool capitalizeLabels;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return switch (async) {
      AsyncError() => ChartMessage(
        icon: Icons.error_outline,
        title: "Couldn't load storage usage",
        onRetry: () => ref.invalidate(provider),
      ),
      AsyncData(:final value) => _donutOrEmpty(
        buildDonut(value, maxSlices: maxSlices),
      ),
      _ => const _DonutSkeleton(),
    };
  }

  Widget _donutOrEmpty(DonutData donut) {
    if (donut.isEmpty) {
      return const ChartMessage(
        icon: Icons.donut_large_outlined,
        title: 'No storage data yet',
      );
    }
    return _Donut(donut: donut, capitalizeLabels: capitalizeLabels);
  }
}

class _Donut extends StatelessWidget {
  const _Donut({required this.donut, required this.capitalizeLabels});

  final DonutData donut;
  final bool capitalizeLabels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    sections: [
                      for (final slice in donut.slices)
                        PieChartSectionData(
                          value: slice.fraction * 100,
                          color: sliceColor(slice.colorIndex, scheme, tokens),
                          radius: 36,
                          title: slice.fraction >= 0.08
                              ? '${(slice.fraction * 100).round()}%'
                              : '',
                          titleStyle: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatBytes(donut.totalBytes),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'total',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spaceLg),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final slice in donut.slices)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
                    child: _LegendRow(
                      color: sliceColor(slice.colorIndex, scheme, tokens),
                      label: _label(slice.label),
                      bytes: slice.bytes,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _label(String raw) {
    if (!capitalizeLabels || raw.isEmpty) return raw;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.bytes,
  });

  final Color color;
  final String label;
  final int bytes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(tokens.radiusSm),
          ),
        ),
        SizedBox(width: tokens.spaceSm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        SizedBox(width: tokens.spaceSm),
        Text(
          formatBytes(bytes),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DonutSkeleton extends StatelessWidget {
  const _DonutSkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Row(
          children: [
            const Expanded(
              flex: 2,
              child: Center(
                child: Skeleton(
                  width: 110,
                  height: 110,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            SizedBox(width: tokens.spaceLg),
            Expanded(
              flex: 3,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: tokens.spaceXs),
                      child: Skeleton(height: 12, radius: tokens.radiusSm),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
