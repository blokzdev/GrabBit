import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Material 3 (Expressive) theming. Uses dynamic color when the platform supplies
/// it, falling back to the seeded brand scheme. Brand type is bundled (Outfit for
/// display/headline, Inter for body/label) — no runtime font fetch.
abstract final class AppTheme {
  /// Brand indigo-violet seed (replaces the default M3 purple).
  static const Color seed = Color(0xFF5A3FE0);

  static const String _display = 'Outfit';
  static const String _body = 'Inter';

  static ThemeData light([ColorScheme? dynamicScheme]) =>
      _build(dynamicScheme ?? ColorScheme.fromSeed(seedColor: seed));

  static ThemeData dark([ColorScheme? dynamicScheme, bool amoled = false]) {
    final scheme =
        dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    return _build(amoled ? _amoled(scheme) : scheme);
  }

  /// Pushes the dark scheme to a true-black background while keeping the
  /// container roles graded so cards / inputs / app bar stay distinguishable.
  static ColorScheme _amoled(ColorScheme dark) => dark.copyWith(
    surface: Colors.black,
    surfaceContainerLowest: Colors.black,
    surfaceContainerLow: const Color(0xFF0A0A0A),
    surfaceContainer: const Color(0xFF121212),
    surfaceContainerHigh: const Color(0xFF1A1A1A),
    surfaceContainerHighest: const Color(0xFF1F1F1F),
  );

  static ThemeData _build(ColorScheme scheme) {
    const tokens = GrabBitTokens.standard;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = _textTheme(base.textTheme);

    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radiusLg),
    );
    const pill = StadiumBorder();
    final buttonStyle = ButtonStyle(
      shape: const WidgetStatePropertyAll(pill),
      minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: tokens.spaceXl),
      ),
      textStyle: WidgetStatePropertyAll(text.labelLarge),
    );

    return base.copyWith(
      textTheme: text,
      extensions: const [GrabBitTokens.standard],
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: tokens.elevation0,
        scrolledUnderElevation: tokens.elevation2,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: tokens.elevation0,
        color: scheme.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: buttonStyle),
      textButtonTheme: const TextButtonThemeData(
        style: ButtonStyle(shape: WidgetStatePropertyAll(pill)),
      ),
      chipTheme: ChipThemeData(
        shape: pill,
        side: BorderSide.none,
        labelStyle: text.labelLarge,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXl),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusXl),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide.none,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    final body = base.apply(fontFamily: _body);
    TextStyle? display(TextStyle? s) =>
        s?.copyWith(fontFamily: _display, fontWeight: FontWeight.w600);
    return body.copyWith(
      displayLarge: display(body.displayLarge),
      displayMedium: display(body.displayMedium),
      displaySmall: display(body.displaySmall),
      headlineLarge: display(body.headlineLarge),
      headlineMedium: display(body.headlineMedium),
      headlineSmall: display(body.headlineSmall),
      titleLarge: display(body.titleLarge),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
