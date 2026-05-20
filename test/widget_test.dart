import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';

void main() {
  testWidgets('launches to the empty Library screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: GrabBitApp()));
    await tester.pumpAndSettle();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
