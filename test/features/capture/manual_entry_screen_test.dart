import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/thing_repository.dart';
import 'package:grabbit/features/capture/presentation/manual_entry_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/grab/manual'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/grab/manual',
        builder: (context, state) => const ManualEntryScreen(),
      ),
      GoRoute(
        path: '/thing/:id',
        builder: (context, state) =>
            Scaffold(body: Text('thing ${state.pathParameters['id']}')),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          thingRepositoryProvider.overrideWithValue(ThingRepository(db)),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('saving a named Thing commits it and shows a confirmation', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(find.byType(TextFormField).first, 'Buy milk');
    await tester.tap(find.text('Add to library'));
    await tester.pumpAndSettle();

    expect(find.text('Added to your library'), findsOneWidget);
    final count = await ThingRepository(db).countThings();
    expect(count, 1);
  });

  testWidgets('blank name is rejected and nothing is committed', (
    tester,
  ) async {
    await pump(tester);

    await tester.tap(find.text('Add to library'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name'), findsOneWidget);
    expect(find.text('Added to your library'), findsNothing);
    expect(await ThingRepository(db).countThings(), 0);
  });
}
