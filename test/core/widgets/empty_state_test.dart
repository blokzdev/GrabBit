import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/empty_state.dart';

void main() {
  testWidgets('renders icon, title and message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox,
            title: 'Nothing here',
            message: 'Add something to begin',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('Nothing here'), findsOneWidget);
    expect(find.text('Add something to begin'), findsOneWidget);
  });

  testWidgets('action tap fires its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.inbox,
            title: 'Empty',
            action: FilledButton(
              onPressed: () => tapped = true,
              child: const Text('Add'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add'));
    expect(tapped, isTrue);
  });
}
