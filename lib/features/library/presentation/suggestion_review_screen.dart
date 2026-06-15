import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/confirm_dialog.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/features/library/data/suggestion_review_service.dart';

/// P15d — the confirmation surface. Renders an item's pending AI-extracted
/// suggestions as review cards (type + fields + confidence) with Accept / Edit /
/// Reject. Reached from the Activity-Inbox entry and the post-extract "Review"
/// SnackBar. Asserting a Thing into the library happens only here, on confirm.
class SuggestionReviewScreen extends ConsumerWidget {
  const SuggestionReviewScreen({required this.itemId, super.key});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final suggestions = ref.watch(suggestionsForItemProvider(itemId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review suggestions')),
      body: ContentBounds(
        child: AsyncFade(
          value: suggestions,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: 'Failed to load suggestions: $e',
            onRetry: () => ref.invalidate(suggestionsForItemProvider(itemId)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No pending suggestions',
                message:
                    'Things you confirm are added to your library. Extract '
                    'Things from an item to see suggestions here.',
              );
            }
            return ListView(
              padding: EdgeInsets.all(tokens.spaceLg),
              children: [
                for (final s in list)
                  Padding(
                    padding: EdgeInsets.only(bottom: tokens.spaceMd),
                    child: _SuggestionCard(suggestion: s),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One pending suggestion, with a read mode (type + fields + Accept/Edit/Reject)
/// and a minimal inline edit mode (a TextField per field; "Save & Accept" rebuilds
/// the ThingDoc and runs the same accept path). Rich typed editing is P16.
class _SuggestionCard extends ConsumerStatefulWidget {
  const _SuggestionCard({required this.suggestion});

  final ThingSuggestion suggestion;

  @override
  ConsumerState<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends ConsumerState<_SuggestionCard> {
  bool _editing = false;
  final _controllers = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  ThingDoc get _doc => ThingDoc.fromJsonString(widget.suggestion.jsonld);

  void _startEditing() {
    _controllers.clear();
    for (final field in thingDisplayFields(_doc)) {
      _controllers[field.key] = TextEditingController(text: field.value);
    }
    setState(() => _editing = true);
  }

  /// Overlays the edited values onto the original JSON-LD, preserving `@*` and
  /// `grabbit:*` keys. List-valued fields are split back on commas.
  ThingDoc _editedDoc() {
    final original = _doc.json;
    final json = Map<String, dynamic>.from(original);
    _controllers.forEach((key, controller) {
      final text = controller.text.trim();
      if (original[key] is List) {
        json[key] = text.isEmpty
            ? <String>[]
            : text
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
      } else {
        json[key] = text;
      }
    });
    return ThingDoc(json);
  }

  Future<void> _accept({ThingDoc? edited}) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(suggestionReviewServiceProvider)
        .accept(widget.suggestion, edited: edited);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Added to your library')));
  }

  Future<void> _reject() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirm(
      context,
      title: 'Discard suggestion?',
      message:
          "This extracted ${widget.suggestion.type} won't be added to your "
          'library.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok) return;
    await ref
        .read(suggestionReviewServiceProvider)
        .reject(widget.suggestion.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Suggestion discarded')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final fields = thingDisplayFields(_doc);
    final confidence = widget.suggestion.confidence;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(
                    widget.suggestion.type,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (confidence != null)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${(confidence * 100).round()}%'),
                  ),
              ],
            ),
            SizedBox(height: tokens.spaceMd),
            if (_editing)
              for (final field in fields) ...[
                TextField(
                  controller: _controllers[field.key],
                  decoration: InputDecoration(
                    labelText: field.key,
                    isDense: true,
                  ),
                ),
                SizedBox(height: tokens.spaceSm),
              ]
            else if (fields.isEmpty)
              Text(
                'No fields were extracted.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final field in fields)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spaceSm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.key,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(field.value, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
            SizedBox(height: tokens.spaceSm),
            _actions(),
          ],
        ),
      ),
    );
  }

  Widget _actions() {
    if (_editing) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => setState(() => _editing = false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => _accept(edited: _editedDoc()),
            child: const Text('Save & Accept'),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(onPressed: _reject, child: const Text('Reject')),
        TextButton(onPressed: _startEditing, child: const Text('Edit')),
        FilledButton(onPressed: () => _accept(), child: const Text('Accept')),
      ],
    );
  }
}
