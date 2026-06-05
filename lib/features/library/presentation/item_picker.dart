import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';

/// A searchable bottom-sheet picker over the library; resolves to the chosen
/// item id (or `null` if dismissed). [excludeId] drops one item from the list
/// (e.g. the item you're relating *from*). Reuses the pick-list sheet idiom.
Future<String?> pickLibraryItem(
  BuildContext context, {
  required String excludeId,
  String title = 'Pick an item',
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ItemPickerSheet(excludeId: excludeId, title: title),
  );
}

class _ItemPickerSheet extends ConsumerStatefulWidget {
  const _ItemPickerSheet({required this.excludeId, required this.title});

  final String excludeId;
  final String title;

  @override
  ConsumerState<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends ConsumerState<_ItemPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final all = ref.watch(libraryItemsProvider).asData?.value ?? const [];
    final q = _query.trim().toLowerCase();
    final items = [
      for (final m in all)
        if (m.id != widget.excludeId &&
            (q.isEmpty || m.title.toLowerCase().contains(q)))
          m,
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceMd,
          0,
          tokens.spaceMd,
          tokens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: tokens.spaceSm),
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search your library',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: tokens.spaceSm),
            Flexible(
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No items',
                        message: 'Try a different search.',
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              tokens.radiusSm,
                            ),
                            child: SizedBox(
                              width: 56,
                              height: 38,
                              child: MediaThumb(item: item),
                            ),
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(item.site),
                          onTap: () => Navigator.of(context).pop(item.id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
