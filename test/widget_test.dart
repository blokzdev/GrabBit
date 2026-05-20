import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';

void main() {
  testWidgets('launches to the empty Library screen', (tester) async {
    await tester.pumpWidget(const GrabBitApp());

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
