import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/authored_edge_predicates.dart';
import 'package:grabbit/features/library/data/authored_edge_service.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/thing_picker.dart';

enum _RelKind { link, note }

/// The P16e authoring entry point from a Thing's detail: pick whether to author a
/// plain link (ADR-0004 kind 2) or a reified note connecting two Things (kind 3),
/// run the flow, persist via [AuthoredEdgeService], and refresh the relationships.
Future<void> showAddRelationship(
  BuildContext context,
  WidgetRef ref,
  Thing thing,
) async {
  final kind = await showModalBottomSheet<_RelKind>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_link),
            title: const Text('Link to a Thing'),
            subtitle: const Text('Relate this to another Thing'),
            onTap: () => Navigator.of(context).pop(_RelKind.link),
          ),
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined),
            title: const Text('Write a note connecting two Things'),
            subtitle: const Text('Saved as its own note Thing'),
            onTap: () => Navigator.of(context).pop(_RelKind.note),
          ),
        ],
      ),
    ),
  );
  if (kind == null || !context.mounted) return;
  switch (kind) {
    case _RelKind.link:
      await _authorLink(context, ref, thing);
    case _RelKind.note:
      await _authorNote(context, ref, thing);
  }
}

Future<void> _authorLink(
  BuildContext context,
  WidgetRef ref,
  Thing thing,
) async {
  final target = await pickThing(context, excludeId: thing.id);
  if (target == null || !context.mounted) return;
  final details = await showDialog<({String predicate, String? note})>(
    context: context,
    builder: (context) =>
        _LinkDetailsDialog(targetName: target.name ?? target.type),
  );
  if (details == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  await ref
      .read(authoredEdgeServiceProvider)
      .addLink(
        subject: thing.id,
        object: target.id,
        predicate: details.predicate,
        note: details.note,
      );
  ref.invalidate(thingRelationshipsProvider(thing.id));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text('Linked to ${target.name ?? target.type}')),
    );
}

Future<void> _authorNote(
  BuildContext context,
  WidgetRef ref,
  Thing thing,
) async {
  final target = await pickThing(
    context,
    excludeId: thing.id,
    title: 'Connect to which Thing?',
  );
  if (target == null || !context.mounted) return;
  final text = await showDialog<String>(
    context: context,
    builder: (context) => const _NoteTextDialog(),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  await ref
      .read(authoredEdgeServiceProvider)
      .addNote(subjectId: thing.id, objectId: target.id, text: text);
  ref.invalidate(thingRelationshipsProvider(thing.id));
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(const SnackBar(content: Text('Note added')));
}

class _LinkDetailsDialog extends StatefulWidget {
  const _LinkDetailsDialog({required this.targetName});

  final String targetName;

  @override
  State<_LinkDetailsDialog> createState() => _LinkDetailsDialogState();
}

class _LinkDetailsDialogState extends State<_LinkDetailsDialog> {
  String _predicate = kAuthoredEdgePredicates.first;
  bool _custom = false;
  final _customController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return AlertDialog(
      title: Text('Link to ${widget.targetName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Relationship'),
            SizedBox(height: tokens.spaceSm),
            Wrap(
              spacing: tokens.spaceSm,
              children: [
                for (final p in kAuthoredEdgePredicates)
                  ChoiceChip(
                    label: Text(p),
                    selected: !_custom && _predicate == p,
                    onSelected: (_) => setState(() {
                      _custom = false;
                      _predicate = p;
                    }),
                  ),
                ChoiceChip(
                  label: const Text('Custom…'),
                  selected: _custom,
                  onSelected: (_) => setState(() => _custom = true),
                ),
              ],
            ),
            if (_custom)
              TextField(
                controller: _customController,
                decoration: const InputDecoration(labelText: 'Custom label'),
              ),
            SizedBox(height: tokens.spaceMd),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final predicate = _custom
                ? _customController.text.trim()
                : _predicate;
            if (predicate.isEmpty) return;
            final note = _noteController.text.trim();
            Navigator.of(
              context,
            ).pop((predicate: predicate, note: note.isEmpty ? null : note));
          },
          child: const Text('Link'),
        ),
      ],
    );
  }
}

class _NoteTextDialog extends StatefulWidget {
  const _NoteTextDialog();

  @override
  State<_NoteTextDialog> createState() => _NoteTextDialogState();
}

class _NoteTextDialogState extends State<_NoteTextDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Write a note'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'What connects these two Things?',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
