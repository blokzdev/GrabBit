import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: [
          if (heldCount > 0)
            TextButton.icon(
              onPressed: controller.startAll,
              icon: const Icon(Icons.play_arrow),
              label: Text('Start all ($heldCount)'),
            ),
          if (runningCount > 0)
            IconButton(
              tooltip: 'Pause all',
              icon: const Icon(Icons.pause),
              onPressed: controller.pauseAll,
            ),
        ],
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load queue: $e')),
        data: (rows) => rows.isEmpty
            ? const Center(child: Text('No downloads in the queue'))
            : ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => _TaskTile(task: rows[i]),
              ),
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
    final running = task.status == TaskStatus.running;
    return ListTile(
      title: Text(task.url, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: running && task.progress == 0 ? null : task.progress / 100,
          ),
          const SizedBox(height: 4),
          Text(_statusLabel(task)),
        ],
      ),
      trailing: _actions(controller),
    );
  }

  Widget _actions(QueueController controller) {
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
              onPressed: () => controller.cancel(task.id),
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
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove',
              onPressed: () => controller.remove(task.id),
            ),
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
        return IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Remove',
          onPressed: () => controller.remove(task.id),
        );
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
