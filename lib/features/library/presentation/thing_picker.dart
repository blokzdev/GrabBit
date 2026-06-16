import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/thing_cards.dart';
import 'package:grabbit/features/library/presentation/things_browser_screen.dart';

/// A searchable bottom-sheet picker over the Things graph (P16e); resolves to the
/// chosen [Thing] (or null if dismissed). [excludeId] drops one Thing (the one
/// you're linking *from*). Mirrors the library `item_picker` idiom.
Future<Thing?> pickThing(
  BuildContext context, {
  required String excludeId,
  String title = 'Link to a Thing',
}) {
  return showModalBottomSheet<Thing>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ThingPickerSheet(excludeId: excludeId, title: title),
  );
}

class _ThingPickerSheet extends ConsumerStatefulWidget {
  const _ThingPickerSheet({required this.excludeId, required this.title});

  final String excludeId;
  final String title;

  @override
  ConsumerState<_ThingPickerSheet> createState() => _ThingPickerSheetState();
}

class _ThingPickerSheetState extends ConsumerState<_ThingPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final all = ref.watch(allThingsProvider).asData?.value ?? const [];
    final q = _query.trim().toLowerCase();
    final things = [
      for (final t in all)
        if (t.id != widget.excludeId &&
            (q.isEmpty ||
                (t.name ?? '').toLowerCase().contains(q) ||
                t.type.toLowerCase().contains(q)))
          t,
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
                hintText: 'Search Things',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            SizedBox(height: tokens.spaceSm),
            Flexible(
              child: things.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: EmptyState(
                        icon: Icons.search_off,
                        title: 'No Things',
                        message: 'Try a different search.',
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: things.length,
                      itemBuilder: (context, i) {
                        final thing = things[i];
                        return ListTile(
                          leading: Icon(iconForThingType(thing.type)),
                          title: Text(
                            thing.name ?? thing.type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            thingListSummary(thing) ?? thing.type,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(thing),
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
