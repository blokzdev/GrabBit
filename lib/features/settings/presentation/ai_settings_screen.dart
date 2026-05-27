import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_subscaffold.dart';

/// `/settings/ai` — on-device AI + the relationship graph (semantic search,
/// graph rebuild, embedder diagnostics).
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubScaffold(
      title: 'AI & graph',
      children: (context, ref, settings) => [
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Rebuild graph index'),
              subtitle: const Text(
                'Reproject your library into the on-device graph',
              ),
              trailing: const Icon(Icons.play_arrow_outlined),
              onTap: () => _rebuildGraph(context, ref),
            ),
            const _SemanticSearchTile(),
            const _EmbedderSelfTestTile(),
          ],
        ),
      ],
    );
  }
}

Future<void> _rebuildGraph(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Rebuilding graph index…')));
  final stats = await ref.read(graphSyncServiceProvider).rebuild();
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          stats.available
              ? 'Graph rebuilt — ${stats.mediaNodes} media · ${stats.edges} edges'
              : 'Graph engine unavailable on this device',
        ),
      ),
    );
}

/// Opt-in toggle for on-device semantic search (P10b-2). Enabling downloads the
/// embedder model (one time, ~N MB) with a progress snackbar; disabling leaves
/// the model untouched but stops using it. When the pinned model changes
/// (P10g-1) an opted-in user sees an **Update AI model** row to fetch the new
/// one (never auto-downloaded). Everything works without it.
class _SemanticSearchTile extends ConsumerStatefulWidget {
  const _SemanticSearchTile();

  @override
  ConsumerState<_SemanticSearchTile> createState() =>
      _SemanticSearchTileState();
}

class _SemanticSearchTileState extends ConsumerState<_SemanticSearchTile> {
  bool _busy = false;

  Future<void> _toggle(bool value) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!value) {
      await controller.setSemanticSearchEnabled(false);
      return;
    }
    await controller.setSemanticSearchEnabled(true);
    await _download();
  }

  /// Downloads (or re-downloads) the pinned embedder, then builds the index.
  /// Reused by the on-toggle path and by the "update model" path (P10g-1), where
  /// an opted-in user is on a now-superseded model and `ensureReady()` is false.
  Future<void> _download() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Downloading semantic-search model…')),
      );
    try {
      await ref.read(inferenceEngineProvider).downloadModel();
      // Build the vector index now that the model is ready.
      final stats = await ref
          .read(graphSyncServiceProvider)
          .backfillEmbeddings();
      ref.invalidate(semanticSearchReadyProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Semantic search ready — ${stats.total} embedded'),
          ),
        );
    } on InferenceException catch (e) {
      await controller.setSemanticSearchEnabled(false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.code == InferenceErrorCode.unavailable
                  ? 'On-device AI isn\'t available on this device'
                  : 'Couldn\'t download the model — try again later',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.asData?.value.semanticSearchEnabled ?? false,
      ),
    );
    final ready = ref.watch(semanticSearchReadyProvider).asData?.value ?? false;
    final model = ref.read(inferenceEngineProvider).model;
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Semantic search'),
          subtitle: Text(
            'Search your library by meaning, on-device. '
            'Downloads a ~${model.approxDownloadMb} MB model.',
          ),
          value: enabled,
          onChanged: _busy ? null : _toggle,
        ),
        // Opted in but the (new) model isn't installed — offer the download
        // instead of silently fetching it on launch (P10g-1 model upgrade).
        if (enabled && !ready && !_busy)
          ListTile(
            leading: const Icon(Icons.system_update_alt),
            title: const Text('Update AI model'),
            subtitle: Text(
              'An improved model is available (~${model.approxDownloadMb} MB).',
            ),
            onTap: _download,
          ),
      ],
    );
  }
}

/// On-device diagnostic: embeds a sample string and reports the engine's
/// availability + vector dimension via a snackbar. The verification surface for
/// the embedder foundation (mirrors the graph self-test).
class _EmbedderSelfTestTile extends ConsumerWidget {
  const _EmbedderSelfTestTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.auto_awesome_outlined),
      title: const Text('Test embedder'),
      subtitle: const Text('Verify the on-device embedding model'),
      trailing: const Icon(Icons.play_arrow_outlined),
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final engine = ref.read(inferenceEngineProvider);
    String message;
    try {
      final ready = await engine.ensureReady();
      if (!ready || !engine.isAvailable) {
        message = 'Embedder not ready — enable Semantic search first';
      } else {
        final vector = await engine.embed('GrabBit semantic search test');
        final stats = await ref.read(graphSyncServiceProvider).stats();
        message =
            'Embedder OK — ${vector.length}-d · ${stats.embeddings} embedded';
      }
    } on InferenceException catch (e) {
      message = 'Embedder test failed: ${e.message}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}
