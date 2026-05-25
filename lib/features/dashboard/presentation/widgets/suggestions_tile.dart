import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/presentation/suggested_albums_provider.dart';

/// Dashboard "Suggested for you" tile: up to [maxShown] on-device similarity
/// clusters (P10c-d-2). Auto-hides when AI is off or nothing clusters (the
/// provider returns `[]`), mirroring the Collections "Suggested" section.
class SuggestionsTile extends ConsumerWidget {
  const SuggestionsTile({this.maxShown = 3, super.key});

  final int maxShown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums =
        ref.watch(suggestedAlbumsProvider).asData?.value ??
        const <SuggestedAlbum>[];
    if (albums.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Suggested for you', icon: Icons.auto_awesome),
        for (final album in albums.take(maxShown))
          ListTile(
            leading: CircleAvatar(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              child: const Icon(Icons.auto_awesome_outlined),
            ),
            title: Text(album.label),
            subtitle: Text(
              '${album.items.length} item${album.items.length == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/suggested-album', extra: album),
          ),
      ],
    );
  }
}
