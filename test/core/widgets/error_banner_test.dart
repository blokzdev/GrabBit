import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/error_banner.dart';

void main() {
  testWidgets('renders the message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorBanner(message: 'Could not resolve link')),
      ),
    );
    expect(find.text('Could not resolve link'), findsOneWidget);
  });

  testWidgets('renders provided actions', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorBanner(
            message: 'Unsupported site',
            actions: [
              TextButton(
                onPressed: () => tapped = true,
                child: const Text('Update engine'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Update engine'), findsOneWidget);
    await tester.tap(find.text('Update engine'));
    expect(tapped, isTrue);
  });

  testWidgets('reveals raw details under a toggle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorBanner(
            message: 'This link isn\'t supported.',
            details: 'ERROR: [tiktok] raw yt-dlp stderr',
          ),
        ),
      ),
    );
    // Collapsed by default: the raw text is hidden behind a "Details" toggle.
    expect(find.textContaining('raw yt-dlp stderr'), findsNothing);
    expect(find.text('Details'), findsOneWidget);

    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('raw yt-dlp stderr'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('omits the Details toggle when details add nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorBanner(message: 'Same', details: 'Same'),
        ),
      ),
    );
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('notice tone uses info styling and still exposes details', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ErrorBanner(
            tone: BannerTone.notice,
            message: "This link isn't supported yet",
            details: 'ERROR: Unsupported URL',
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(find.text('Details'), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Unsupported URL'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });
}
