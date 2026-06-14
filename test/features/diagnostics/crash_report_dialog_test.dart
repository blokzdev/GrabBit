import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/diagnostics/crash_log.dart';
import 'package:grabbit/features/diagnostics/presentation/crash_report_dialog.dart';

void main() {
  testWidgets('renders the report with Copy + Dismiss; Dismiss closes', (
    tester,
  ) async {
    final report = CrashReport(
      time: DateTime(2026),
      text: 'GrabBit crash report\nBad state: kaboom',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCrashReportDialog(context, report),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('GrabBit closed unexpectedly'), findsOneWidget);
    expect(find.textContaining('kaboom'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Copy'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Dismiss'));
    await tester.pumpAndSettle();
    expect(find.text('GrabBit closed unexpectedly'), findsNothing);
  });
}
