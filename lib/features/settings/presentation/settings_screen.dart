import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settings.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load settings: $e')),
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
    final controller = ref.read(settingsControllerProvider.notifier);
    return ListView(
      children: [
        const _SectionHeader('Downloads'),
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
              DropdownMenuItem(value: 'audio_only', child: Text('Audio only')),
            ],
          ),
        ),
        ListTile(
          title: const Text('Max concurrent downloads'),
          trailing: DropdownButton<int>(
            value: settings.maxConcurrentDownloads,
            onChanged: (v) =>
                v == null ? null : controller.setMaxConcurrentDownloads(v),
            items: [
              for (var i = 1; i <= 5; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Wi-Fi only'),
          subtitle: const Text('Pause downloads on mobile data'),
          value: settings.wifiOnly,
          onChanged: controller.setWifiOnly,
        ),
        const Divider(),
        const _SectionHeader('Storage'),
        SwitchListTile(
          title: const Text('Auto-save to device'),
          subtitle: const Text('Export every download to your gallery folder'),
          value: settings.storagePolicy == StoragePolicy.autoExport,
          onChanged: (v) => controller.setStoragePolicy(
            v ? StoragePolicy.autoExport : StoragePolicy.private,
          ),
        ),
        ListTile(
          title: const Text('Export folder'),
          subtitle: Text(
            settings.exportFolder == null
                ? 'Default: gallery (Movies/Music/Pictures/GrabBit)'
                : settings.exportFolder!,
          ),
          trailing: settings.exportFolder == null
              ? const Icon(Icons.folder_open)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Use gallery default',
                  onPressed: () => controller.setExportFolder(null),
                ),
          onTap: () async {
            final uri = await ref.read(mediaExportServiceProvider).pickFolder();
            if (uri != null) await controller.setExportFolder(uri);
          },
        ),
        const Divider(),
        const _SectionHeader('Appearance'),
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
              DropdownMenuItem(value: ThemeChoice.light, child: Text('Light')),
              DropdownMenuItem(value: ThemeChoice.dark, child: Text('Dark')),
            ],
          ),
        ),
        SwitchListTile(
          title: const Text('Dynamic color'),
          subtitle: const Text('Use colors from your wallpaper'),
          value: settings.dynamicColor,
          onChanged: controller.setDynamicColor,
        ),
        const Divider(),
        const _SectionHeader('Security'),
        const ListTile(
          enabled: false,
          title: Text('App lock'),
          subtitle: Text('PIN and biometric lock — coming in P2-C'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
