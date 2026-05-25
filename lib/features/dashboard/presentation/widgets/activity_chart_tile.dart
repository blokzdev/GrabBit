import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/dashboard/domain/chart_mappers.dart';
import 'package:grabbit/features/dashboard/presentation/widgets/chart_message.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

/// Library additions over the last 30 days as a bar chart. Durable, on-device
/// (driven by `MediaItem.createdAt`). Honest empty / loading / error states.
class ActivityChartTile extends ConsumerWidget {
  const ActivityChartTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(libraryItemsProvider);
    return switch (async) {
      AsyncError() => ChartMessage(
        icon: Icons.error_outline,
        title: "Couldn't load activity",
        onRetry: () => ref.invalidate(libraryItemsProvider),
      ),
      AsyncData(:final value) => _chartOrEmpty(
        buildActivitySeries(value, now: DateTime.now()),
      ),
      _ => const _ActivitySkeleton(),
    };
  }

  Widget _chartOrEmpty(ActivitySeries series) {
    if (series.isEmpty) {
      return const ChartMessage(
        icon: Icons.show_chart,
        title: 'No activity yet',
      );
    }
    return _ActivityChart(series: series);
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.series});

  final ActivitySeries series;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final scheme = theme.colorScheme;
    final buckets = series.buckets;

    final maxCount = buckets.fold<int>(0, (a, b) => math.max(a, b.count));
    final step = math.max(1, (maxCount / 4).ceil());
    final maxY = (maxCount + 1).toDouble();
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceMd,
        tokens.spaceLg,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceBetween,
          barTouchData: const BarTouchData(enabled: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: step.toDouble(),
            getDrawingHorizontalLine: (_) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: step.toDouble(),
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > maxCount) {
                    return const SizedBox.shrink();
                  }
                  return Text('${value.toInt()}', style: labelStyle);
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= buckets.length) {
                    return const SizedBox.shrink();
                  }
                  // Weekly ticks anchored to the newest day.
                  if ((buckets.length - 1 - i) % 7 != 0) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(top: tokens.spaceXs),
                    child: Text(
                      DateFormat.MMMd().format(buckets[i].start),
                      style: labelStyle,
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < buckets.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: buckets[i].count.toDouble(),
                    color: scheme.primary,
                    width: 6,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(tokens.radiusSm / 2),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActivitySkeleton extends StatelessWidget {
  const _ActivitySkeleton();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final h in const [40.0, 70.0, 30.0, 90.0, 55.0, 75.0, 45.0])
              Skeleton(width: 10, height: h, radius: tokens.radiusSm),
          ],
        ),
      ),
    );
  }
}
