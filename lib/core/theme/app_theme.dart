import 'package:flutter/material.dart';

/// Material 3 theming. Uses dynamic color when the platform supplies it,
/// falling back to a seeded brand scheme.
abstract final class AppTheme {
  static const Color seed = Color(0xFF6750A4);

  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark([ColorScheme? dynamicScheme]) => _build(
    dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
  );

  static ThemeData _build(ColorScheme scheme) =>
      ThemeData(useMaterial3: true, colorScheme: scheme);
}
