import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Brand design tokens (spacing, radii, elevation, motion, brand colors) exposed
/// as a [ThemeExtension] so widgets read them via
/// `Theme.of(context).extension<GrabBitTokens>()` instead of hardcoding values.
@immutable
class GrabBitTokens extends ThemeExtension<GrabBitTokens> {
  const GrabBitTokens({
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.spaceXxxl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusPill,
    required this.elevation0,
    required this.elevation1,
    required this.elevation2,
    required this.accent,
    required this.onAccent,
    required this.brand,
    required this.motionShort,
    required this.motionMedium,
    required this.motionLong,
  });

  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double spaceXxxl;

  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusPill;

  final double elevation0;
  final double elevation1;
  final double elevation2;

  /// Warm-amber CTA accent for the primary download/grab action and FAB. Not a
  /// standard [ColorScheme] role, so it lives here and survives dynamic color.
  final Color accent;
  final Color onAccent;

  /// The brand indigo seed, for the rare case a literal brand color is needed
  /// regardless of the active (possibly dynamic) scheme.
  final Color brand;

  final Duration motionShort;
  final Duration motionMedium;
  final Duration motionLong;

  static const GrabBitTokens standard = GrabBitTokens(
    spaceXs: 4,
    spaceSm: 8,
    spaceMd: 12,
    spaceLg: 16,
    spaceXl: 24,
    spaceXxl: 32,
    spaceXxxl: 40,
    radiusSm: 8,
    radiusMd: 12,
    radiusLg: 20,
    radiusXl: 28,
    radiusPill: 999,
    elevation0: 0,
    elevation1: 1,
    elevation2: 3,
    accent: Color(0xFFFF8A4C),
    onAccent: Color(0xFF422100),
    brand: Color(0xFF5A3FE0),
    motionShort: Duration(milliseconds: 150),
    motionMedium: Duration(milliseconds: 250),
    motionLong: Duration(milliseconds: 400),
  );

  @override
  GrabBitTokens copyWith({
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? spaceXxxl,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusPill,
    double? elevation0,
    double? elevation1,
    double? elevation2,
    Color? accent,
    Color? onAccent,
    Color? brand,
    Duration? motionShort,
    Duration? motionMedium,
    Duration? motionLong,
  }) {
    return GrabBitTokens(
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      spaceXxxl: spaceXxxl ?? this.spaceXxxl,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusPill: radiusPill ?? this.radiusPill,
      elevation0: elevation0 ?? this.elevation0,
      elevation1: elevation1 ?? this.elevation1,
      elevation2: elevation2 ?? this.elevation2,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      brand: brand ?? this.brand,
      motionShort: motionShort ?? this.motionShort,
      motionMedium: motionMedium ?? this.motionMedium,
      motionLong: motionLong ?? this.motionLong,
    );
  }

  @override
  GrabBitTokens lerp(ThemeExtension<GrabBitTokens>? other, double t) {
    if (other is! GrabBitTokens) return this;
    return GrabBitTokens(
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t)!,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t)!,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t)!,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t)!,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t)!,
      spaceXxl: lerpDouble(spaceXxl, other.spaceXxl, t)!,
      spaceXxxl: lerpDouble(spaceXxxl, other.spaceXxxl, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusPill: lerpDouble(radiusPill, other.radiusPill, t)!,
      elevation0: lerpDouble(elevation0, other.elevation0, t)!,
      elevation1: lerpDouble(elevation1, other.elevation1, t)!,
      elevation2: lerpDouble(elevation2, other.elevation2, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      motionShort: _lerpDuration(motionShort, other.motionShort, t),
      motionMedium: _lerpDuration(motionMedium, other.motionMedium, t),
      motionLong: _lerpDuration(motionLong, other.motionLong, t),
    );
  }

  static Duration _lerpDuration(Duration a, Duration b, double t) => Duration(
    microseconds: lerpDouble(
      a.inMicroseconds.toDouble(),
      b.inMicroseconds.toDouble(),
      t,
    )!.round(),
  );
}
