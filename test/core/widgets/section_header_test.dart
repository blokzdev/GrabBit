import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/section_header.dart';

void main() {
  testWidgets('renders its title', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SectionHeader('Downloads'))),
    );
    expect(find.text('Downloads'), findsOneWidget);
  });
}
