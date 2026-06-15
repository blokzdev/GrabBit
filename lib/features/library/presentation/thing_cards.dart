import 'package:flutter/material.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:intl/intl.dart';

/// Returns a bespoke, first-class detail card for a priority-type [thing]
/// (P16c) — Recipe/Event/Place/Article/Product — or null for the long tail
/// (which falls back to the generic field render). MediaObjects never reach the
/// generic Thing detail (they route to the media item screen), so they're not
/// handled here.
Widget? thingCardFor(Thing thing) {
  final ThingDoc doc;
  try {
    doc = ThingDoc.fromJsonString(thing.jsonld);
  } on FormatException {
    return null;
  }
  return switch (thing.type) {
    'Recipe' => _RecipeCard(doc),
    'Event' => _EventCard(doc),
    'Place' => _PlaceCard(doc),
    'Article' => _ArticleCard(doc),
    'Product' => _ProductCard(doc),
    _ => null,
  };
}

// ── shared helpers ──────────────────────────────────────────────────────────

String? _str(ThingDoc doc, String key) {
  final v = doc.property(key);
  if (v == null) return null;
  if (v is Map) {
    final name = (v['name'] ?? v['@id'])?.toString().trim();
    return (name == null || name.isEmpty) ? null : name;
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

List<String> _list(ThingDoc doc, String key) {
  final v = doc.property(key);
  if (v is List) {
    return v
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }
  final s = _str(doc, key);
  return s == null ? const [] : [s];
}

/// Formats a schema.org date/datetime string for display, or returns it verbatim
/// when unparseable.
String _displayDate(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  return iso.contains('T')
      ? DateFormat.yMMMEd().add_jm().format(dt)
      : DateFormat.yMMMEd().format(dt);
}

class _CardScaffold extends StatelessWidget {
  const _CardScaffold({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        0,
      ),
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  SizedBox(width: tokens.spaceSm),
                  Text(title, style: theme.textTheme.titleSmall),
                ],
              ),
              SizedBox(height: tokens.spaceSm),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// A label + value, rendered only when [value] is non-null/non-blank.
Widget _maybe(String label, String? value) => (value == null || value.isEmpty)
    ? const SizedBox.shrink()
    : _Labeled(label, value);

class _Chips extends StatelessWidget {
  const _Chips(this.values);

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceSm),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: [for (final v in values) Chip(label: Text(v))],
      ),
    );
  }
}

// ── per-type cards ──────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  const _RecipeCard(this.doc);
  final ThingDoc doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final ingredients = _list(doc, 'recipeIngredient');
    final steps = _list(doc, 'recipeInstructions');
    final meta = [
      if (_str(doc, 'recipeYield') != null)
        'Serves ${_str(doc, 'recipeYield')}',
      if (_str(doc, 'prepTime') != null) 'Prep ${_str(doc, 'prepTime')}',
      if (_str(doc, 'cookTime') != null) 'Cook ${_str(doc, 'cookTime')}',
      if (_str(doc, 'recipeCuisine') != null) _str(doc, 'recipeCuisine')!,
    ];
    return _CardScaffold(
      icon: Icons.restaurant_outlined,
      title: 'Recipe',
      children: [
        _maybe('Description', _str(doc, 'description')),
        if (meta.isNotEmpty) _Chips(meta),
        if (ingredients.isNotEmpty) ...[
          Text('Ingredients', style: theme.textTheme.labelLarge),
          SizedBox(height: tokens.spaceXs),
          for (final i in ingredients)
            Text('•  $i', style: theme.textTheme.bodyMedium),
          SizedBox(height: tokens.spaceSm),
        ],
        if (steps.isNotEmpty) ...[
          Text('Instructions', style: theme.textTheme.labelLarge),
          SizedBox(height: tokens.spaceXs),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: tokens.spaceXs),
              child: Text(
                '${i + 1}.  ${steps[i]}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard(this.doc);
  final ThingDoc doc;

  @override
  Widget build(BuildContext context) {
    final start = _str(doc, 'startDate');
    final end = _str(doc, 'endDate');
    final when = start == null
        ? null
        : (end == null
              ? _displayDate(start)
              : '${_displayDate(start)} – ${_displayDate(end)}');
    return _CardScaffold(
      icon: Icons.event_outlined,
      title: 'Event',
      children: [
        _maybe('When', when),
        _maybe('Where', _str(doc, 'location')),
        _maybe('Organizer', _str(doc, 'organizer')),
        _maybe('Description', _str(doc, 'description')),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard(this.doc);
  final ThingDoc doc;

  @override
  Widget build(BuildContext context) {
    final amenities = _list(doc, 'amenityFeature');
    return _CardScaffold(
      icon: Icons.place_outlined,
      title: 'Place',
      children: [
        _maybe('Address', _str(doc, 'address')),
        _maybe('Phone', _str(doc, 'telephone')),
        _maybe('Area', _str(doc, 'containedInPlace')),
        _maybe('Description', _str(doc, 'description')),
        if (amenities.isNotEmpty) _Chips(amenities),
      ],
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard(this.doc);
  final ThingDoc doc;

  @override
  Widget build(BuildContext context) {
    final published = _str(doc, 'datePublished');
    return _CardScaffold(
      icon: Icons.article_outlined,
      title: 'Article',
      children: [
        _maybe('Headline', _str(doc, 'headline')),
        _maybe('By', _str(doc, 'author')),
        _maybe('Published', published == null ? null : _displayDate(published)),
        _maybe('Section', _str(doc, 'articleSection')),
        _maybe('Summary', _str(doc, 'description')),
        _maybe('Link', _str(doc, 'url')),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard(this.doc);
  final ThingDoc doc;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      icon: Icons.shopping_bag_outlined,
      title: 'Product',
      children: [
        _maybe('Brand', _str(doc, 'brand')),
        _maybe('Price', _str(doc, 'offers')),
        _maybe('GTIN', _str(doc, 'gtin')),
        _maybe('Category', _str(doc, 'category')),
        _maybe('Description', _str(doc, 'description')),
        _maybe('Link', _str(doc, 'url')),
      ],
    );
  }
}
