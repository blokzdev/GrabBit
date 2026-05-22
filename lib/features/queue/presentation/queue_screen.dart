import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
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
        ],
      ),
      body: tasks.when(
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
                  _QueueSummary(rows: rows),
                  Expanded(
                    child: ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _TaskTile(task: rows[i]),
                    ),
                  ),
                ],
              ),
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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final pills = <Widget>[
      if (running > 0)
        _pill(
          context,
          '$running running',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
      if (queued > 0)
        _pill(
          context,
          '$queued queued',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      if (held > 0)
        _pill(
          context,
          '$held held',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      if (paused > 0)
        _pill(
          context,
          '$paused paused',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
      if (done > 0)
        _pill(
          context,
          '$done done',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      if (failed > 0)
        _pill(
          context,
          '$failed failed',
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
    ];
    if (pills.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceSm,
      ),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: pills,
      ),
    );
  }

  Widget _pill(BuildContext context, String label, Color bg, Color fg) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceMd,
        vertical: tokens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(color: fg),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});
  final DownloadTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(queueControllerProvider.notifier);
    final tokens = GrabBitTokens.of(context);
    final running = task.status == TaskStatus.running;
    return ListTile(
      title: Text(
        _displayTitle(task),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: tokens.spaceXs),
          LinearProgressIndicator(
            value: running && task.progress == 0 ? null : task.progress / 100,
            borderRadius: BorderRadius.circular(tokens.radiusPill),
          ),
          SizedBox(height: tokens.spaceXs),
          Text(_statusLabel(task)),
        ],
      ),
      trailing: _actions(context, controller),
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
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: 'Resume',
          onPressed: () => controller.resume(task.id),
        );
      case TaskStatus.error:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Retry',
          onPressed: () => controller.retry(task.id),
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

/// The download's display title (from the persisted request), falling back to
/// the raw URL for legacy/partial rows that lack one.
String _displayTitle(DownloadTask task) {
  try {
    final json = jsonDecode(task.requestJson) as Map<String, dynamic>;
    final title = json['title'] as String?;
    if (title != null && title.trim().isNotEmpty) return title;
  } catch (_) {}
  return task.url;
}

void _notify(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
