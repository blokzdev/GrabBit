import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/graph/graph_error.dart';
import 'package:grabbit/core/graph/graph_store_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App identity, version, licenses, and a link back to the user-responsibility
/// disclaimer. Pure on-device; no network.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ContentBounds(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            SizedBox(height: tokens.spaceLg),
            SvgPicture.asset(
              'assets/brand/logo.svg',
              height: 72,
              semanticsLabel: 'GrabBit',
            ),
            SizedBox(height: tokens.spaceLg),
            Text(
              'GrabBit',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spaceXs),
            const _Version(),
            SizedBox(height: tokens.spaceMd),
            Text(
              'A free, privacy-first downloader and private media manager. '
              'Everything runs on your device; nothing leaves it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: tokens.spaceXl),
            Card(
              margin: EdgeInsets.zero,
              color: theme.colorScheme.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(tokens.radiusLg),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Open-source licenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showLicenses(context),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_user_outlined),
                    title: const Text('User responsibility & disclaimer'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/disclaimer'),
                  ),
                  const _GraphSelfTestTile(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLicenses(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: 'GrabBit',
      applicationVersion: 'v${info.version} (build ${info.buildNumber})',
    );
  }
}

/// On-device diagnostics for the graph engine (P10a): opens the Cozo store,
/// ensures the schema, and reports availability + relation count via a snackbar.
/// The only on-device verification surface for the foundation PR.
class _GraphSelfTestTile extends ConsumerWidget {
  const _GraphSelfTestTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.hub_outlined),
      title: const Text('Graph engine self-test'),
      subtitle: const Text('Verify the on-device graph database'),
      trailing: const Icon(Icons.play_arrow_outlined),
      onTap: () => _run(context, ref),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final store = ref.read(graphStoreProvider);
    String message;
    try {
      final opened = await store.open();
      if (!opened || !store.isAvailable) {
        message = 'Graph engine unavailable on this device';
      } else {
        final res = await store.runScript('::relations');
        final count = (res['rows'] as List?)?.length ?? 0;
        message = 'Graph OK — $count relations ready';
      }
    } on GraphException catch (e) {
      message = 'Graph self-test failed: ${e.message}';
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Renders the app version once `PackageInfo` resolves.
class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null
            ? '…'
            : 'v${info.version} (build ${info.buildNumber})';
        return Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }
}
