import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/downloaded_models_provider.dart';
import 'package:grabbit/core/ai/downloaded_translation_packs_provider.dart';
import 'package:grabbit/core/ai/embedder_engine_factory.dart';
import 'package:grabbit/core/ai/embedder_engine_provider.dart';
import 'package:grabbit/core/ai/generation_model.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/model_capability_matrix.dart';
import 'package:grabbit/core/ai/model_catalog.dart';
import 'package:grabbit/core/ai/model_download_service.dart';
import 'package:grabbit/core/ai/ocr_provider.dart';
import 'package:grabbit/core/ai/transcription_model.dart';
import 'package:grabbit/core/ai/transcription_provider.dart';
import 'package:grabbit/core/ai/translation_provider.dart';
import 'package:grabbit/core/device/device_profile.dart';
import 'package:grabbit/core/device/device_tier_provider.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/features/ai/data/thing_stats_providers.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';
import 'package:grabbit/features/library/presentation/translation.dart';
import 'package:grabbit/features/notifications/data/notification_enums.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_subscaffold.dart';
import 'package:path_provider/path_provider.dart';

/// `/settings/ai` — on-device AI + the relationship graph (semantic search,
/// graph rebuild, embedder diagnostics).
class AiSettingsScreen extends ConsumerWidget {
  const AiSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubScaffold(
      title: 'AI & graph',
      children: (context, ref, settings) => [
        const _DeviceTierBanner(),
        SettingsCard(
          children: [
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Rebuild graph index'),
              subtitle: const Text(
                'Reproject your library into the on-device graph',
              ),
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InfoHintButton(
                    InfoHint(
                      title: 'Rebuild graph index',
                      body:
                          'Rebuilds the on-device relationship graph from your '
                          'library. Normally kept in sync automatically — use '
                          'this if related items or hubs look out of date.',
                    ),
                  ),
                  Icon(Icons.play_arrow_outlined),
                ],
              ),
              onTap: () => _rebuildGraph(context, ref),
            ),
            const _SemanticSearchTile(),
            const _MultilingualModelTile(),
            const _ThingsStatsTile(),
            const _EmbedderSelfTestTile(),
            const _MultilingualSelfTestTile(),
          ],
        ),
        const _GenerationCard(),
        const _TranscriptionCard(),
        const _OcrCard(),
        const _TranslationCard(),
      ],
    );
  }
}

/// On-device image OCR (P13b-3). Image text is always scannable by hand from an
/// image's detail screen (P13b-1); this card just offers the opt-in to do it
/// automatically on download. Shown only where ML Kit OCR can run (Android).
class _OcrCard extends ConsumerWidget {
  const _OcrCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(ocrEngineProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final auto = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.autoOcrOnDownload ?? false,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SettingsCard(
        children: [
          SwitchListTile(
            secondary: const InfoHintButton(
              InfoHint(
                title: 'Auto-scan images for text',
                body:
                    'Automatically read text inside each downloaded image so '
                    'you can search for it — all on-device and offline. You can '
                    'always scan an image by hand from its detail screen.',
              ),
            ),
            title: const Text('Image text (OCR)'),
            subtitle: const Text(
              'Scan new image downloads for searchable text',
            ),
            value: auto,
            onChanged: (v) => ref
                .read(settingsControllerProvider.notifier)
                .setAutoOcrOnDownload(v),
          ),
        ],
      ),
    );
  }
}

/// On-device translation language packs (P13f-2). ML Kit downloads a ~30 MB
/// model per language on demand the first time you translate; this card makes
/// them visible — list what's downloaded, delete to free space, or pre-download
/// a language. Shown only where ML Kit translation can run (Android).
class _TranslationCard extends ConsumerWidget {
  const _TranslationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(translationEngineProvider).isAvailable) {
      return const SizedBox.shrink();
    }
    final packs =
        ref.watch(downloadedTranslationPacksProvider).asData?.value ??
        const <String>{};
    final codes = packs.toList()
      ..sort(
        (a, b) =>
            translationLanguageName(a).compareTo(translationLanguageName(b)),
      );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SettingsCard(
        children: [
          const ListTile(
            leading: Icon(Icons.translate_outlined),
            title: Text('On-device translation'),
            subtitle: Text('Translate saved items without leaving your device'),
            trailing: InfoHintButton(
              InfoHint(
                title: 'Translation language packs',
                body:
                    'Each language uses a ~30 MB model that downloads once over '
                    'Wi-Fi, then translates offline. Packs download '
                    'automatically the first time you translate; delete ones '
                    'you no longer need to free space, or add one ahead of time.',
              ),
            ),
          ),
          if (codes.isEmpty)
            const ListTile(
              dense: true,
              title: Text(
                'No language packs yet — they download the first time you '
                'translate, or add one below.',
              ),
            )
          else
            for (final code in codes) _TranslationPackTile(code: code),
          const _AddTranslationLanguageTile(),
        ],
      ),
    );
  }
}

/// A single downloaded language pack: its name + size, with a delete affordance
/// to free space (the pack re-downloads on demand later).
class _TranslationPackTile extends ConsumerStatefulWidget {
  const _TranslationPackTile({required this.code});

  final String code;

  @override
  ConsumerState<_TranslationPackTile> createState() =>
      _TranslationPackTileState();
}

class _TranslationPackTileState extends ConsumerState<_TranslationPackTile> {
  bool _busy = false;

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = translationLanguageName(widget.code);
    setState(() => _busy = true);
    try {
      await ref.read(translationEngineProvider).deleteModel(widget.code);
      ref.invalidate(downloadedTranslationPacksProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Deleted $name language pack')));
    } on InferenceException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Couldn\'t delete $name — ${e.message}')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.language_outlined),
      title: Text(translationLanguageName(widget.code)),
      subtitle: Text('${widget.code}  ·  ~30 MB  ·  Downloaded'),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : PopupMenuButton<void>(
              tooltip: 'Manage language pack',
              onSelected: (_) => _delete(),
              itemBuilder: (context) => const [
                PopupMenuItem<void>(
                  value: null,
                  child: Text('Delete language pack'),
                ),
              ],
            ),
    );
  }
}

/// Pre-download a language pack from Settings (rather than waiting for the first
/// translation). Picks a language, confirms the ~30 MB Wi-Fi download, fetches.
class _AddTranslationLanguageTile extends ConsumerStatefulWidget {
  const _AddTranslationLanguageTile();

  @override
  ConsumerState<_AddTranslationLanguageTile> createState() =>
      _AddTranslationLanguageTileState();
}

class _AddTranslationLanguageTileState
    extends ConsumerState<_AddTranslationLanguageTile> {
  bool _busy = false;

  Future<void> _add() async {
    final downloaded =
        ref.read(downloadedTranslationPacksProvider).asData?.value ??
        const <String>{};
    final code = await _pickTranslationLanguage(context, exclude: downloaded);
    if (code == null || !mounted) return;
    final name = translationLanguageName(code);
    final ok = await confirm(
      context,
      title: 'Download $name?',
      message:
          'Downloads a ~30 MB language pack over Wi-Fi, then translates '
          'offline.',
      confirmLabel: 'Download',
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(translationEngineProvider).downloadModel(code);
      ref.invalidate(downloadedTranslationPacksProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$name language pack ready')));
    } on InferenceException catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Couldn\'t download $name — ${e.message}')),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.add),
      title: const Text('Download a language'),
      enabled: !_busy,
      onTap: _busy ? null : _add,
    );
  }
}

/// Searchable bottom-sheet picker over ML Kit's supported languages, excluding
/// already-downloaded ones. Returns the chosen BCP-47 code, or null if
/// dismissed.
Future<String?> _pickTranslationLanguage(
  BuildContext context, {
  required Set<String> exclude,
}) {
  final all = [
    for (final l in kTranslationLanguages)
      if (!exclude.contains(l.code)) l,
  ];
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var query = '';
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final q = query.trim().toLowerCase();
          final shown = q.isEmpty
              ? all
              : [
                  for (final l in all)
                    if (l.name.toLowerCase().contains(q) || l.code.contains(q))
                      l,
                ];
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search languages',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final l in shown)
                          ListTile(
                            title: Text(l.name),
                            subtitle: Text(l.code),
                            onTap: () => Navigator.pop(ctx, l.code),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

/// Compact banner framing the AI screen with the device's capability tier (P12g)
/// — so a user understands *why* some AI options are offered or gated. Reads the
/// live tier (probed at startup); the InfoHint explains on-device scaling.
class _DeviceTierBanner extends ConsumerWidget {
  const _DeviceTierBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(activeDeviceTierProvider);
    return SettingsCard(
      children: [
        ListTile(
          leading: const Icon(Icons.memory_outlined),
          title: Text('Your device: ${tier.label}'),
          subtitle: Text(tier.blurb),
          trailing: const InfoHintButton(
            InfoHint(
              title: 'On-device AI & your device',
              body:
                  'GrabBit runs all AI on your device, so what it can do scales '
                  'with your device. More capable devices unlock larger, faster '
                  'models and more features; every device runs at least semantic '
                  'search and speech transcription. Everything is optional and '
                  'private — nothing leaves your device.',
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> _rebuildGraph(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  // Captured before the await so a mid-rebuild navigation can't read a
  // disposed ref.
  final center = ref.read(notificationCenterProvider);
  final sync = ref.read(graphSyncServiceProvider);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Rebuilding graph index…')));
  try {
    final stats = await sync.rebuild();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            stats.available
                ? 'Graph rebuilt — ${stats.mediaNodes} media · ${stats.edges} edges · ${stats.thingNodes} things'
                : "Graph engine isn't available on this device",
          ),
        ),
      );
    await center.post(
      category: NotificationCategory.graph,
      severity: stats.available
          ? NotificationSeverity.success
          : NotificationSeverity.warning,
      title: stats.available
          ? 'Graph index rebuilt'
          : 'Graph engine unavailable',
      body: stats.available
          ? '${stats.mediaNodes} media · ${stats.edges} edges · ${stats.thingNodes} things'
          : "On-device graph isn't available on this device.",
      dedupeKey: 'graph_rebuild',
    );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Graph rebuild failed')));
    await center.post(
      category: NotificationCategory.graph,
      severity: NotificationSeverity.error,
      title: 'Graph rebuild failed',
      body: 'Something went wrong rebuilding the graph index.',
      dedupeKey: 'graph_rebuild',
    );
  }
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
      await ref.read(embedderEngineProvider).downloadModel();
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
    final model = ref.read(embedderEngineProvider).model;
    return Column(
      children: [
        SwitchListTile(
          secondary: const InfoHintButton(
            InfoHint(
              title: 'Semantic search',
              body:
                  'Find library items by meaning, not just keywords — all '
                  'on-device. Turning it on downloads a small embedding model '
                  'once; nothing leaves your device, and search still works '
                  'without it.',
            ),
          ),
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
/// P14f diagnostic: a read-only count of the Things layer (typed schema.org
/// records projected from the library + any authored relationships).
class _ThingsStatsTile extends ConsumerWidget {
  const _ThingsStatsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final things = ref.watch(thingCountProvider);
    final edges = ref.watch(thingEdgeCountProvider);
    final count = things.value;
    final edgeCount = edges.value;
    final subtitle = count == null
        ? 'Counting…'
        : '$count Thing${count == 1 ? '' : 's'}'
              "${edgeCount == null ? '' : ' · $edgeCount authored edge${edgeCount == 1 ? '' : 's'}'}";
    return ListTile(
      leading: const Icon(Icons.schema_outlined),
      title: const Text('Things in your library'),
      subtitle: Text(subtitle),
      trailing: const InfoHintButton(
        InfoHint(
          title: 'Things',
          body:
              'Your library as typed schema.org records. Every download is '
              'projected into a MediaObject Thing; authored edges are '
              'relationships you or the app assert between them. The graph and '
              '“Ask your library” read this layer.',
        ),
      ),
    );
  }
}

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
    final engine = ref.read(embedderEngineProvider);
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

/// On-device check for the multilingual embedder (P12c-2): downloads MiniLM (if
/// needed) and embeds a translated pair + an unrelated sentence, reporting their
/// cosine similarities — the en/es pair should score far higher. Proves the onnx
/// engine end-to-end **without** changing the active embedder. Android-only; it
/// no-ops gracefully elsewhere (the engine reports unavailable).
class _MultilingualSelfTestTile extends ConsumerStatefulWidget {
  const _MultilingualSelfTestTile();

  @override
  ConsumerState<_MultilingualSelfTestTile> createState() =>
      _MultilingualSelfTestTileState();
}

class _MultilingualSelfTestTileState
    extends ConsumerState<_MultilingualSelfTestTile> {
  bool _busy = false;

  Future<void> _run() async {
    final messenger = ScaffoldMessenger.of(context);
    const model = paraphraseMultilingualMiniLmL12V2;
    final engine = embedderEngineFor(
      model,
      downloads: ref.read(modelDownloadServiceProvider),
    );
    setState(() => _busy = true);
    String message;
    try {
      if (!await engine.ensureReady()) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Downloading multilingual model (~${model.approxDownloadMb} MB)…',
              ),
            ),
          );
        await engine.downloadModel();
        await engine.ensureReady();
      }
      if (!engine.isAvailable) {
        message = "Multilingual embedder isn't available on this device";
      } else {
        final vecs = await engine.embedBatch(const [
          'A cat sits on the mat',
          'Un gato se sienta en la alfombra',
          'Quarterly tax revenue increased sharply',
        ]);
        final translation = _cosine(vecs[0], vecs[1]);
        final unrelated = _cosine(vecs[0], vecs[2]);
        message =
            'Multilingual OK — en/es ${translation.toStringAsFixed(2)} ≫ '
            'unrelated ${unrelated.toStringAsFixed(2)}';
      }
    } on InferenceException catch (e) {
      message = 'Multilingual test failed: ${e.message}';
    } finally {
      await engine.close();
      if (mounted) setState(() => _busy = false);
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // Vectors are L2-normalized by the engine, so cosine == dot product.
  double _cosine(List<double> a, List<double> b) {
    var sum = 0.0;
    for (var i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    const model = paraphraseMultilingualMiniLmL12V2;
    return ListTile(
      leading: const Icon(Icons.translate_outlined),
      title: const Text('Test multilingual embedder'),
      subtitle: Text(
        'Downloads MiniLM (~${model.approxDownloadMb} MB) and checks '
        'cross-lingual similarity',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_outlined),
      onTap: _busy ? null : _run,
    );
  }
}

/// Install-global switch to the multilingual embedder (P12c-3). Shown only on
/// eligible (mid/high-tier Android) devices — low-end stays on Gecko. Toggling
/// persists the selection; if semantic search is on, it immediately downloads
/// the model (if needed) and **re-embeds the whole library** so non-English
/// search/related improve right away (otherwise the re-embed happens on next
/// launch). Toggling off reverts to Gecko and re-embeds back.
class _MultilingualModelTile extends ConsumerStatefulWidget {
  const _MultilingualModelTile();

  @override
  ConsumerState<_MultilingualModelTile> createState() =>
      _MultilingualModelTileState();
}

class _MultilingualModelTileState
    extends ConsumerState<_MultilingualModelTile> {
  bool _busy = false;

  static const _miniLm = paraphraseMultilingualMiniLmL12V2;

  Future<void> _toggle(bool value) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final enabled = ref.read(
      settingsControllerProvider.select(
        (s) => s.value?.semanticSearchEnabled ?? false,
      ),
    );
    await controller.setSelectedEmbedderModelId(value ? _miniLm.id : '');
    // Only re-embed now if semantic search is active; otherwise the switch is
    // recorded and applied on the next launch sync.
    if (enabled) await _reindex();
  }

  /// Downloads the now-active embedder (if needed) and re-embeds the library.
  Future<void> _reindex() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Switching model — re-indexing your library…'),
        ),
      );
    try {
      await ref.read(embedderEngineProvider).downloadModel();
      final stats = await ref
          .read(graphSyncServiceProvider)
          .backfillEmbeddings();
      ref.invalidate(semanticSearchReadyProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Re-indexed — ${stats.total} embedded')),
        );
    } on InferenceException catch (e) {
      // Revert the selection so the active model matches what's actually usable.
      await controller.setSelectedEmbedderModelId('');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.code == InferenceErrorCode.unavailable
                  ? 'Multilingual model isn\'t available on this device'
                  : 'Couldn\'t switch the model — try again later',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = ref.watch(activeDeviceTierProvider);
    final eligible = const ModelCapabilityMatrix()
        .eligibleEmbedders(tier)
        .contains(_miniLm);
    // Ineligible devices stay on the always-present Gecko embedder (semantic
    // search still works). Show a muted disabled tile rather than hiding, so
    // gating reads consistently with the generation card (P12g) — the
    // device-tier banner explains the bigger picture.
    if (!eligible) {
      final theme = Theme.of(context);
      return ListTile(
        leading: Icon(Icons.translate_outlined, color: theme.disabledColor),
        title: const Text('Multilingual semantic search'),
        subtitle: const Text('Available on more capable devices.'),
        trailing: const InfoHintButton(
          InfoHint(
            title: 'Multilingual semantic search',
            body:
                'A 50-language embedding model that improves search and '
                '“related” on non-English content. It needs more memory than '
                'this device has, so semantic search uses the default English '
                'model here — everything still works on-device.',
          ),
        ),
        enabled: false,
      );
    }
    final selectedId = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.selectedEmbedderModelId ?? '',
      ),
    );
    return SwitchListTile(
      secondary: const InfoHintButton(
        InfoHint(
          title: 'Multilingual semantic search',
          body:
              'Switches the embedding model to a 50-language one so search and '
              '“related” work well on non-English content. One-time '
              '~127 MB download, then your library is re-indexed on-device. '
              'Turn off to go back to the default English model.',
        ),
      ),
      title: const Text('Multilingual semantic search'),
      subtitle: Text(
        'Better non-English results. Downloads ~${_miniLm.approxDownloadMb} MB '
        'and re-indexes your library.',
      ),
      value: selectedId == _miniLm.id,
      onChanged: _busy ? null : _toggle,
    );
  }
}

/// On-device text generation (P12d) — a tier-gated, opt-in model picker + a Labs
/// self-test. Hidden entirely on devices that can't run any generation model
/// (low tier) so the AI screen stays clean. The picker + self-test are the only
/// generation surface in v1; real features (summaries, "Ask your library") are P13.
class _GenerationCard extends ConsumerWidget {
  const _GenerationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(activeDeviceTierProvider);
    final eligible = const ModelCapabilityMatrix().eligibleGenerationModels(
      tier,
    );
    // Low-end / ineligible devices: no generation model fits. Rather than hide
    // the section silently, show a muted disabled-reason tile so the gating is
    // legible (P12g) — the device-tier banner explains the bigger picture.
    if (eligible.isEmpty) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SettingsCard(
          children: [
            ListTile(
              leading: Icon(
                Icons.auto_awesome_outlined,
                color: theme.disabledColor,
              ),
              title: const Text('On-device text generation'),
              subtitle: const Text('Needs more memory than this device has.'),
              trailing: const InfoHintButton(
                InfoHint(
                  title: 'On-device text generation',
                  body:
                      'Text generation runs a larger language model on your '
                      'device, which needs more memory than this device has. '
                      'Semantic search and speech transcription still work here. '
                      'Nothing leaves your device.',
                ),
              ),
              enabled: false,
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SettingsCard(
        children: [
          for (final m in eligible) _GenerationModelTile(model: m),
          const _AutoSummarizeTile(),
          const _AutoTagTile(),
          const _AutoExtractTile(),
          const _GenerationSelfTestTile(),
        ],
      ),
    );
  }
}

/// Opt-in (P13a-2): auto-generate the abstractive summary for newly downloaded
/// items in the background. Shown only when text generation is enabled (a model
/// is active); it runs only when that model is already downloaded — the
/// on-demand "Summarize with AI" on item detail works regardless.
class _AutoSummarizeTile extends ConsumerWidget {
  const _AutoSummarizeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.generationEnabled ?? false,
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    final auto = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.autoSummarizeOnDownload ?? false,
      ),
    );
    return SwitchListTile(
      secondary: const InfoHintButton(
        InfoHint(
          title: 'Auto-summarize new downloads',
          body:
              'Generate an AI summary for each new download automatically, in '
              'the background — all on-device. Runs only when a text-generation '
              'model is downloaded; you can always summarize an item by hand '
              'from its detail screen.',
        ),
      ),
      title: const Text('Auto-summarize new downloads'),
      subtitle: const Text('Summarize each download in the background'),
      value: auto,
      onChanged: (v) => ref
          .read(settingsControllerProvider.notifier)
          .setAutoSummarizeOnDownload(v),
    );
  }
}

/// Opt-in (P13c-2): auto-apply LLM tags to new downloads in the background.
/// Shown only when text generation is enabled; runs only when a model is
/// downloaded. Auto-applied tags are marked as AI and can be deleted; the
/// on-demand "Suggest tags with AI" in the editor works regardless.
class _AutoTagTile extends ConsumerWidget {
  const _AutoTagTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.generationEnabled ?? false,
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    final auto = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.autoTagOnDownload ?? false,
      ),
    );
    return SwitchListTile(
      secondary: const InfoHintButton(
        InfoHint(
          title: 'Auto-tag new downloads',
          body:
              'Add AI-suggested tags to each new download automatically, in the '
              'background — all on-device. Runs only when a text-generation '
              'model is downloaded. AI tags are marked with a ✦ and can be '
              'deleted; you can always tag an item by hand.',
        ),
      ),
      title: const Text('Auto-tag new downloads'),
      subtitle: const Text('Tag each download in the background'),
      value: auto,
      onChanged: (v) =>
          ref.read(settingsControllerProvider.notifier).setAutoTagOnDownload(v),
    );
  }
}

/// Opt-in (P15f): auto-extract structured schema.org Things from new downloads in
/// the background. Shown only when text generation is enabled **and** this device
/// can run structured (function-calling) extraction; runs only when a compatible
/// model is downloaded. Results are pending suggestions in the inbox — never
/// auto-asserted; the on-demand "Extract Things" on item detail works regardless.
class _AutoExtractTile extends ConsumerWidget {
  const _AutoExtractTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.generationEnabled ?? false,
      ),
    );
    if (!enabled || !ref.watch(structuredExtractionSupportedProvider)) {
      return const SizedBox.shrink();
    }
    final auto = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.autoExtractOnDownload ?? false,
      ),
    );
    return SwitchListTile(
      secondary: const InfoHintButton(
        InfoHint(
          title: 'Auto-extract Things',
          body:
              'Extract structured records (a Recipe, Event, Place…) from each new '
              'download automatically, in the background — all on-device. Runs '
              'only when a function-calling-capable model is downloaded. Each '
              'extraction is a suggestion you confirm before it joins your '
              'library; you can always extract by hand from an item.',
        ),
      ),
      title: const Text('Auto-extract Things'),
      subtitle: const Text('Extract structured data from each download'),
      value: auto,
      onChanged: (v) => ref
          .read(settingsControllerProvider.notifier)
          .setAutoExtractOnDownload(v),
    );
  }
}

/// One selectable generation model row: badge (Recommended / size band) + size,
/// a radio-like check for the active selection. Selecting it opts in + downloads
/// (storage-guarded); selecting the active one again turns generation off.
class _GenerationModelTile extends ConsumerStatefulWidget {
  const _GenerationModelTile({required this.model});

  final GenerationModel model;

  @override
  ConsumerState<_GenerationModelTile> createState() =>
      _GenerationModelTileState();
}

class _GenerationModelTileState extends ConsumerState<_GenerationModelTile> {
  bool _busy = false;
  double _progress = 0;

  GenerationModel get _model => widget.model;

  Future<void> _select(bool selected) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!selected) {
      // Toggling off the active model disables generation (keeps the download).
      await controller.setGenerationEnabled(false);
      await controller.setSelectedGenerationModelId('');
      return;
    }
    await controller.setGenerationEnabled(true);
    await controller.setSelectedGenerationModelId(_model.id);
    await _download();
  }

  Future<void> _download() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await ref
          .read(generationEngineProvider)
          .downloadModel(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      await ref.read(generationEngineProvider).ensureReady();
      ref.invalidate(downloadedModelIdsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${_model.displayName} ready')));
    } on InferenceException catch (e) {
      await controller.setGenerationEnabled(false);
      await controller.setSelectedGenerationModelId('');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.code == InferenceErrorCode.unavailable
                  ? 'Text generation isn\'t available on this device'
                  : 'Couldn\'t download ${_model.displayName} — ${e.message}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(modelDownloadServiceProvider).delete(_model.id);
    ref.invalidate(downloadedModelIdsProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Deleted ${_model.displayName} download')),
      );
  }

  String get _bandLabel => switch (_model.modelClass) {
    GenerationModelClass.small => 'Smaller · faster',
    GenerationModelClass.balanced => 'Recommended',
    GenerationModelClass.large => 'Larger · better',
    GenerationModelClass.flagship => 'Flagship',
  };

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeGenerationModelProvider);
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.generationEnabled ?? false,
      ),
    );
    final isSelected = enabled && active?.id == _model.id;
    final downloaded =
        ref
            .watch(downloadedModelIdsProvider)
            .asData
            ?.value
            .contains(_model.id) ??
        false;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Row(
        children: [
          Text(_model.displayName),
          const SizedBox(width: 8),
          Chip(
            label: Text(_bandLabel),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      subtitle: Text(
        '${_model.blurb}  ·  ${_stateLabel(isSelected, downloaded)}',
      ),
      trailing: _trailing(isSelected, downloaded),
      onTap: _busy ? null : () => _select(!isSelected),
    );
  }

  String _stateLabel(bool active, bool downloaded) {
    if (active) return 'Active';
    if (downloaded) return 'Downloaded';
    return '~${_model.approxDownloadMb} MB';
  }

  Widget? _trailing(bool active, bool downloaded) {
    if (_busy) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: _progress == 0 ? null : _progress,
        ),
      );
    }
    // Free space by deleting a downloaded model that isn't the active one.
    if (downloaded && !active) {
      return PopupMenuButton<void>(
        tooltip: 'Manage download',
        onSelected: (_) => _delete(),
        itemBuilder: (context) => const [
          PopupMenuItem<void>(value: null, child: Text('Delete download')),
        ],
      );
    }
    return null;
  }
}

/// Labs self-test: runs a fixed prompt through the active generation model and
/// streams the completion into a snackbar — proves generation works offline,
/// without any real feature. Visible only when generation is enabled + ready.
class _GenerationSelfTestTile extends ConsumerStatefulWidget {
  const _GenerationSelfTestTile();

  @override
  ConsumerState<_GenerationSelfTestTile> createState() =>
      _GenerationSelfTestTileState();
}

class _GenerationSelfTestTileState
    extends ConsumerState<_GenerationSelfTestTile> {
  bool _busy = false;
  String? _output;

  Future<void> _run() async {
    final engine = ref.read(generationEngineProvider);
    setState(() {
      _busy = true;
      _output = '';
    });
    try {
      if (!await engine.ensureReady()) {
        setState(() => _output = 'Enable a model above first');
        return;
      }
      final buffer = StringBuffer();
      await for (final token in engine.generate(
        'In one short sentence, what is a knowledge graph?',
      )) {
        buffer.write(token);
        if (mounted) setState(() => _output = buffer.toString());
      }
    } on InferenceException catch (e) {
      if (mounted) setState(() => _output = 'Generation failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.generationEnabled ?? false,
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.science_outlined),
      title: const Text('Test text generation'),
      subtitle: Text(
        _output?.isNotEmpty == true
            ? _output!
            : 'Run a sample prompt through the on-device model',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_outlined),
      onTap: _busy ? null : _run,
    );
  }
}

/// On-device speech transcription (P12e) — a tier-gated, opt-in model picker + a
/// Labs self-test. Unlike generation, this card is shown on **every** tier (even
/// low-end runs whisper-tiny). It's the fallback that gives caption-less media a
/// transcript; the pipeline wiring lands in P12e-3.
class _TranscriptionCard extends ConsumerWidget {
  const _TranscriptionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(activeDeviceTierProvider);
    final eligible = const ModelCapabilityMatrix().eligibleTranscriptionModels(
      tier,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SettingsCard(
        children: [
          const ListTile(
            leading: Icon(Icons.mic_none_outlined),
            title: Text('Speech transcription'),
            subtitle: Text('Transcribe downloads without captions, on-device'),
            trailing: InfoHintButton(
              InfoHint(
                title: 'Speech transcription',
                body:
                    'Turns speech in your downloads into searchable text and '
                    'tap-to-seek captions — all on-device with Whisper. Used '
                    'only when a download has no captions of its own. Pick a '
                    'model to download it once; bigger models are more accurate '
                    'but slower and larger.',
              ),
            ),
          ),
          for (final m in eligible) _TranscriptionModelTile(model: m),
          const _TranscriptionSelfTestTile(),
        ],
      ),
    );
  }
}

/// One selectable transcription model row: a Recommended/size-band badge + size,
/// a radio-like check for the active selection. Selecting it opts in + downloads
/// (storage-guarded); selecting the active one again turns transcription off.
class _TranscriptionModelTile extends ConsumerStatefulWidget {
  const _TranscriptionModelTile({required this.model});

  final TranscriptionModel model;

  @override
  ConsumerState<_TranscriptionModelTile> createState() =>
      _TranscriptionModelTileState();
}

class _TranscriptionModelTileState
    extends ConsumerState<_TranscriptionModelTile> {
  bool _busy = false;
  double _progress = 0;

  TranscriptionModel get _model => widget.model;

  Future<void> _select(bool selected) async {
    final controller = ref.read(settingsControllerProvider.notifier);
    if (!selected) {
      // Toggling off the active model disables transcription (keeps the download).
      await controller.setTranscriptionEnabled(false);
      await controller.setSelectedTranscriptionModelId('');
      return;
    }
    await controller.setTranscriptionEnabled(true);
    await controller.setSelectedTranscriptionModelId(_model.id);
    await _download();
  }

  Future<void> _download() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _progress = 0;
    });
    try {
      await ref
          .read(transcriptionEngineProvider)
          .downloadModel(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
      await ref.read(transcriptionEngineProvider).ensureReady();
      ref.invalidate(downloadedModelIdsProvider);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('${_model.displayName} ready')));
    } on InferenceException catch (e) {
      await controller.setTranscriptionEnabled(false);
      await controller.setSelectedTranscriptionModelId('');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              e.code == InferenceErrorCode.unavailable
                  ? 'Transcription isn\'t available on this device'
                  : 'Couldn\'t download ${_model.displayName} — ${e.message}',
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(modelDownloadServiceProvider).delete(_model.id);
    ref.invalidate(downloadedModelIdsProvider);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Deleted ${_model.displayName} download')),
      );
  }

  String get _bandLabel => switch (_model.modelClass) {
    TranscriptionModelClass.tiny => 'Smaller · faster',
    TranscriptionModelClass.base => 'Recommended',
    TranscriptionModelClass.small => 'Larger · better',
    TranscriptionModelClass.turbo => 'Flagship',
  };

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(activeTranscriptionModelProvider);
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.transcriptionEnabled ?? false,
      ),
    );
    final isSelected = enabled && active.id == _model.id;
    final downloaded =
        ref
            .watch(downloadedModelIdsProvider)
            .asData
            ?.value
            .contains(_model.id) ??
        false;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? theme.colorScheme.primary : null,
      ),
      title: Row(
        children: [
          Text(_model.displayName),
          const SizedBox(width: 8),
          Chip(
            label: Text(_bandLabel),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
      subtitle: Text(
        '${_model.blurb}  ·  ${_stateLabel(isSelected, downloaded)}',
      ),
      trailing: _trailing(isSelected, downloaded),
      onTap: _busy ? null : () => _select(!isSelected),
    );
  }

  String _stateLabel(bool active, bool downloaded) {
    if (active) return 'Active';
    if (downloaded) return 'Downloaded';
    return '~${_model.approxDownloadMb} MB';
  }

  Widget? _trailing(bool active, bool downloaded) {
    if (_busy) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: _progress == 0 ? null : _progress,
        ),
      );
    }
    if (downloaded && !active) {
      return PopupMenuButton<void>(
        tooltip: 'Manage download',
        onSelected: (_) => _delete(),
        itemBuilder: (context) => const [
          PopupMenuItem<void>(value: null, child: Text('Delete download')),
        ],
      );
    }
    return null;
  }
}

/// Labs self-test: transcribes a tiny bundled speech sample and shows the
/// recognized text — proves the whisper pipeline (ffmpeg → model) works offline.
/// Visible only when transcription is enabled. The sample is a synthetic,
/// license-clean clip we ship in `assets/audio/` (CLAUDE.md §10).
class _TranscriptionSelfTestTile extends ConsumerStatefulWidget {
  const _TranscriptionSelfTestTile();

  @override
  ConsumerState<_TranscriptionSelfTestTile> createState() =>
      _TranscriptionSelfTestTileState();
}

class _TranscriptionSelfTestTileState
    extends ConsumerState<_TranscriptionSelfTestTile> {
  static const _sampleAsset = 'assets/audio/transcription_sample.wav';

  bool _busy = false;
  String? _output;

  Future<void> _run() async {
    final engine = ref.read(transcriptionEngineProvider);
    setState(() {
      _busy = true;
      _output = '';
    });
    String? tempPath;
    try {
      if (!await engine.ensureReady()) {
        if (mounted) setState(() => _output = 'Download a model above first');
        return;
      }
      tempPath = await _copySampleToTemp();
      final result = await engine.transcribe(tempPath);
      if (mounted) {
        setState(
          () => _output = result.flat.isEmpty
              ? 'Ran — no speech detected in the sample'
              : 'OK — “${result.flat}”',
        );
      }
    } on InferenceException catch (e) {
      if (mounted) {
        setState(() => _output = 'Transcription failed: ${e.message}');
      }
    } finally {
      if (tempPath != null) {
        unawaited(File(tempPath).delete().then((_) {}, onError: (_) {}));
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copies the bundled sample WAV to a temp file the engine can read by path.
  Future<String> _copySampleToTemp() async {
    final bytes = await rootBundle.load(_sampleAsset);
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/transcription_selftest_'
        '${DateTime.now().microsecondsSinceEpoch}.wav';
    await File(path).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(
      settingsControllerProvider.select(
        (s) => s.value?.transcriptionEnabled ?? false,
      ),
    );
    if (!enabled) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.science_outlined),
      title: const Text('Test transcription'),
      subtitle: Text(
        _output?.isNotEmpty == true
            ? _output!
            : 'Transcribe a short sample clip on-device',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_arrow_outlined),
      onTap: _busy ? null : _run,
    );
  }
}
