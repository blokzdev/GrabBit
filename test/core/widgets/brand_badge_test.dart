import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/brand_badge.dart';

void main() {
  testWidgets('lays out at the requested size with a GrabBit label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandBadge())),
      ),
    );

    expect(find.byType(BrandBadge), findsOneWidget);
    // The badge constrains its own box to `size` even though the mark overflows.
    expect(tester.getSize(find.byType(BrandBadge)), const Size(32, 32));
    expect(find.bySemanticsLabel('GrabBit'), findsOneWidget);
  });

  testWidgets('honours a custom size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BrandBadge(size: 48))),
      ),
    );
    expect(tester.getSize(find.byType(BrandBadge)), const Size(48, 48));
  });
}
