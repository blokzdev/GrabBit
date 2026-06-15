import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/things_browser_screen.dart';

Thing _thing(String id, String type, String name) => Thing(
  id: id,
  type: type,
  jsonld: '{"@type":"$type","name":"$name"}',
  name: name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<ThingTypeCount> counts,
    required List<Thing> all,
    List<Thing> recipes = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thingTypeCountsProvider.overrideWith((ref) => Stream.value(counts)),
          allThingsProvider.overrideWith((ref) => Stream.value(all)),
          thingsByTypeProvider(
            'Recipe',
          ).overrideWith((ref) => Stream.value(recipes)),
        ],
        child: const MaterialApp(home: ThingsBrowserScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('renders facet chips with counts and the Things list', (
    tester,
  ) async {
    await pump(
      tester,
      counts: const [
        (type: 'VideoObject', count: 2),
        (type: 'Recipe', count: 1),
      ],
      all: [
        _thing('v1', 'VideoObject', 'Vid A'),
        _thing('v2', 'VideoObject', 'Vid B'),
        _thing('r1', 'Recipe', 'Carbonara'),
      ],
    );

    expect(find.text('All (3)'), findsOneWidget);
    expect(find.text('VideoObject (2)'), findsOneWidget);
    expect(find.text('Recipe (1)'), findsOneWidget);
    expect(find.text('Vid A'), findsOneWidget);
    expect(find.text('Carbonara'), findsOneWidget);
  });

  testWidgets('selecting a type chip filters the list', (tester) async {
    await pump(
      tester,
      counts: const [
        (type: 'VideoObject', count: 2),
        (type: 'Recipe', count: 1),
      ],
      all: [
        _thing('v1', 'VideoObject', 'Vid A'),
        _thing('r1', 'Recipe', 'Carbonara'),
      ],
      recipes: [_thing('r1', 'Recipe', 'Carbonara')],
    );

    await tester.tap(find.text('Recipe (1)'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Vid A'), findsNothing);
    expect(find.text('Carbonara'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no Things', (tester) async {
    await pump(tester, counts: const [], all: const []);

    expect(find.text('No Things yet'), findsOneWidget);
  });

  testWidgets('typing a query searches across types and hides the facets', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thingTypeCountsProvider.overrideWith(
            (ref) => Stream.value(const [
              (type: 'VideoObject', count: 1),
              (type: 'Recipe', count: 1),
            ]),
          ),
          allThingsProvider.overrideWith(
            (ref) => Stream.value([
              _thing('v1', 'VideoObject', 'Vid A'),
              _thing('r1', 'Recipe', 'Carbonara'),
            ]),
          ),
          thingsSearchProvider('carb').overrideWith(
            (ref) => Stream.value([_thing('r1', 'Recipe', 'Carbonara')]),
          ),
        ],
        child: const MaterialApp(home: ThingsBrowserScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'carb');
    await tester.pump();
    await tester.pump();

    expect(find.text('Carbonara'), findsOneWidget);
    expect(find.text('Vid A'), findsNothing);
    expect(find.text('All (2)'), findsNothing); // facets hidden while searching
  });

  testWidgets('a priority-type row shows its type-aware summary', (
    tester,
  ) async {
    final recipe = Thing(
      id: 'r1',
      type: 'Recipe',
      jsonld:
          '{"@type":"Recipe","name":"Carbonara","recipeIngredient":["eggs","guanciale"]}',
      name: 'Carbonara',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    await pump(
      tester,
      counts: const [(type: 'Recipe', count: 1)],
      all: [recipe],
    );

    expect(find.text('2 ingredients'), findsOneWidget);
  });
}
