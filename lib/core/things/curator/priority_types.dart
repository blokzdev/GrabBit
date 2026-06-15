/// The curated **priority Thing types** the P15 curator can extract from
/// downloaded text (ADR-0002 narrow-then-fill). schema.org has ~1010 types; the
/// on-device curator targets a small, high-value set, each with a **curated field
/// subset** (<20 props, flat) so a small function-calling model fills it reliably.
///
/// This catalog is hand-authored but **vocabulary-validated**: a test asserts every
/// [CuratorField.name] is `isDefined` on its type against the bundled schema.org
/// asset, so the curation can't silently drift from the vocabulary (ADR-0001).
library;

/// How a curated field is expressed in the JSON-schema tool definition the model
/// fills. Object-valued schema.org properties (e.g. `author`, `location`) are
/// surfaced as a flat [string] (a human-readable value) — deep nested fill is
/// unreliable on tiny models, and the value is advisory + user-confirmed anyway
/// (suggest-don't-assert). Validation checks the property *name*, not its value.
enum CuratorFieldType { string, stringArray, number, dateTime }

/// One curated property on a [PriorityType]: its bare schema.org [name], the
/// JSON-schema [type] the model fills, and an optional NL [description] hint.
class CuratorField {
  const CuratorField(this.name, this.type, [this.description]);

  final String name;
  final CuratorFieldType type;
  final String? description;
}

/// A priority schema.org type plus everything the curator needs to (a) classify a
/// download into it from cheap signals and (b) build its fill tool-schema.
class PriorityType {
  const PriorityType({
    required this.type,
    required this.description,
    required this.fields,
    required this.keywords,
    this.hostHints = const [],
    this.mediaTypeHints = const [],
  });

  /// Bare schema.org `@type` (e.g. `Recipe`).
  final String type;

  /// NL description guiding the model when this tool is offered.
  final String description;

  /// The curated field subset (<20, flat). Every name must be schema.org-defined
  /// on [type] (enforced by `priority_types_test.dart`).
  final List<CuratorField> fields;

  /// Lowercase content keywords that signal this type (matched in title/text/tags).
  final List<String> keywords;

  /// Lowercase host fragments that strongly signal this type (matched in the
  /// download's source host, e.g. `allrecipes` → Recipe).
  final List<String> hostHints;

  /// Media-type values (`video`/`audio`/`image`) that weakly favor this type.
  final List<String> mediaTypeHints;
}

const _string = CuratorFieldType.string;
const _stringArray = CuratorFieldType.stringArray;
const _number = CuratorFieldType.number;
const _dateTime = CuratorFieldType.dateTime;

/// The five priority types the P15 curator extracts (the map's locked set).
const List<PriorityType> kPriorityTypes = [
  PriorityType(
    type: 'Recipe',
    description:
        'A cooking recipe: ingredients, step-by-step instructions, and timings.',
    fields: [
      CuratorField('name', _string, 'The dish name.'),
      CuratorField('description', _string),
      CuratorField(
        'recipeIngredient',
        _stringArray,
        'One entry per ingredient.',
      ),
      CuratorField(
        'recipeInstructions',
        _stringArray,
        'One entry per step, in order.',
      ),
      CuratorField('recipeYield', _string, 'How many servings or the yield.'),
      CuratorField('prepTime', _string, 'ISO-8601 duration, e.g. PT15M.'),
      CuratorField('cookTime', _string, 'ISO-8601 duration, e.g. PT30M.'),
      CuratorField('totalTime', _string, 'ISO-8601 duration.'),
      CuratorField('recipeCuisine', _string, 'e.g. Italian, Thai.'),
      CuratorField('recipeCategory', _string, 'e.g. dessert, main course.'),
      CuratorField('cookingMethod', _string),
      CuratorField('author', _string, 'Name of the cook or channel.'),
      CuratorField('keywords', _stringArray),
      CuratorField('datePublished', _dateTime),
    ],
    keywords: [
      'recipe',
      'ingredient',
      'ingredients',
      'preheat',
      'tablespoon',
      'teaspoon',
      'cup',
      'bake',
      'cook',
      'stir',
      'simmer',
      'whisk',
      'serving',
      'dough',
      'sauce',
    ],
    hostHints: [
      'allrecipes',
      'seriouseats',
      'foodnetwork',
      'bonappetit',
      'epicurious',
      'cooking.nytimes',
      'budgetbytes',
    ],
  ),
  PriorityType(
    type: 'Event',
    description:
        'A scheduled event: when and where it happens, who is involved.',
    fields: [
      CuratorField('name', _string),
      CuratorField('description', _string),
      CuratorField('startDate', _dateTime, 'ISO-8601 date/time.'),
      CuratorField('endDate', _dateTime, 'ISO-8601 date/time.'),
      CuratorField('location', _string, 'Venue or place name.'),
      CuratorField('organizer', _string),
      CuratorField('performer', _stringArray),
      CuratorField(
        'eventAttendanceMode',
        _string,
        'online, offline, or mixed.',
      ),
      CuratorField('eventStatus', _string),
      CuratorField('about', _string),
      CuratorField('url', _string),
      CuratorField('image', _string),
    ],
    keywords: [
      'event',
      'concert',
      'festival',
      'conference',
      'meetup',
      'tickets',
      'rsvp',
      'venue',
      'doors open',
      'lineup',
      'schedule',
      'admission',
    ],
    hostHints: ['eventbrite', 'meetup', 'ticketmaster', 'dice.fm', 'lu.ma'],
  ),
  PriorityType(
    type: 'Place',
    description:
        'A physical place or business: where it is and how to reach it.',
    fields: [
      CuratorField('name', _string),
      CuratorField('description', _string),
      CuratorField('address', _string, 'Full street address.'),
      CuratorField('telephone', _string),
      CuratorField('url', _string),
      CuratorField('image', _string),
      CuratorField('containedInPlace', _string, 'City or area it sits in.'),
      CuratorField('amenityFeature', _stringArray),
      CuratorField('maximumAttendeeCapacity', _number),
    ],
    keywords: [
      'restaurant',
      'cafe',
      'hotel',
      'bar',
      'museum',
      'park',
      'address',
      'located',
      'neighborhood',
      'directions',
      'open until',
      'reservation',
    ],
    hostHints: ['tripadvisor', 'yelp', 'google.com/maps', 'foursquare'],
  ),
  PriorityType(
    type: 'Article',
    description: 'A written article, blog post, or news story.',
    fields: [
      CuratorField('name', _string, 'The article title.'),
      CuratorField('headline', _string),
      CuratorField('description', _string, 'A short summary.'),
      CuratorField('author', _string),
      CuratorField('publisher', _string),
      CuratorField('datePublished', _dateTime),
      CuratorField('dateModified', _dateTime),
      CuratorField('articleSection', _string),
      CuratorField('keywords', _stringArray),
      CuratorField('about', _string),
      CuratorField('wordCount', _number),
      CuratorField('url', _string),
      CuratorField('image', _string),
    ],
    keywords: [
      'article',
      'blog',
      'post',
      'op-ed',
      'editorial',
      'published',
      'read more',
      'newsletter',
      'column',
      'report',
    ],
    hostHints: [
      'medium.com',
      'substack',
      'wordpress',
      'nytimes',
      'theguardian',
      'bbc.co',
    ],
  ),
  PriorityType(
    type: 'Product',
    description: 'A product for sale: what it is, its brand, and its price.',
    fields: [
      CuratorField('name', _string),
      CuratorField('description', _string),
      CuratorField('brand', _string),
      CuratorField('category', _string),
      CuratorField('color', _string),
      CuratorField('material', _string),
      CuratorField('sku', _string),
      CuratorField('gtin', _string),
      CuratorField('manufacturer', _string),
      CuratorField('offers', _string, 'Price and currency, e.g. "29.99 USD".'),
      CuratorField('url', _string),
      CuratorField('image', _string),
    ],
    keywords: [
      'product',
      'price',
      'buy',
      'shop',
      'sale',
      'discount',
      'brand',
      'in stock',
      'add to cart',
      'shipping',
      'review',
      'unboxing',
    ],
    hostHints: ['amazon', 'etsy', 'ebay', 'aliexpress', 'shopify', 'walmart'],
  ),
];
