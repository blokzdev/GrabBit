import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/storage/cache_cleaner.dart';
import 'package:grabbit/core/storage/media_export_service.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/utils/byte_format.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/lock/lock_controller.dart';
import 'package:grabbit/features/lock/pin_dialog.dart';
import 'package:grabbit/features/lock/pin_repository.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/engine_update_controller.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';
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

/// App-bar overflow: a shortcut to the same maintenance actions surfaced in the
/// General section below.
class _SettingsOverflow extends ConsumerWidget {
  const _SettingsOverflow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'reset':
            confirmResetSettings(context, ref);
          case 'cache':
            clearAppCache(context);
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
}

/// Confirms, then resets all preferences to their defaults (app lock + accepted
/// disclaimer are kept). Shared by the overflow menu and the General section.
Future<void> confirmResetSettings(BuildContext context, WidgetRef ref) async {
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

/// Clears the app's temporary directory and reports the bytes freed.
Future<void> clearAppCache(BuildContext context) async {
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

/// The settings landing: links to the heavy sub-screens, the small/stable
/// sections inline, and a General section for maintenance.
class _SettingsList extends ConsumerWidget {
  const _SettingsList({required this.settings});
  final SettingsModel settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final controller = ref.read(settingsControllerProvider.notifier);
    return ContentBounds(
      child: ListView(
        padding: EdgeInsets.only(top: tokens.spaceLg, bottom: tokens.spaceLg),
        children: [
          SettingsCard(
            children: [
              SettingsNavTile(
                leading: Icons.download_outlined,
                title: 'Downloads',
                subtitle: 'Quality, format, filename, advanced options',
                onTap: () => context.push('/settings/downloads'),
              ),
              SettingsNavTile(
                leading: Icons.closed_caption_outlined,
                title: 'Captions & transcripts',
                subtitle: 'Download captions and build transcripts',
                onTap: () => context.push('/settings/captions'),
              ),
              SettingsNavTile(
                leading: Icons.hub_outlined,
                title: 'AI & graph',
                subtitle: 'Semantic search and the on-device graph',
                onTap: () => context.push('/settings/ai'),
              ),
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
            icon: Icons.settings_outlined,
            title: 'General',
            children: [
              SettingsNavTile(
                leading: Icons.info_outline,
                title: 'About',
                subtitle: 'Version, licenses, donations',
                onTap: () => context.push('/about'),
              ),
              ListTile(
                leading: const Icon(Icons.restore),
                title: const Text('Reset to defaults'),
                subtitle: const Text(
                  'Restore download, appearance, storage & privacy prefs',
                ),
                onTap: () => confirmResetSettings(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Clear cache'),
                subtitle: const Text('Free temporary working files'),
                onTap: () => clearAppCache(context),
              ),
            ],
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
