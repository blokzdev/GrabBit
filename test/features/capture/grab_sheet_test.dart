import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/features/capture/presentation/grab_sheet.dart';

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showGrabSheet(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/add',
        builder: (context, state) => const Scaffold(body: Text('add screen')),
      ),
      GoRoute(
        path: '/grab/manual',
        builder: (context, state) =>
            const Scaffold(body: Text('manual screen')),
      ),
    ],
  );

  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: buildRouter())),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the intake options', (tester) async {
    await openSheet(tester);

    expect(find.text('Grab anything'), findsOneWidget);
    expect(find.text('Paste a link to download'), findsOneWidget);
    expect(find.text('Grab a web page'), findsOneWidget);
    expect(find.text('Add a file'), findsOneWidget);
    expect(find.text('Write a note or add manually'), findsOneWidget);
  });

  testWidgets('tapping "Paste a link" routes to /add', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Paste a link to download'));
    await tester.pumpAndSettle();

    expect(find.text('add screen'), findsOneWidget);
  });

  testWidgets('tapping "add manually" routes to /grab/manual', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Write a note or add manually'));
    await tester.pumpAndSettle();

    expect(find.text('manual screen'), findsOneWidget);
  });
}
