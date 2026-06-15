import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// The unified "Grab anything" intake menu (P16) — a modal bottom sheet listing
/// every way into the library. P16b-1 offers downloading a link and manual entry;
/// later sub-PRs append web-page, file, and barcode rows.
Future<void> showGrabSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => const _GrabSheet(),
  );
}

class _GrabSheet extends StatelessWidget {
  const _GrabSheet();

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLg,
              tokens.spaceSm,
              tokens.spaceLg,
              tokens.spaceSm,
            ),
            child: Text(
              'Grab anything',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const _GrabOption(
            icon: Icons.link,
            title: 'Paste a link to download',
            subtitle: 'Save a video, audio, or page from a URL',
            route: '/add',
          ),
          const _GrabOption(
            icon: Icons.language,
            title: 'Grab a web page',
            subtitle: 'Capture an article, recipe, product… as a Thing',
            route: '/grab/web',
          ),
          const _GrabOption(
            icon: Icons.edit_outlined,
            title: 'Write a note or add manually',
            subtitle: 'Create a Thing yourself — a note, recipe, place…',
            route: '/grab/manual',
          ),
          SizedBox(height: tokens.spaceSm),
        ],
      ),
    );
  }
}

class _GrabOption extends StatelessWidget {
  const _GrabOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: scheme.secondaryContainer,
        foregroundColor: scheme.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () {
        // Capture the router before popping the sheet so the push targets the
        // root navigator, not the dismissed modal route.
        final router = GoRouter.of(context);
        Navigator.of(context).pop();
        router.push(route);
      },
    );
  }
}
