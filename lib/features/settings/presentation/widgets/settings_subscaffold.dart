import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/skeleton.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// Builds the rows for a settings sub-screen once [settings] has loaded.
typedef SettingsChildrenBuilder =
    List<Widget> Function(
      BuildContext context,
      WidgetRef ref,
      SettingsModel settings,
    );

/// Shared chrome for a settings sub-screen (`/settings/...`): an [AppBar] (which
/// names the group, so cards inside need no redundant header) over a
/// [ContentBounds] + scrolling list, with the same async/error handling as the
/// main settings screen. Mirrors the `/storage` and `/about` pattern.
class SettingsSubScaffold extends ConsumerWidget {
  const SettingsSubScaffold({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final SettingsChildrenBuilder children;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final settings = ref.watch(settingsControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: settings.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => ErrorView(
          message: 'Failed to load settings: $e',
          onRetry: () => ref.invalidate(settingsControllerProvider),
        ),
        data: (s) => ContentBounds(
          child: ListView(
            padding: EdgeInsets.only(
              top: tokens.spaceLg,
              bottom: tokens.spaceLg,
            ),
            children: children(context, ref, s),
          ),
        ),
      ),
    );
  }
}
