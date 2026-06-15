import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/features/capture/presentation/file_import_controller.dart';
import 'package:grabbit/features/capture/presentation/file_import_screen.dart';

class _FakeController implements FileImportController {
  _FakeController(this.result);
  final FileImportResult? result;
  @override
  Future<FileImportResult?> pickAndImport() async => result;
  @override
  Future<FileImportResult> importFile({
    required String sourcePath,
    required String fileName,
  }) async => result!;
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
              onPressed: () => context.push('/grab/file'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/grab/file',
        builder: (context, state) => const FileImportScreen(),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (context, state) => const Scaffold(body: Text('item screen')),
      ),
      GoRoute(
        path: '/thing/:id',
        builder: (context, state) => const Scaffold(body: Text('thing screen')),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, FileImportResult? result) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fileImportControllerProvider.overrideWithValue(
            _FakeController(result),
          ),
        ],
        child: MaterialApp.router(routerConfig: buildRouter()),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a file'));
    await tester.pumpAndSettle();
  }

  testWidgets('media import → confirmation snackbar', (tester) async {
    await pump(tester, const FileImportedMedia('m1', 'image'));
    expect(find.text('Added to your library'), findsOneWidget);
  });

  testWidgets('document import → confirmation snackbar', (tester) async {
    await pump(tester, const FileImportedThing('t1'));
    expect(find.text('Added to your library'), findsOneWidget);
  });

  testWidgets('cancelled pick → no change, no snackbar', (tester) async {
    await pump(tester, null);
    expect(find.text('Added to your library'), findsNothing);
    expect(find.text('Choose a file'), findsOneWidget);
  });

  testWidgets('error → shows the message', (tester) async {
    await pump(tester, const FileImportError('Disk full'));
    expect(find.text('Disk full'), findsOneWidget);
  });
}
