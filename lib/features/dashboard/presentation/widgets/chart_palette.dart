import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/dashboard/domain/chart_mappers.dart'
    show kOtherColorIndex;

/// Donut-slice colours derived from the active [ColorScheme] + brand accent, so
/// they follow dynamic colour and light/dark/AMOLED automatically. Ordered and
/// deterministic; real slice indices cycle through it.
List<Color> chartPalette(ColorScheme scheme, GrabBitTokens tokens) => [
  scheme.primary,
  scheme.tertiary,
  scheme.secondary,
  tokens.accent,
  scheme.primaryContainer,
  scheme.tertiaryContainer,
  scheme.secondaryContainer,
];

/// Resolves a [DonutSlice.colorIndex] to a colour. [kOtherColorIndex] becomes a
/// muted neutral so the aggregated "Other" slice reads as secondary.
Color sliceColor(int colorIndex, ColorScheme scheme, GrabBitTokens tokens) {
  if (colorIndex == kOtherColorIndex) {
    return Color.alphaBlend(
      scheme.onSurfaceVariant.withValues(alpha: 0.35),
      scheme.surfaceContainerHighest,
    );
  }
  final palette = chartPalette(scheme, tokens);
  return palette[colorIndex % palette.length];
}
