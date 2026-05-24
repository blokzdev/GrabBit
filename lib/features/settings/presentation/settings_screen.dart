import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/filename_template.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/pin_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/engine_update_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
          _Section(
            icon: Icons.download_outlined,
            title: 'Downloads',
            children: [
              SwitchListTile(
                title: const Text('Advanced mode'),
                subtitle: const Text('Show all format and quality options'),
                value: settings.mode == UiMode.advanced,
                onChanged: (v) =>
                    controller.setMode(v ? UiMode.advanced : UiMode.simple),
              ),
              ListTile(
                title: const Text('Default quality'),
                trailing: DropdownButton<String>(
                  value: settings.defaultQuality,
                  onChanged: (v) =>
                      v == null ? null : controller.setDefaultQuality(v),
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
              ),
              ListTile(
                title: const Text('Max concurrent downloads'),
                trailing: DropdownButton<int>(
                  value: settings.maxConcurrentDownloads,
                  onChanged: (v) => v == null
                      ? null
                      : controller.setMaxConcurrentDownloads(v),
                  items: [
                    for (var i = 1; i <= 5; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('Faster downloads (beta)'),
                subtitle: const Text(
                  'Fetch video in parallel fragments for higher speed. '
                  'Experimental — uses more CPU and data.',
                ),
                value: settings.concurrentFragments > 1,
                onChanged: (v) => controller.setConcurrentFragments(v ? 4 : 1),
              ),
              SwitchListTile(
                title: const Text('Wi-Fi only'),
                subtitle: const Text('Pause downloads on mobile data'),
                value: settings.wifiOnly,
                onChanged: controller.setWifiOnly,
              ),
              _FilenameTemplateTile(template: settings.filenameTemplate),
              SwitchListTile(
                title: const Text('Download subtitles'),
                subtitle: const Text(
                  'Write and embed subtitles when available',
                ),
                value: settings.subtitleLangs.isNotEmpty,
                onChanged: (v) => controller.setSubtitleLangs(v ? 'en' : ''),
              ),
              if (settings.subtitleLangs.isNotEmpty) ...[
                _SubtitleLangsTile(langs: settings.subtitleLangs),
                SwitchListTile(
                  title: const Text('Include auto-generated'),
                  subtitle: const Text(
                    'Fetch auto-captions when no human ones',
                  ),
                  value: settings.subtitleAuto,
                  onChanged: controller.setSubtitleAuto,
                ),
                ListTile(
                  title: const Text('Subtitle format'),
                  trailing: DropdownButton<String>(
                    value: settings.subtitleFormat,
                    onChanged: (v) =>
                        v == null ? null : controller.setSubtitleFormat(v),
                    items: const [
                      DropdownMenuItem(value: 'srt', child: Text('SRT')),
                      DropdownMenuItem(value: 'vtt', child: Text('VTT')),
                      DropdownMenuItem(value: 'ass', child: Text('ASS')),
                      DropdownMenuItem(value: 'best', child: Text('Native')),
                    ],
                  ),
                ),
              ],
              SwitchListTile(
                title: const Text('Embed thumbnail'),
                value: settings.embedThumbnail,
                onChanged: controller.setEmbedThumbnail,
              ),
              SwitchListTile(
                title: const Text('Embed metadata'),
                value: settings.embedMetadata,
                onChanged: controller.setEmbedMetadata,
              ),
            ],
          ),
          if (settings.mode == UiMode.advanced)
            _Section(
              icon: Icons.tune,
              title: 'Advanced download options',
              children: [
                ListTile(
                  title: const Text('Concurrent fragments'),
                  subtitle: const Text('Parallel pieces per download'),
                  trailing: DropdownButton<int>(
                    value: settings.concurrentFragments.clamp(1, 8),
                    onChanged: (v) =>
                        v == null ? null : controller.setConcurrentFragments(v),
                    items: [
                      for (var i = 1; i <= 8; i++)
                        DropdownMenuItem(value: i, child: Text('$i')),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Download speed limit'),
                  trailing: DropdownButton<String>(
                    value: settings.rateLimit,
                    onChanged: (v) =>
                        v == null ? null : controller.setRateLimit(v),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Unlimited')),
                      DropdownMenuItem(value: '500K', child: Text('500 KB/s')),
                      DropdownMenuItem(value: '1M', child: Text('1 MB/s')),
                      DropdownMenuItem(value: '2M', child: Text('2 MB/s')),
                      DropdownMenuItem(value: '5M', child: Text('5 MB/s')),
                    ],
                  ),
                ),
                ListTile(
                  title: const Text('Audio format'),
                  subtitle: const Text('Codec for audio-only downloads'),
                  trailing: DropdownButton<String>(
                    value: settings.audioFormat,
                    onChanged: (v) =>
                        v == null ? null : controller.setAudioFormat(v),
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
                ),
                ListTile(
                  title: const Text('Audio quality'),
                  trailing: DropdownButton<String>(
                    value: settings.audioQuality,
                    onChanged: (v) =>
                        v == null ? null : controller.setAudioQuality(v),
                    items: const [
                      DropdownMenuItem(value: 'best', child: Text('Best')),
                      DropdownMenuItem(value: '320K', child: Text('320 kbps')),
                      DropdownMenuItem(value: '256K', child: Text('256 kbps')),
                      DropdownMenuItem(value: '192K', child: Text('192 kbps')),
                      DropdownMenuItem(value: '128K', child: Text('128 kbps')),
                      DropdownMenuItem(value: '96K', child: Text('96 kbps')),
                    ],
                  ),
                ),
                SwitchListTile(
                  title: const Text('Skip already-downloaded'),
                  subtitle: const Text(
                    'Keep an archive of fetched items; re-adding one is '
                    'skipped (no new file).',
                  ),
                  value: settings.useDownloadArchive,
                  onChanged: controller.setUseDownloadArchive,
                ),
                ListTile(
                  title: const Text('SponsorBlock'),
                  subtitle: const Text('Mark or remove sponsor segments'),
                  trailing: DropdownButton<String>(
                    value: settings.sponsorBlockMode,
                    onChanged: (v) =>
                        v == null ? null : controller.setSponsorBlockMode(v),
                    items: const [
                      DropdownMenuItem(value: 'off', child: Text('Off')),
                      DropdownMenuItem(value: 'mark', child: Text('Mark')),
                      DropdownMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
                if (settings.sponsorBlockMode != 'off')
                  _SponsorCategories(selected: settings.sponsorBlockCategories),
                SwitchListTile(
                  title: const Text('Embed chapters'),
                  subtitle: const Text('Add chapter markers to the file'),
                  value: settings.embedChapters,
                  onChanged: controller.setEmbedChapters,
                ),
                SwitchListTile(
                  title: const Text('Split into chapters'),
                  subtitle: const Text(
                    'Save each chapter as a separate library item',
                  ),
                  value: settings.splitChapters,
                  onChanged: controller.setSplitChapters,
                ),
                _ExtraArgsTile(value: settings.extraDownloadArgs),
              ],
            ),
          _Section(
            icon: Icons.system_update_alt,
            title: 'Downloader engine',
            children: [
              const _EngineUpdateTile(),
              SwitchListTile(
                title: const Text('Check for updates on app open'),
                subtitle: const Text(
                  'Keep yt-dlp current automatically (recommended for YouTube)',
                ),
                value: settings.autoCheckEngineUpdate,
                onChanged: controller.setAutoCheckEngineUpdate,
              ),
            ],
          ),
          _Section(
            icon: Icons.sd_storage_outlined,
            title: 'Storage',
            children: [
              SwitchListTile(
                title: const Text('Auto-save to device'),
                subtitle: const Text(
                  'Export every download to your gallery folder',
                ),
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
              ListTile(
                title: const Text('Storage & cleanup'),
                subtitle: const Text(
                  'Usage breakdown, largest items, duplicates',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/storage'),
              ),
            ],
          ),
          _Section(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            children: [
              ListTile(
                title: const Text('Theme'),
                trailing: DropdownButton<ThemeChoice>(
                  value: settings.theme,
                  onChanged: (v) => v == null ? null : controller.setTheme(v),
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
              ),
              SwitchListTile(
                title: const Text('Dynamic color'),
                subtitle: const Text('Use colors from your wallpaper'),
                value: settings.dynamicColor,
                onChanged: controller.setDynamicColor,
              ),
            ],
          ),
          _Section(
            icon: Icons.lock_outline,
            title: 'Security',
            children: [_AppLockSection(appLock: settings.appLock)],
          ),
        ],
      ),
    );
  }
}

/// A titled, icon-led settings section: a [SectionHeader] above a rounded card
/// holding the section's rows.
class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, icon: icon),
        Card(
          margin: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceLg,
          ),
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusLg),
          ),
          child: Column(children: children),
        ),
      ],
    );
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
              final pin = await _askPin(context);
              if (pin == null) return;
              await ref.read(pinRepositoryProvider).setPin(pin);
              await settings.setAppLock(appLock.copyWith(enabled: true));
              ref.read(lockControllerProvider.notifier).unlock();
            } else {
              await ref.read(pinRepositoryProvider).clear();
              await settings.setAppLock(
                const AppLockSettings(enabled: false, biometric: false),
              );
            }
          },
        ),
        if (appLock.enabled)
          SwitchListTile(
            title: const Text('Biometric unlock'),
            subtitle: const Text('Use fingerprint or face to unlock'),
            value: appLock.biometric,
            onChanged: (v) =>
                settings.setAppLock(appLock.copyWith(biometric: v)),
          ),
      ],
    );
  }

  Future<String?> _askPin(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set a PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'At least 4 digits'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().length >= 4) {
                Navigator.of(context).pop(controller.text.trim());
              }
            },
            child: const Text('Set'),
          ),
        ],
      ),
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
