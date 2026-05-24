import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/share/external_share_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/utils/duration_format.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/queue/data/queue_repository.dart';
import 'package:grabbit/features/queue/presentation/queue_controller.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ensure the scheduler is alive (reconciles + pumps on first build).
    ref.watch(queueControllerProvider);
    final tasks = ref.watch(queueTasksProvider);
    final controller = ref.read(queueControllerProvider.notifier);
    final rows = tasks.asData?.value ?? const [];
    final heldCount = rows.where((t) => t.status == TaskStatus.held).length;
    final runningCount = rows
        .where((t) => t.status == TaskStatus.running)
        .length;
    final pausedCount = rows.where((t) => t.status == TaskStatus.paused).length;
    final completedCount = rows
        .where(
          (t) => t.status == TaskStatus.done || t.status == TaskStatus.canceled,
        )
        .length;
    final failedCount = rows.where((t) => t.status == TaskStatus.error).length;
    final activeCount = rows
        .where(
          (t) =>
              t.status == TaskStatus.running ||
              t.status == TaskStatus.queued ||
              t.status == TaskStatus.held ||
              t.status == TaskStatus.paused,
        )
        .length;
    final finishedCount = completedCount + failedCount;

    return Scaffold(
      appBar: AppBar(
        // Defensive leading: when this screen is the only route (reached via a
        // stack-replacing navigation) there is nothing to pop, so offer Home
        // instead of leaving the user stranded.
        leading: Navigator.of(context).canPop()
            ? const BackButton()
            : IconButton(
                tooltip: 'Home',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => context.go('/'),
              ),
        title: const Text('Queue'),
        actions: [
          if (heldCount > 0)
            TextButton.icon(
              onPressed: () async {
                await controller.startAll();
                if (context.mounted) {
                  _notify(
                    context,
                    'Started $heldCount download'
                    '${heldCount == 1 ? '' : 's'}',
                  );
                }
              },
              icon: const Icon(Icons.play_arrow),
              label: Text('Start all ($heldCount)'),
            ),
          if (pausedCount > 0)
            IconButton(
              tooltip: 'Resume all',
              icon: const Icon(Icons.play_arrow),
              onPressed: controller.resumeAll,
            ),
          if (runningCount > 0)
            IconButton(
              tooltip: 'Pause all',
              icon: const Icon(Icons.pause),
              onPressed: controller.pauseAll,
            ),
          if (completedCount > 0)
            IconButton(
              tooltip: 'Clear completed',
              icon: const Icon(Icons.clear_all),
              onPressed: () async {
                final n = await controller.clearCompleted();
                if (context.mounted) {
                  _notify(context, 'Cleared $n completed');
                }
              },
            ),
          if (failedCount > 0 || activeCount > 0 || finishedCount > 0)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (value) async {
                switch (value) {
                  case 'retry':
                    await controller.retryAllFailed();
                  case 'cancel':
                    await controller.cancelAll();
                    if (context.mounted) _notify(context, 'Canceled all');
                  case 'clear':
                    final n = await controller.clearFinished();
                    if (context.mounted) _notify(context, 'Cleared $n');
                }
              },
              itemBuilder: (context) => [
                if (failedCount > 0)
                  const PopupMenuItem(
                    value: 'retry',
                    child: Text('Retry all failed'),
                  ),
                if (activeCount > 0)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Cancel all'),
                  ),
                if (finishedCount > 0)
                  const PopupMenuItem(
                    value: 'clear',
                    child: Text('Clear finished'),
                  ),
              ],
            ),
        ],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: tasks,
          loading: () => const ListSkeleton(),
          error: (e, _) => ErrorView(
            message: 'Failed to load queue: $e',
            onRetry: () => ref.invalidate(queueTasksProvider),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  icon: Icons.download_done_outlined,
                  title: 'No downloads in the queue',
                  message: 'Links you add will download here.',
                )
              : Column(
                  children: [
                    const _PauseBanner(),
                    _QueueDashboard(rows: rows),
                    _QueueSummary(rows: rows),
                    Expanded(
                      child: ReorderableListView.builder(
                        padding: EdgeInsets.zero,
                        buildDefaultDragHandles: true,
                        itemCount: rows.length,
                        onReorderItem: (oldIndex, newIndex) =>
                            controller.reorder(oldIndex, newIndex),
                        itemBuilder: (context, i) =>
                            _TaskTile(key: ValueKey(rows[i].id), task: rows[i]),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Visual style (container/on-container colors + glyph) for a task status,
/// shared by the summary pills and the per-task status avatars.
({Color bg, Color fg, IconData icon}) _statusStyle(
  ColorScheme s,
  String status,
) => switch (status) {
  TaskStatus.running => (
    bg: s.primaryContainer,
    fg: s.onPrimaryContainer,
    icon: Icons.download,
  ),
  TaskStatus.queued => (
    bg: s.secondaryContainer,
    fg: s.onSecondaryContainer,
    icon: Icons.schedule,
  ),
  TaskStatus.held => (
    bg: s.secondaryContainer,
    fg: s.onSecondaryContainer,
    icon: Icons.inventory_2_outlined,
  ),
  TaskStatus.paused => (
    bg: s.surfaceContainerHighest,
    fg: s.onSurfaceVariant,
    icon: Icons.pause,
  ),
  TaskStatus.done => (
    bg: s.tertiaryContainer,
    fg: s.onTertiaryContainer,
    icon: Icons.check,
  ),
  TaskStatus.canceled => (
    bg: s.surfaceContainerHighest,
    fg: s.onSurfaceVariant,
    icon: Icons.block,
  ),
  TaskStatus.error => (
    bg: s.errorContainer,
    fg: s.onErrorContainer,
    icon: Icons.error_outline,
  ),
  _ => (
    bg: s.surfaceContainerHighest,
    fg: s.onSurfaceVariant,
    icon: Icons.help_outline,
  ),
};

/// A one-line notice when a safety gate is holding downloads back (P9f).
/// Hidden when nothing is paused.
class _PauseBanner extends ConsumerWidget {
  const _PauseBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reason = ref.watch(queuePauseReasonProvider);
    final (message, icon) = switch (reason) {
      QueuePauseReason.metered => (
        'Paused — waiting for Wi-Fi',
        Icons.wifi_off,
      ),
      QueuePauseReason.lowStorage => (
        'Paused — low storage',
        Icons.sd_card_alert_outlined,
      ),
      QueuePauseReason.lowBattery => (
        'Paused — low battery',
        Icons.battery_alert_outlined,
      ),
      QueuePauseReason.none => (null, Icons.info_outline),
    };
    if (message == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        tokens.spaceMd,
        tokens.spaceMd,
        tokens.spaceMd,
        0,
      ),
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSecondaryContainer),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live aggregate header for active downloads: overall progress, counts, and
/// (from the engine stream) combined speed / longest ETA / total size (P9d).
/// Hidden when nothing is active.
class _QueueDashboard extends ConsumerWidget {
  const _QueueDashboard({required this.rows});
  final List<DownloadTask> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool active(DownloadTask t) =>
        t.status == TaskStatus.running ||
        t.status == TaskStatus.queued ||
        t.status == TaskStatus.paused;
    final activeRows = rows.where(active).toList();
    if (activeRows.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final live = ref.watch(queueLiveStatsProvider);
    final running = rows.where((t) => t.status == TaskStatus.running).toList();

    final overall =
        activeRows.fold<double>(0, (a, t) => a + t.progress) /
        (activeRows.length * 100);
    var speed = 0.0;
    int? eta;
    var totalBytes = 0;
    var anySize = false;
    for (final t in running) {
      final s = live[t.id];
      if (s == null) continue;
      if (s.speedBps != null) speed += s.speedBps!;
      final e = s.etaSec;
      if (e != null && (eta == null || e > eta)) eta = e;
      if (s.totalBytes != null) {
        totalBytes += s.totalBytes!;
        anySize = true;
      }
    }

    final queued = rows.where((t) => t.status == TaskStatus.queued).length;
    final done = rows.where((t) => t.status == TaskStatus.done).length;
    final stats = <String>[
      if (speed > 0) '${formatBytes(speed.round())}/s',
      if (eta != null) '${formatDuration(eta)} left',
      if (anySize) formatBytes(totalBytes),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceMd,
        tokens.spaceMd,
        tokens.spaceMd,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${running.length} downloading · $queued queued · $done done',
            style: theme.textTheme.labelLarge,
          ),
          SizedBox(height: tokens.spaceXs),
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radiusSm),
            child: LinearProgressIndicator(
              value: overall.clamp(0.0, 1.0),
              minHeight: 6,
            ),
          ),
          if (stats.isNotEmpty) ...[
            SizedBox(height: tokens.spaceXs),
            Text(
              stats.join('  ·  '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact count of where the queue's tasks stand, shown above the list.
class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.rows});
  final List<DownloadTask> rows;

  @override
  Widget build(BuildContext context) {
    int count(bool Function(DownloadTask) test) => rows.where(test).length;
    final running = count((t) => t.status == TaskStatus.running);
    final queued = count((t) => t.status == TaskStatus.queued);
    final held = count((t) => t.status == TaskStatus.held);
    final paused = count((t) => t.status == TaskStatus.paused);
    final done = count((t) => t.status == TaskStatus.done);
    final failed = count((t) => t.status == TaskStatus.error);

    final tokens = GrabBitTokens.of(context);
    final pills = <Widget>[
      if (running > 0) _pill(context, '$running running', TaskStatus.running),
      if (queued > 0) _pill(context, '$queued queued', TaskStatus.queued),
      if (held > 0) _pill(context, '$held held', TaskStatus.held),
      if (paused > 0) _pill(context, '$paused paused', TaskStatus.paused),
      if (done > 0) _pill(context, '$done done', TaskStatus.done),
      if (failed > 0) _pill(context, '$failed failed', TaskStatus.error),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        0,
      ),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: pills,
      ),
    );
  }

  Widget _pill(BuildContext context, String label, String status) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final style = _statusStyle(theme.colorScheme, status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: style.fg),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, super.key});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(queueControllerProvider.notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final meta = _TaskMeta.parse(task);
    final running = task.status == TaskStatus.running;
    final showProgress = running || task.status == TaskStatus.paused;
    final suffix = [
      meta.site,
      formatDuration(meta.durationSec),
    ].where((e) => e != null && e.isNotEmpty).join('  ·  ');
    final statusLine = suffix.isEmpty
        ? _statusLabel(task)
        : '${_statusLabel(task)}  ·  $suffix';

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceMd),
        child: Row(
          children: [
            _StatusAvatar(status: task.status),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    meta.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  SizedBox(height: tokens.spaceXs),
                  Text(
                    statusLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: task.status == TaskStatus.error
                          ? scheme.error
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (showProgress) ...[
                    SizedBox(height: tokens.spaceSm),
                    LinearProgressIndicator(
                      value: running && task.progress == 0
                          ? null
                          : task.progress / 100,
                      borderRadius: BorderRadius.circular(tokens.radiusPill),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            _actions(context, controller),
            _overflow(context, ref, controller),
          ],
        ),
      ),
    );
  }

  /// Per-task overflow: reorder shortcuts + source-link actions (P9g).
  Widget _overflow(
    BuildContext context,
    WidgetRef ref,
    QueueController controller,
  ) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      onSelected: (value) async {
        switch (value) {
          case 'top':
            await controller.moveToTop(task.id);
          case 'bottom':
            await controller.moveToBottom(task.id);
          case 'copy':
            await Clipboard.setData(ClipboardData(text: task.url));
            if (context.mounted) _notify(context, 'Copied source URL');
          case 'open':
            await ref.read(externalShareServiceProvider).openUrl(task.url);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'top', child: Text('Move to top')),
        PopupMenuItem(value: 'bottom', child: Text('Move to bottom')),
        PopupMenuItem(value: 'copy', child: Text('Copy source URL')),
        PopupMenuItem(value: 'open', child: Text('Open source link')),
      ],
    );
  }

  Widget _actions(BuildContext context, QueueController controller) {
    switch (task.status) {
      case TaskStatus.running:
      case TaskStatus.queued:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.pause),
              tooltip: 'Pause',
              onPressed: () => controller.pause(task.id),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Cancel download?',
                  message: 'Progress on "${_displayTitle(task)}" will be lost.',
                  confirmLabel: 'Cancel download',
                  cancelLabel: 'Keep',
                  destructive: true,
                );
                if (!ok) return;
                await controller.cancel(task.id);
                if (context.mounted) _notify(context, 'Download canceled');
              },
            ),
          ],
        );
      case TaskStatus.held:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Start',
              onPressed: () => controller.resume(task.id),
            ),
            _RemoveButton(task: task, controller: controller),
          ],
        );
      case TaskStatus.paused:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Resume',
              onPressed: () => controller.resume(task.id),
            ),
            _RemoveButton(task: task, controller: controller),
          ],
        );
      case TaskStatus.error:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Retry',
              onPressed: () => controller.retry(task.id),
            ),
            _RemoveButton(task: task, controller: controller),
          ],
        );
      default:
        return _RemoveButton(task: task, controller: controller);
    }
  }

  String _statusLabel(DownloadTask task) => switch (task.status) {
    TaskStatus.running => '${task.progress.toStringAsFixed(0)}%',
    TaskStatus.queued => 'Queued',
    TaskStatus.held => 'Held (batch)',
    TaskStatus.paused => 'Paused',
    TaskStatus.done => 'Done',
    TaskStatus.canceled => 'Canceled',
    TaskStatus.error =>
      'Failed${task.errorCode != null ? ' (${task.errorCode})' : ''}',
    _ => task.status,
  };
}

/// Circular, status-colored badge for a task tile's leading slot.
class _StatusAvatar extends StatelessWidget {
  const _StatusAvatar({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final style = _statusStyle(Theme.of(context).colorScheme, status);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: style.bg, shape: BoxShape.circle),
      child: Icon(style.icon, color: style.fg, size: 20),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.task, required this.controller});
  final DownloadTask task;
  final QueueController controller;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline),
      tooltip: 'Remove',
      onPressed: () async {
        final ok = await confirm(
          context,
          title: 'Remove from queue?',
          message: 'Remove "${_displayTitle(task)}" from the queue?',
          confirmLabel: 'Remove',
          destructive: true,
        );
        if (!ok) return;
        await controller.remove(task.id);
        if (context.mounted) _notify(context, 'Removed from queue');
      },
    );
  }
}

/// Display metadata pulled from the persisted request JSON.
class _TaskMeta {
  const _TaskMeta({required this.title, this.site, this.durationSec});
  final String title;
  final String? site;
  final int? durationSec;

  static _TaskMeta parse(DownloadTask task) {
    try {
      final json = jsonDecode(task.requestJson) as Map<String, dynamic>;
      final title = (json['title'] as String?)?.trim();
      return _TaskMeta(
        title: title != null && title.isNotEmpty ? title : task.url,
        site: json['site'] as String?,
        durationSec: json['durationSec'] as int?,
      );
    } catch (_) {
      return _TaskMeta(title: task.url);
    }
  }
}

/// The download's display title (from the persisted request), falling back to
/// the raw URL for legacy/partial rows that lack one.
String _displayTitle(DownloadTask task) => _TaskMeta.parse(task).title;

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
