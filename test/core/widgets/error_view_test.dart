import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/error_view.dart';

void main() {
  testWidgets('shows the message and fires retry', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ErrorView(
            message: 'Something broke',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('Something broke'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });

  testWidgets('omits the retry button when onRetry is null', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ErrorView(message: 'Read-only error')),
      ),
    );

    expect(find.text('Read-only error'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
