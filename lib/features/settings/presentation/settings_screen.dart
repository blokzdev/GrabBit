import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/inference_engine_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/storage/cache_cleaner.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/utils/filename_template.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/pin_dialog.dart';
import 'package:grabbit/features/lock/pin_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/engine_update_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_tiles.dart';
import 'package:path_provider/path_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: const [_SettingsOverflow()],
      ),
      body: settings.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Failed to load settings: $e',
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (s) => _SettingsList(settings: s),
      ),
    );
  }
}

/// App-bar overflow: maintenance actions that don't belong inside a section.
class _SettingsOverflow extends ConsumerWidget {
  const _SettingsOverflow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'reset':
            _reset(context, ref);
          case 'cache':
            _clearCache(context);
          case 'about':
            context.push('/about');
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'reset', child: Text('Reset to defaults')),
        PopupMenuItem(value: 'cache', child: Text('Clear cache')),
        PopupMenuItem(value: 'about', child: Text('About')),
      ],
    );
  }

  Future<void> _reset(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: 'Reset to defaults?',
      message:
          'All download, appearance, storage and privacy preferences return '
          'to their defaults. Your app lock and accepted disclaimer are kept.',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!ok) return;
    await ref.read(settingsControllerProvider.notifier).resetToDefaults();
    messenger.showSnackBar(
      const SnackBar(content: Text('Settings reset to defaults')),
    );
  }

  Future<void> _clearCache(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await clearDirectory(await getTemporaryDirectory());
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.bytes == 0
              ? 'Cache already empty'
              : 'Freed ${formatBytes(result.bytes)}',
        ),
      ),
    );
  }
}

class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.settings});
  final SettingsModel settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final controller = ref.read(settingsControllerProvider.notifier);
    return ContentBounds(
      child: ListView(
        padding: EdgeInsets.only(bottom: tokens.spaceLg),
        children: [
          SettingsSection(
            icon: Icons.download_outlined,
            title: 'Downloads',
            children: [
              SettingsSwitchTile(
                title: 'Advanced mode',
                subtitle: 'Show all format and quality options',
                value: settings.mode == UiMode.advanced,
                onChanged: (v) =>
                    controller.setMode(v ? UiMode.advanced : UiMode.simple),
              ),
              SettingsChoiceTile<String>(
                title: 'Default quality',
                value: settings.defaultQuality,
                onChanged: controller.setDefaultQuality,
                items: const [
                  DropdownMenuItem(value: 'best', child: Text('Best')),
                  DropdownMenuItem(value: '1080p', child: Text('1080p')),
                  DropdownMenuItem(value: '720p', child: Text('720p')),
                  DropdownMenuItem(
                    value: 'audio_only',
                    child: Text('Audio only'),
                  ),
                ],
              ),
              SettingsChoiceTile<int>(
                title: 'Max concurrent downloads',
                value: settings.maxConcurrentDownloads,
                onChanged: controller.setMaxConcurrentDownloads,
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
              ),
              SettingsSwitchTile(
                title: 'Faster downloads (beta)',
                subtitle:
                    'Fetch video in parallel fragments for higher speed. '
                    'Experimental — uses more CPU and data.',
                value: settings.concurrentFragments > 1,
                onChanged: (v) => controller.setConcurrentFragments(v ? 4 : 1),
              ),
              SettingsSwitchTile(
                title: 'Wi-Fi only',
                subtitle: 'Pause downloads on mobile data',
                value: settings.wifiOnly,
                onChanged: controller.setWifiOnly,
              ),
              SettingsChoiceTile<int>(
                title: 'Pause when storage is low',
                subtitle: 'Hold downloads below this free space',
                value: settings.minFreeSpaceMb,
                onChanged: controller.setMinFreeSpaceMb,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Off')),
                  DropdownMenuItem(value: 500, child: Text('500 MB')),
                  DropdownMenuItem(value: 1024, child: Text('1 GB')),
                  DropdownMenuItem(value: 2048, child: Text('2 GB')),
                ],
              ),
              SettingsSwitchTile(
                title: 'Pause on low battery',
                subtitle:
                    'Hold downloads when the battery is low or in power saver',
                value: settings.pauseOnLowBattery,
                onChanged: controller.setPauseOnLowBattery,
              ),
              if (settings.pauseOnLowBattery)
                SettingsChoiceTile<int>(
                  title: 'Low-battery threshold',
                  value: settings.lowBatteryThreshold,
                  onChanged: controller.setLowBatteryThreshold,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10%')),
                    DropdownMenuItem(value: 15, child: Text('15%')),
                    DropdownMenuItem(value: 20, child: Text('20%')),
                    DropdownMenuItem(value: 30, child: Text('30%')),
                  ],
                ),
              _FilenameTemplateTile(template: settings.filenameTemplate),
              SettingsSwitchTile(
                title: 'Download subtitles',
                subtitle: 'Write and embed subtitles when available',
                value: settings.subtitleLangs.isNotEmpty,
                onChanged: (v) => controller.setSubtitleLangs(v ? 'en' : ''),
              ),
              if (settings.subtitleLangs.isNotEmpty) ...[
                _SubtitleLangsTile(langs: settings.subtitleLangs),
                SettingsSwitchTile(
                  title: 'Include auto-generated',
                  subtitle: 'Fetch auto-captions when no human ones',
                  value: settings.subtitleAuto,
                  onChanged: controller.setSubtitleAuto,
                ),
                SettingsChoiceTile<String>(
                  title: 'Subtitle format',
                  value: settings.subtitleFormat,
                  onChanged: controller.setSubtitleFormat,
                  items: const [
                    DropdownMenuItem(value: 'srt', child: Text('SRT')),
                    DropdownMenuItem(value: 'vtt', child: Text('VTT')),
                    DropdownMenuItem(value: 'ass', child: Text('ASS')),
                    DropdownMenuItem(value: 'best', child: Text('Native')),
                  ],
                ),
              ],
              SettingsSwitchTile(
                title: 'Embed thumbnail',
                value: settings.embedThumbnail,
                onChanged: controller.setEmbedThumbnail,
              ),
              SettingsSwitchTile(
                title: 'Embed metadata',
                value: settings.embedMetadata,
                onChanged: controller.setEmbedMetadata,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.notes_outlined,
            title: 'Transcripts',
            children: [
              SettingsSwitchTile(
                title: 'Auto-download captions',
                subtitle: "In the app's language, when a video has them",
                value: settings.autoDownloadCaptions,
                onChanged: controller.setAutoDownloadCaptions,
                hint: const InfoHint(
                  title: 'Auto-download captions',
                  body:
                      "Automatically save a video's captions (in the app's "
                      'language) so transcripts and summaries can be built — '
                      "even if you haven't turned on subtitles.",
                ),
              ),
              SettingsSwitchTile(
                title: 'Auto-build transcripts',
                subtitle: 'From captions, after each download',
                value: settings.autoTranscribe,
                onChanged: controller.setAutoTranscribe,
                hint: const InfoHint(
                  title: 'Auto-build transcripts',
                  body:
                      'Build a text transcript from downloaded captions '
                      'automatically, so summaries use the spoken content.',
                ),
              ),
              SettingsSwitchTile(
                title: 'Backfill transcripts on open',
                subtitle: 'For items downloaded earlier',
                value: settings.transcriptBackfill,
                onChanged: controller.setTranscriptBackfill,
                hint: const InfoHint(
                  title: 'Backfill transcripts on open',
                  body:
                      'Build transcripts for older downloads the first time '
                      'you open them, if they have caption files.',
                ),
              ),
            ],
          ),
          if (settings.mode == UiMode.advanced)
            SettingsSection(
              icon: Icons.tune,
              title: 'Advanced download options',
              children: [
                SettingsChoiceTile<int>(
                  title: 'Concurrent fragments',
                  subtitle: 'Parallel pieces per download',
                  value: settings.concurrentFragments.clamp(1, 8),
                  onChanged: controller.setConcurrentFragments,
                  items: [
                    for (var i = 1; i <= 8; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                ),
                SettingsChoiceTile<String>(
                  title: 'Download speed limit',
                  value: settings.rateLimit,
                  onChanged: controller.setRateLimit,
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Unlimited')),
                    DropdownMenuItem(value: '500K', child: Text('500 KB/s')),
                    DropdownMenuItem(value: '1M', child: Text('1 MB/s')),
                    DropdownMenuItem(value: '2M', child: Text('2 MB/s')),
                    DropdownMenuItem(value: '5M', child: Text('5 MB/s')),
                  ],
                ),
                SettingsChoiceTile<String>(
                  title: 'Audio format',
                  subtitle: 'Codec for audio-only downloads',
                  value: settings.audioFormat,
                  onChanged: controller.setAudioFormat,
                  items: const [
                    DropdownMenuItem(value: 'm4a', child: Text('M4A (AAC)')),
                    DropdownMenuItem(value: 'mp3', child: Text('MP3')),
                    DropdownMenuItem(value: 'opus', child: Text('Opus')),
                    DropdownMenuItem(value: 'vorbis', child: Text('Vorbis')),
                    DropdownMenuItem(value: 'aac', child: Text('AAC')),
                    DropdownMenuItem(value: 'flac', child: Text('FLAC')),
                    DropdownMenuItem(value: 'wav', child: Text('WAV')),
                    DropdownMenuItem(
                      value: 'best',
                      child: Text('Best (source)'),
                    ),
                  ],
                ),
                SettingsChoiceTile<String>(
                  title: 'Audio quality',
                  value: settings.audioQuality,
                  onChanged: controller.setAudioQuality,
                  items: const [
                    DropdownMenuItem(value: 'best', child: Text('Best')),
                    DropdownMenuItem(value: '320K', child: Text('320 kbps')),
                    DropdownMenuItem(value: '256K', child: Text('256 kbps')),
                    DropdownMenuItem(value: '192K', child: Text('192 kbps')),
                    DropdownMenuItem(value: '128K', child: Text('128 kbps')),
                    DropdownMenuItem(value: '96K', child: Text('96 kbps')),
                  ],
                ),
                SettingsSwitchTile(
                  title: 'Skip already-downloaded',
                  subtitle:
                      'Keep an archive of fetched items; re-adding one is '
                      'skipped (no new file).',
                  value: settings.useDownloadArchive,
                  onChanged: controller.setUseDownloadArchive,
                ),
                SettingsChoiceTile<String>(
                  title: 'SponsorBlock',
                  subtitle: 'Mark or remove sponsor segments',
                  value: settings.sponsorBlockMode,
                  onChanged: controller.setSponsorBlockMode,
                  items: const [
                    DropdownMenuItem(value: 'off', child: Text('Off')),
                    DropdownMenuItem(value: 'mark', child: Text('Mark')),
                    DropdownMenuItem(value: 'remove', child: Text('Remove')),
                  ],
                ),
                if (settings.sponsorBlockMode != 'off')
                  _SponsorCategories(selected: settings.sponsorBlockCategories),
                SettingsSwitchTile(
                  title: 'Embed chapters',
                  subtitle: 'Add chapter markers to the file',
                  value: settings.embedChapters,
                  onChanged: controller.setEmbedChapters,
                ),
                SettingsSwitchTile(
                  title: 'Split into chapters',
                  subtitle: 'Save each chapter as a separate library item',
                  value: settings.splitChapters,
                  onChanged: controller.setSplitChapters,
                ),
                _ExtraArgsTile(value: settings.extraDownloadArgs),
              ],
            ),
          SettingsSection(
            icon: Icons.system_update_alt,
            title: 'Downloader engine',
            children: [
              const _EngineUpdateTile(),
              SettingsSwitchTile(
                title: 'Check for updates on app open',
                subtitle:
                    'Keep yt-dlp current automatically (recommended for YouTube)',
                value: settings.autoCheckEngineUpdate,
                onChanged: controller.setAutoCheckEngineUpdate,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.sd_storage_outlined,
            title: 'Storage',
            children: [
              SettingsSwitchTile(
                title: 'Auto-save to device',
                subtitle: 'Export every download to your gallery folder',
                value: settings.storagePolicy == StoragePolicy.autoExport,
                onChanged: (v) => controller.setStoragePolicy(
                  v ? StoragePolicy.autoExport : StoragePolicy.private,
                ),
              ),
              ListTile(
                title: const Text('Export folder'),
                subtitle: Text(
                  settings.exportFolder ??
                      'Default: gallery (Movies/Music/Pictures/GrabBit)',
                ),
                trailing: settings.exportFolder == null
                    ? const Icon(Icons.folder_open)
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Use gallery default',
                        onPressed: () => controller.setExportFolder(null),
                      ),
                onTap: () async {
                  final uri = await ref
                      .read(mediaExportServiceProvider)
                      .pickFolder();
                  if (uri != null) await controller.setExportFolder(uri);
                },
              ),
              SettingsNavTile(
                title: 'Storage & cleanup',
                subtitle: 'Usage breakdown, largest items, duplicates',
                onTap: () => context.push('/storage'),
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              SettingsChoiceTile<ThemeChoice>(
                title: 'Theme',
                value: settings.theme,
                onChanged: controller.setTheme,
                items: const [
                  DropdownMenuItem(
                    value: ThemeChoice.system,
                    child: Text('System'),
                  ),
                  DropdownMenuItem(
                    value: ThemeChoice.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemeChoice.dark,
                    child: Text('Dark'),
                  ),
                ],
              ),
              SettingsSwitchTile(
                title: 'Dynamic color',
                subtitle: 'Use colors from your wallpaper',
                value: settings.dynamicColor,
                onChanged: controller.setDynamicColor,
              ),
              SettingsSwitchTile(
                title: 'Pure black (AMOLED)',
                subtitle: 'True-black background for the dark theme',
                value: settings.amoledDark,
                onChanged: controller.setAmoledDark,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.lock_outline,
            title: 'Security',
            children: [_AppLockSection(appLock: settings.appLock)],
          ),
          SettingsSection(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            children: [
              SettingsSwitchTile(
                title: 'Block screenshots',
                subtitle:
                    'Hide content in screenshots and the recent-apps preview',
                value: settings.blockScreenshots,
                onChanged: controller.setBlockScreenshots,
              ),
              SettingsSwitchTile(
                title: 'Secure delete',
                subtitle:
                    'Overwrite files before deleting — slower, and only '
                    'best-effort on flash storage',
                value: settings.secureDelete,
                onChanged: controller.setSecureDelete,
              ),
            ],
          ),
          SettingsSection(
            icon: Icons.hub_outlined,
            title: 'Graph database',
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
      ),
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

class _FilenameTemplateTile extends ConsumerStatefulWidget {
  const _FilenameTemplateTile({required this.template});
  final String template;

  @override
  ConsumerState<_FilenameTemplateTile> createState() =>
      _FilenameTemplateTileState();
}

class _FilenameTemplateTileState extends ConsumerState<_FilenameTemplateTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.template,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _persist(String value) =>
      ref.read(settingsControllerProvider.notifier).setFilenameTemplate(value);

  void _insert(String token) {
    final text = '${_controller.text}{$token}';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _persist(text);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Download filename', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spaceSm),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              isDense: true,
              helperText:
                  'Tap a tag to add it. The extension is added for you.',
            ),
            onChanged: (v) {
              _persist(v);
              setState(() {});
            },
          ),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: tokens.spaceSm,
            runSpacing: tokens.spaceXs,
            children: [
              for (final t in filenameTokens)
                ActionChip(
                  label: Text(t.label),
                  onPressed: () => _insert(t.key),
                ),
            ],
          ),
          SizedBox(height: tokens.spaceSm),
          Text(
            'Preview: ${renderPreview(_controller.text)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Advanced-only multi-line input for raw yt-dlp arguments (the escape hatch).
class _ExtraArgsTile extends ConsumerStatefulWidget {
  const _ExtraArgsTile({required this.value});
  final String value;

  @override
  ConsumerState<_ExtraArgsTile> createState() => _ExtraArgsTileState();
}

class _ExtraArgsTileState extends ConsumerState<_ExtraArgsTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extra yt-dlp arguments', style: theme.textTheme.titleMedium),
          SizedBox(height: tokens.spaceSm),
          TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              isDense: true,
              hintText: '--no-mtime --retries 3',
              helperText:
                  'Advanced. Passed straight to yt-dlp — wrong flags can '
                  'break downloads.',
            ),
            onChanged: (v) => ref
                .read(settingsControllerProvider.notifier)
                .setExtraDownloadArgs(v),
          ),
        ],
      ),
    );
  }
}

/// Comma-separated subtitle-language input (e.g. `en,es`).
class _SubtitleLangsTile extends ConsumerStatefulWidget {
  const _SubtitleLangsTile({required this.langs});
  final String langs;

  @override
  ConsumerState<_SubtitleLangsTile> createState() => _SubtitleLangsTileState();
}

class _SubtitleLangsTileState extends ConsumerState<_SubtitleLangsTile> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.langs,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          isDense: true,
          labelText: 'Subtitle languages',
          helperText: 'Comma-separated, e.g. en,es,en-US',
        ),
        onChanged: (v) =>
            ref.read(settingsControllerProvider.notifier).setSubtitleLangs(v),
      ),
    );
  }
}

/// Selectable SponsorBlock categories rendered as filter chips.
class _SponsorCategories extends ConsumerWidget {
  const _SponsorCategories({required this.selected});
  final String selected;

  static const _all = [
    'sponsor',
    'selfpromo',
    'interaction',
    'intro',
    'outro',
    'preview',
    'music_offtopic',
    'filler',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final current = selected.split(',').where((c) => c.isNotEmpty).toSet();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        0,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: [
          for (final cat in _all)
            FilterChip(
              label: Text(cat),
              selected: current.contains(cat),
              onSelected: (on) {
                final next = {...current};
                if (on) {
                  next.add(cat);
                } else {
                  next.remove(cat);
                }
                ref
                    .read(settingsControllerProvider.notifier)
                    .setSponsorBlockCategories(next.join(','));
              },
            ),
        ],
      ),
    );
  }
}

class _AppLockSection extends ConsumerWidget {
  const _AppLockSection({required this.appLock});
  final AppLockSettings appLock;

  static const _autoLockOptions = <int, String>{
    0: 'Immediately',
    30: 'After 30 seconds',
    60: 'After 1 minute',
    300: 'After 5 minutes',
    900: 'After 15 minutes',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.read(settingsControllerProvider.notifier);
    return Column(
      children: [
        SwitchListTile(
          title: const Text('App lock'),
          subtitle: const Text('Require a PIN to open GrabBit'),
          value: appLock.enabled,
          onChanged: (enable) async {
            if (enable) {
              final pin = await showPinDialog(context);
              if (pin == null) return;
              await ref.read(pinRepositoryProvider).setPin(pin);
              await settings.setAppLock(appLock.copyWith(enabled: true));
              ref.read(lockControllerProvider.notifier).unlock();
            } else {
              final ok = await confirm(
                context,
                title: 'Turn off app lock?',
                message: 'Your PIN will be removed.',
                confirmLabel: 'Turn off',
                destructive: true,
              );
              if (!ok) return;
              await ref.read(pinRepositoryProvider).clear();
              await settings.setAppLock(
                const AppLockSettings(enabled: false, biometric: false),
              );
            }
          },
        ),
        if (appLock.enabled) ...[
          ListTile(
            title: const Text('Change PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final pin = await showPinDialog(context, title: 'Change PIN');
              if (pin == null) return;
              await ref.read(pinRepositoryProvider).setPin(pin);
            },
          ),
          SwitchListTile(
            title: const Text('Biometric unlock'),
            subtitle: const Text('Use fingerprint or face to unlock'),
            value: appLock.biometric,
            onChanged: (v) =>
                settings.setAppLock(appLock.copyWith(biometric: v)),
          ),
          ListTile(
            title: const Text('Auto-lock'),
            subtitle: const Text('Re-lock after leaving the app'),
            trailing: DropdownButton<int>(
              value: appLock.autoLockSeconds,
              onChanged: (v) => v == null
                  ? null
                  : settings.setAppLock(appLock.copyWith(autoLockSeconds: v)),
              items: [
                for (final entry in _autoLockOptions.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _EngineUpdateTile extends ConsumerWidget {
  const _EngineUpdateTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(engineUpdateControllerProvider);
    final data = state.asData?.value;
    final updating = data?.updating ?? false;
    return ListTile(
      title: const Text('yt-dlp'),
      subtitle: Text(
        data?.message ??
            (data?.version != null ? 'Version ${data!.version}' : 'Loading…'),
      ),
      trailing: updating
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () =>
                  ref.read(engineUpdateControllerProvider.notifier).runUpdate(),
              child: const Text('Update'),
            ),
    );
  }
}
