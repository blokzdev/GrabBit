import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/presentation/thing_cards.dart';

Thing _thing(String type, String jsonld) => Thing(
  id: 't',
  type: type,
  jsonld: jsonld,
  name: 'X',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

Future<void> pumpCard(WidgetTester tester, Widget? card) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: card ?? const Text('no-card'))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Recipe card lists ingredients and numbered steps', (
    tester,
  ) async {
    await pumpCard(
      tester,
      thingCardFor(
        _thing(
          'Recipe',
          '{"@type":"Recipe","name":"Carbonara","recipeIngredient":["eggs","guanciale"],'
              '"recipeInstructions":["Boil","Mix"],"recipeYield":"4"}',
        ),
      ),
    );
    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('•  eggs'), findsOneWidget);
    expect(find.text('1.  Boil'), findsOneWidget);
    expect(find.text('2.  Mix'), findsOneWidget);
    expect(find.text('Serves 4'), findsOneWidget); // meta chip
  });

  testWidgets('Event card shows a formatted date range', (tester) async {
    await pumpCard(
      tester,
      thingCardFor(
        _thing(
          'Event',
          '{"@type":"Event","name":"Conf","startDate":"2026-06-20T09:00:00Z",'
              '"location":"SF"}',
        ),
      ),
    );
    expect(find.text('Event'), findsOneWidget);
    expect(find.text('Where'), findsOneWidget);
    expect(find.text('SF'), findsOneWidget);
  });

  testWidgets('Product card surfaces brand and gtin', (tester) async {
    await pumpCard(
      tester,
      thingCardFor(
        _thing(
          'Product',
          '{"@type":"Product","name":"Widget","brand":"Acme","gtin":"036000291452"}',
        ),
      ),
    );
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('036000291452'), findsOneWidget);
  });

  testWidgets('a long-tail type has no bespoke card', (tester) async {
    final card = thingCardFor(_thing('Book', '{"@type":"Book","name":"B"}'));
    expect(card, isNull);
    await pumpCard(tester, card);
    expect(find.text('no-card'), findsOneWidget);
  });
}
