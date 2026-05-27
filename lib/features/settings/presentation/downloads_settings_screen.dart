import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/filename_template.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_subscaffold.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_tiles.dart';

/// `/settings/downloads` — download behaviour plus (in Advanced mode) the
/// power-user options.
class DownloadsSettingsScreen extends ConsumerWidget {
  const DownloadsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubScaffold(
      title: 'Downloads',
      children: (context, ref, settings) {
        final controller = ref.read(settingsControllerProvider.notifier);
        return [
          SettingsCard(
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
        ];
      },
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
