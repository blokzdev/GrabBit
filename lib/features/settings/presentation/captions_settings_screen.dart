import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_subscaffold.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_tiles.dart';

/// `/settings/captions` — the caption download → transcript pipeline (P10j-b),
/// now on its own screen.
class CaptionsSettingsScreen extends ConsumerWidget {
  const CaptionsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubScaffold(
      title: 'Captions & transcripts',
      children: (context, ref, settings) {
        final controller = ref.read(settingsControllerProvider.notifier);
        return [
          SettingsCard(
            children: [
              // Captions: the text tracks yt-dlp downloads alongside the media.
              SettingsSwitchTile(
                title: 'Download captions',
                subtitle: 'Save caption tracks alongside the video',
                value: settings.subtitleLangs.isNotEmpty,
                onChanged: (v) => controller.setSubtitleLangs(v ? 'en' : ''),
                hint: const InfoHint(
                  title: 'Captions',
                  body:
                      'Captions are the text tracks (subtitles) GrabBit saves '
                      'with a download. GrabBit can also turn them into a '
                      'searchable transcript below.',
                ),
              ),
              if (settings.subtitleLangs.isNotEmpty) ...[
                _SubtitleLangsTile(langs: settings.subtitleLangs),
                SettingsSwitchTile(
                  title: 'Include auto-generated',
                  subtitle: 'Use auto-captions when there are no human ones',
                  value: settings.subtitleAuto,
                  onChanged: controller.setSubtitleAuto,
                ),
                SettingsChoiceTile<String>(
                  title: 'Caption format',
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
              const Divider(height: 1),
              // Transcript: the searchable text GrabBit extracts from captions.
              SettingsSwitchTile(
                title: 'Build a searchable transcript',
                subtitle: 'Extract text from captions after each download',
                value: settings.autoTranscribe,
                onChanged: controller.setAutoTranscribe,
                hint: const InfoHint(
                  title: 'Transcript',
                  body:
                      'A transcript is the searchable text GrabBit extracts '
                      "from a download's captions. It powers summaries and "
                      'full-text search of what was said.',
                ),
              ),
              SettingsSwitchTile(
                title: 'Backfill on open',
                subtitle:
                    'Also build transcripts for older downloads when you '
                    'open them',
                value: settings.transcriptBackfill,
                onChanged: controller.setTranscriptBackfill,
                hint: const InfoHint(
                  title: 'Backfill on open',
                  body:
                      'The first time you open an older download that has '
                      'captions but no transcript yet, GrabBit builds one.',
                ),
              ),
              SettingsSwitchTile(
                title: 'Auto-fetch captions for transcripts',
                subtitle:
                    "In the app's language, when you haven't picked caption "
                    'languages above',
                value: settings.autoDownloadCaptions,
                onChanged: controller.setAutoDownloadCaptions,
                hint: const InfoHint(
                  title: 'Auto-fetch captions for transcripts',
                  body:
                      "When you haven't chosen caption languages above, "
                      "GrabBit fetches captions in the app's language "
                      '(auto-generated if needed) on every download so a '
                      'transcript can be built. Caption languages you pick '
                      'above take priority.',
                ),
              ),
            ],
          ),
        ];
      },
    );
  }
}

/// Comma-separated caption-language input (e.g. `en,es`).
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
          labelText: 'Caption languages',
          helperText: 'Comma-separated, e.g. en,es,en-US',
        ),
        onChanged: (v) =>
            ref.read(settingsControllerProvider.notifier).setSubtitleLangs(v),
      ),
    );
  }
}
