import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/theme/app_theme.dart';
import 'package:grabbit/core/theme/tokens.dart';

void main() {
  test('light and dark build with the brand accent and correct brightness', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.useMaterial3, isTrue);
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);

    for (final theme in [light, dark]) {
      final tokens = theme.extension<GrabBitTokens>();
      expect(tokens, isNotNull);
      expect(tokens!.accent, const Color(0xFFFF8A4C));
    }
  });

  test('a supplied dynamic scheme overrides the seeded fallback', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00FF00));
    expect(AppTheme.light(scheme).colorScheme.primary, scheme.primary);
  });

  testWidgets('GrabBitTokens is reachable via Theme.of(context)', (
    tester,
  ) async {
    late GrabBitTokens tokens;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            tokens = Theme.of(context).extension<GrabBitTokens>()!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(tokens.spaceLg, 16);
    expect(tokens.radiusPill, 999);
    expect(tokens.motionMedium, const Duration(milliseconds: 250));
  });
}
