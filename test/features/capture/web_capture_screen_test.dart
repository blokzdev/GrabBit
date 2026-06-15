import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/things/capture/web_page_fetcher.dart';
import 'package:grabbit/features/capture/presentation/web_capture_controller.dart';
import 'package:grabbit/features/capture/presentation/web_capture_screen.dart';

class _FakeController implements WebCaptureController {
  _FakeController(this.result);
  final WebCaptureResult result;
  @override
  Future<WebCaptureResult> capture(String url) async => result;
}

void main() {
  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => context.push('/grab/web'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/grab/web',
        builder: (context, state) => const WebCaptureScreen(),
      ),
      GoRoute(
        path: '/grab/manual',
        builder: (context, state) =>
            const Scaffold(body: Text('manual screen')),
      ),
      GoRoute(
        path: '/thing/:id',
        builder: (context, state) => const Scaffold(body: Text('thing screen')),
      ),
      GoRoute(
        path: '/capture/:id/suggestions',
        builder: (context, state) =>
            Scaffold(body: Text('review ${state.pathParameters['id']}')),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, WebCaptureResult result) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          webCaptureControllerProvider.overrideWith(
            (ref) async => _FakeController(result),
          ),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://x.test/a');
    await tester.tap(find.text('Grab'));
    await tester.pumpAndSettle();
  }

  testWidgets('committed → pops with a confirmation snackbar', (tester) async {
    await pump(tester, const WebCaptureCommitted('t1', 'Recipe'));
    expect(find.text('Added to your library'), findsOneWidget);
  });

  testWidgets('review → navigates to the capture review surface', (
    tester,
  ) async {
    await pump(tester, const WebCaptureReview('cap_1', 'Recipe'));
    expect(find.text('review cap_1'), findsOneWidget);
  });

  testWidgets('nothing found → offers manual entry', (tester) async {
    await pump(tester, const WebCaptureNothingFound());
    expect(find.text('Add manually'), findsOneWidget);
  });

  testWidgets('fetch error → shows the friendly message', (tester) async {
    await pump(
      tester,
      const WebCaptureError('Network problem.', WebFetchError.network),
    );
    expect(find.text('Network problem.'), findsOneWidget);
  });
}
