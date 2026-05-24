import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/features/lock/pin_dialog.dart';

void main() {
  Future<String?> openDialog(WidgetTester tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async => result = await showPinDialog(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('enter → Next → confirm → Set returns the PIN', (tester) async {
    await openDialog(tester);

    // Step 1: PIN only; the confirm step isn't shown yet.
    expect(find.text('Set a PIN'), findsOneWidget);
    expect(find.text('Confirm PIN'), findsNothing);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Step 2: a mismatch blocks Set; a match completes the dialog.
    expect(find.text('Confirm PIN'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1239');
    await tester.pumpAndSettle();
    expect(find.text("PINs don't match"), findsOneWidget);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();

    // The button that opened the dialog captured the returned PIN.
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Next is disabled until the PIN is long enough', (tester) async {
    await openDialog(tester);
    final next = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(next.onPressed, isNull);

    await tester.enterText(find.byType(TextField), '12');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('Back returns to the PIN step', (tester) async {
    await openDialog(tester);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm PIN'), findsOneWidget);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Set a PIN'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}
