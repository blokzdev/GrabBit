import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
import 'package:grabbit/features/settings/presentation/widgets/info_hint.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_section.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_subscaffold.dart';
import 'package:grabbit/features/settings/presentation/widgets/settings_tiles.dart';

/// `/settings/notifications` — the Activity Inbox preferences (P11b): how long
/// to keep entries, and which categories to record. Errors and system notices
/// are always recorded regardless of the per-category toggles.
class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubScaffold(
      title: 'Notifications',
      children: (context, ref, settings) {
        final controller = ref.read(settingsControllerProvider.notifier);
        return [
          SettingsCard(
            children: [
              SettingsChoiceTile<int>(
                title: 'Keep notifications',
                subtitle: 'Older entries are cleared automatically',
                value: settings.notificationRetentionDays,
                onChanged: controller.setNotificationRetentionDays,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Forever')),
                  DropdownMenuItem(value: 7, child: Text('7 days')),
                  DropdownMenuItem(value: 14, child: Text('14 days')),
                  DropdownMenuItem(value: 30, child: Text('30 days')),
                  DropdownMenuItem(value: 90, child: Text('90 days')),
                ],
                hint: const InfoHint(
                  title: 'Keep notifications',
                  body:
                      'How long the Activity Inbox keeps an entry before '
                      'clearing it. "Forever" never auto-clears. The cleanup '
                      'runs when you open the app.',
                ),
              ),
              const Divider(height: 1),
              SettingsSwitchTile(
                title: 'Download activity',
                subtitle: 'Completed and failed downloads',
                value: settings.notifyDownload,
                onChanged: controller.setNotifyDownload,
                hint: const InfoHint(
                  title: 'Download activity',
                  body:
                      'Record an inbox entry when a download finishes or '
                      'fails. Failures are always recorded even when this is '
                      'off.',
                ),
              ),
              SettingsSwitchTile(
                title: 'Transcript activity',
                subtitle: 'Built and backfilled transcripts',
                value: settings.notifyTranscript,
                onChanged: controller.setNotifyTranscript,
                hint: const InfoHint(
                  title: 'Transcript activity',
                  body:
                      'Record an inbox entry when a transcript is built for a '
                      'download.',
                ),
              ),
              SettingsSwitchTile(
                title: 'AI activity',
                subtitle: 'On-device AI tasks',
                value: settings.notifyAi,
                onChanged: controller.setNotifyAi,
                hint: const InfoHint(
                  title: 'AI activity',
                  body:
                      'Record an inbox entry for on-device AI work such as '
                      'semantic-index updates.',
                ),
              ),
              SettingsSwitchTile(
                title: 'Graph activity',
                subtitle: 'Relationship-graph index rebuilds',
                value: settings.notifyGraph,
                onChanged: controller.setNotifyGraph,
                hint: const InfoHint(
                  title: 'Graph activity',
                  body:
                      'Record an inbox entry when the on-device relationship '
                      'graph is rebuilt.',
                ),
              ),
            ],
          ),
        ];
      },
    );
  }
}
