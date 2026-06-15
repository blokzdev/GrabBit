import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_jsonld_format.dart';
import 'package:grabbit/core/widgets/async_fade.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/core/widgets/error_view.dart';
import 'package:grabbit/core/widgets/section_header.dart';
import 'package:grabbit/features/library/data/thing_export_service.dart';
import 'package:grabbit/features/library/data/thing_exporters.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/thing_cards.dart';
import 'package:grabbit/features/library/presentation/things_browser_screen.dart';
import 'package:grabbit/features/settings/data/settings_model.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// P15e — the standalone generic render for a non-media Thing (e.g. a confirmed
/// `Recipe`). Per ADR-0001 this is a schema-driven key/value view (bespoke per-type
/// UI is P16): a type+name header, the Thing's properties, and a "Based on" section
/// linking to the source media leaf. Advanced mode adds a raw JSON-LD diagnostic.
class ThingDetailScreen extends ConsumerWidget {
  const ThingDetailScreen({required this.thingId, super.key});

  final String thingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = GrabBitTokens.of(context);
    final thing = ref.watch(thingByIdProvider(thingId));
    final advanced =
        ref.watch(settingsControllerProvider).value?.mode == UiMode.advanced;
    final loaded = thing.asData?.value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thing'),
        actions: [
          if (loaded != null && exportKindFor(loaded.type) != null)
            IconButton(
              tooltip: 'Share / export',
              icon: const Icon(Icons.ios_share),
              onPressed: () =>
                  ref.read(thingExportServiceProvider).export(loaded),
            ),
          if (advanced && loaded != null)
            IconButton(
              tooltip: 'View JSON-LD',
              icon: const Icon(Icons.code),
              onPressed: () => _viewJsonld(context, loaded),
            ),
        ],
      ),
      body: ContentBounds(
        child: AsyncFade(
          value: thing,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(
            message: 'Failed to load Thing: $e',
            onRetry: () => ref.invalidate(thingByIdProvider(thingId)),
          ),
          data: (row) {
            if (row == null) {
              return const EmptyState(
                icon: Icons.category_outlined,
                title: 'Thing not found',
                message: 'It may have been removed.',
              );
            }
            // A priority type gets its bespoke, first-class card; the long tail
            // falls back to the generic schema-driven field list (ADR-0001).
            final card = thingCardFor(row);
            return ListView(
              padding: EdgeInsets.only(bottom: tokens.spaceXl),
              children: [
                _Header(thing: row),
                card ?? _Fields(thing: row),
                _Relationships(thingId: thingId),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _viewJsonld(BuildContext context, Thing thing) async {
    final pretty = prettyThingJsonld(thing.jsonld);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thing (JSON-LD)'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.thing});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.all(tokens.spaceLg),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            child: Icon(iconForThingType(thing.type), size: 28),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thing.name ?? thing.type,
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  thing.type,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields({required this.thing});

  final Thing thing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final ThingDoc doc;
    try {
      doc = ThingDoc.fromJsonString(thing.jsonld);
    } on FormatException {
      return const SizedBox.shrink();
    }
    // `name` is already in the header.
    final fields = thingDisplayFields(
      doc,
    ).where((e) => e.key != 'name').toList();
    if (fields.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Details'),
        for (final field in fields)
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spaceLg,
              0,
              tokens.spaceLg,
              tokens.spaceSm,
            ),
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
      ],
    );
  }
}

/// The Thing's linked nodes (P16d): outgoing authored edges ("Based on"), incoming
/// authored edges ("Referenced by"), and derived vocabulary edges ("Mentions") —
/// each hydrated to a real name/type and tappable to traverse.
class _Relationships extends ConsumerWidget {
  const _Relationships({required this.thingId});

  final String thingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rel = ref.watch(thingRelationshipsProvider(thingId)).asData?.value;
    if (rel == null || rel.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._section(context, 'Based on', Icons.link_outlined, rel.outgoing),
        ..._section(
          context,
          'Referenced by',
          Icons.call_received_outlined,
          rel.incoming,
        ),
        ..._section(
          context,
          'Mentions',
          Icons.alternate_email_outlined,
          rel.mentions,
        ),
      ],
    );
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    IconData icon,
    List<ThingRelation> rels,
  ) {
    if (rels.isEmpty) return const [];
    return [
      SectionHeader(title, icon: icon),
      for (final r in rels)
        ListTile(
          leading: Icon(
            r.node.media != null
                ? Icons.movie_outlined
                : iconForThingType(r.node.type ?? ''),
          ),
          title: Text(
            r.node.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(_humanizePredicate(r.predicate)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(
            r.node.media != null ? '/item/${r.node.id}' : '/thing/${r.node.id}',
          ),
        ),
    ];
  }
}

/// `isBasedOn` → "Based on", `relatedTo` → "Related to", etc.
String _humanizePredicate(String predicate) {
  final spaced = predicate.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => ' ${m[0]!.toLowerCase()}',
  );
  if (spaced.isEmpty) return predicate;
  return spaced[0].toUpperCase() + spaced.substring(1);
}
