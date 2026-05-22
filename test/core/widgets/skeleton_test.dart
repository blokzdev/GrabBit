import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/skeleton.dart';

void main() {
  // The shimmer animation repeats forever, so drive frames with pump(Duration)
  // rather than pumpAndSettle (which would hang).

  testWidgets('MediaGridSkeleton shimmers placeholder blocks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MediaGridSkeleton(count: 6))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(Skeleton), findsAtLeastNWidgets(2));
  });

  testWidgets('ListSkeleton renders one row per count', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ListSkeleton(count: 4))),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(Shimmer), findsOneWidget);
    expect(find.byType(ListTileSkeleton), findsNWidgets(4));
  });
}
