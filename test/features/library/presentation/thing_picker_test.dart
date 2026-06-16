import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/features/library/data/things_browse_providers.dart';
import 'package:grabbit/features/library/presentation/thing_picker.dart';

Thing _thing(String id, String type, String name) => Thing(
  id: id,
  type: type,
  jsonld: '{"@type":"$type","name":"$name"}',
  name: name,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  Future<Thing?> open(
    WidgetTester tester, {
    required List<Thing> all,
    required String excludeId,
  }) async {
    Thing? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [allThingsProvider.overrideWith((ref) => Stream.value(all))],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    picked = await pickThing(context, excludeId: excludeId),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return picked;
  }

  testWidgets('lists Things excluding self and selecting returns it', (
    tester,
  ) async {
    await open(
      tester,
      excludeId: 'self',
      all: [_thing('self', 'Recipe', 'Me'), _thing('b', 'Place', 'Trattoria')],
    );
    expect(find.text('Me'), findsNothing); // excluded
    expect(find.text('Trattoria'), findsOneWidget);

    await tester.tap(find.text('Trattoria'));
    await tester.pumpAndSettle();
    // Sheet closed after selection.
    expect(find.text('Trattoria'), findsNothing);
  });

  testWidgets('search filters the list', (tester) async {
    await open(
      tester,
      excludeId: 'x',
      all: [
        _thing('a', 'Recipe', 'Carbonara'),
        _thing('b', 'Place', 'Trattoria'),
      ],
    );
    await tester.enterText(find.byType(TextField), 'carb');
    await tester.pumpAndSettle();
    expect(find.text('Carbonara'), findsOneWidget);
    expect(find.text('Trattoria'), findsNothing);
  });
}
