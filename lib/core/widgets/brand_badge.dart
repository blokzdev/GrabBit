import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The GrabBit brand mark for the app bar — the bunny + amber chevron with no
/// background plate. Theme-adaptive so it stays legible on either surface:
/// the white-foreground launcher mark on dark, and the indigo `logo.svg` on
/// light (a white mark would vanish on a light app bar). Both keep the amber
/// chevron.
class BrandBadge extends StatelessWidget {
  const BrandBadge({this.size = 32, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // The launcher foreground bakes a ~75% safe zone, so it reads smaller than
    // the tightly-cropped SVG at the same box; size each to match visually.
    final Widget mark = dark
        ? Image.asset(
            'assets/brand/generated/icon_foreground.png',
            width: size,
            height: size,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          )
        : SvgPicture.asset('assets/brand/logo.svg', height: size * 0.72);

    return Semantics(
      label: 'GrabBit',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: mark),
      ),
    );
  }
}
