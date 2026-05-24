import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/widgets/async_fade.dart';

Widget _host(AsyncValue<int> value) => MaterialApp(
  home: AsyncFade<int>(
    value: value,
    loading: () => const Text('loading'),
    error: (e, _) => Text('error: $e'),
    data: (n) => Text('data: $n'),
  ),
);

void main() {
  testWidgets('renders each phase and wraps them in an AnimatedSwitcher', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncValue.loading()));
    expect(find.byType(AnimatedSwitcher), findsOneWidget);
    expect(find.text('loading'), findsOneWidget);

    await tester.pumpWidget(_host(const AsyncValue.data(7)));
    await tester.pumpAndSettle();
    expect(find.text('data: 7'), findsOneWidget);
    expect(find.text('loading'), findsNothing);

    await tester.pumpWidget(
      _host(const AsyncValue.error('boom', StackTrace.empty)),
    );
    await tester.pumpAndSettle();
    expect(find.text('error: boom'), findsOneWidget);
  });

  testWidgets('a data refresh keeps the same phase (no extra fade)', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const AsyncValue.data(1)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_host(const AsyncValue.data(2)));
    // Same load phase => switcher is already settled, no transition pending.
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('data: 2'), findsOneWidget);
  });
}
