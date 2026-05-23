import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';

void main() {
  testWidgets('caps and centers its child on a wide window', (tester) async {
    const key = Key('bounded');
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(1400, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ContentBounds(
            maxWidth: 640,
            child: SizedBox(key: key, height: 100),
          ),
        ),
      ),
    );

    final width = tester.getSize(find.byKey(key)).width;
    expect(width, lessThanOrEqualTo(640));
  });

  testWidgets('does not stretch a narrow child beyond its window', (
    tester,
  ) async {
    const key = Key('bounded');
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(size: Size(360, 800)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ContentBounds(
            maxWidth: 640,
            child: SizedBox(key: key, height: 100),
          ),
        ),
      ),
    );

    final width = tester.getSize(find.byKey(key)).width;
    expect(width, lessThanOrEqualTo(360));
  });
}
