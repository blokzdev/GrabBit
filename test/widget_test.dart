import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/app.dart';
import 'package:grabbit/features/library/presentation/library_controller.dart';

void main() {
  testWidgets('launches to the empty Library screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          libraryItemsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const GrabBitApp(),
      ),
    );
    await tester.pump();

    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Your library is empty'), findsOneWidget);
  });
}
