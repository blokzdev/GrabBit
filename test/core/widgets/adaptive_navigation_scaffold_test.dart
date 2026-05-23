import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/adaptive_navigation_scaffold.dart';

const _destinations = [
  AdaptiveDestination(icon: Icon(Icons.home), label: 'Home'),
  AdaptiveDestination(icon: Icon(Icons.search), label: 'Search'),
  AdaptiveDestination(icon: Icon(Icons.settings), label: 'Settings'),
];

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int selectedIndex = 0,
  ValueChanged<int>? onSelect,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800)),
        child: AdaptiveNavigationScaffold(
          destinations: _destinations,
          selectedIndex: selectedIndex,
          onSelect: onSelect ?? (_) {},
          child: const Center(child: Text('body')),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Compact width shows a bottom NavigationBar', (tester) async {
    await _pump(tester, width: 400);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('Medium width shows a collapsed NavigationRail', (tester) async {
    await _pump(tester, width: 700);
    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
  });

  testWidgets('Large width shows an extended NavigationRail', (tester) async {
    await _pump(tester, width: 1300);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
  });

  testWidgets('selecting a destination reports its index', (tester) async {
    int? picked;
    await _pump(tester, width: 400, onSelect: (i) => picked = i);
    await tester.tap(find.text('Settings'));
    expect(picked, 2);
  });
}
