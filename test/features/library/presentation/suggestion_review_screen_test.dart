import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/library/data/suggestion_review_service.dart';
import 'package:grabbit/features/library/presentation/suggestion_review_screen.dart';

void main() {
  late AppDatabase db;
  late StreamController<List<ThingSuggestion>> stream;
  late ThingSuggestion suggestion;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    stream = StreamController<List<ThingSuggestion>>();
    suggestion = ThingSuggestion(
      id: 'sug_1',
      sourceItemId: 'x',
      type: 'Recipe',
      jsonld:
          '{"@type":"Recipe","name":"Carbonara","recipeIngredient":["eggs"]}',
      confidence: 0.8,
      createdAt: DateTime.utc(2026),
    );
  });
  tearDown(() async {
    await stream.close();
    await db.close();
  });

  // The suggestions stream is a controllable stub (avoids a live Drift watch's
  // pending-timer at teardown, per the metadata-edit test); the review service is
  // real over an in-memory db so accept/reject perform genuine writes.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          suggestionsForItemProvider('x').overrideWith((ref) => stream.stream),
        ],
        child: const MaterialApp(home: SuggestionReviewScreen(itemId: 'x')),
      ),
    );
    stream.add([suggestion]);
    await tester.pump();
    await tester.pump();
  }

  // Resolving an action shows a SnackBar (a 4s timer) — advance well past it so
  // nothing is pending at teardown.
  Future<void> drain(WidgetTester tester) =>
      tester.pumpAndSettle(const Duration(seconds: 5));

  testWidgets('renders the suggestion type, fields, and actions', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Recipe'), findsOneWidget);
    expect(find.text('Carbonara'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Edit'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Reject'), findsOneWidget);
  });

  testWidgets('Accept asserts the Thing; the row clears to the empty state', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pump();
    stream.add(<ThingSuggestion>[]); // the suggestion stream drains on delete
    await tester.pump();

    expect(find.text('No pending suggestions'), findsOneWidget);
    expect(await ThingRepository(db).countThings(), 1);
    await drain(tester);
  });

  testWidgets('Reject confirms then discards', (tester) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pump();
    stream.add(<ThingSuggestion>[]);
    await tester.pump();

    expect(find.text('No pending suggestions'), findsOneWidget);
    expect(await ThingRepository(db).countThings(), 0);
    await drain(tester);
  });

  testWidgets('Edit reveals editable fields; Save & Accept asserts', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.widgetWithText(TextButton, 'Edit'));
    await tester.pump();

    expect(find.byType(TextField), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Save & Accept'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Save & Accept'));
    await tester.pump();
    stream.add(<ThingSuggestion>[]);
    await tester.pump();

    expect(find.text('No pending suggestions'), findsOneWidget);
    expect(await ThingRepository(db).countThings(), 1);
    await drain(tester);
  });
}
