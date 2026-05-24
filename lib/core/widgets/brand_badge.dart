import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// The GrabBit brand mark as a rounded-square badge (echoing the adaptive
/// launcher icon): the brand-indigo square with the white-bunny + amber-chevron
/// foreground drawn slightly oversized so the ears/face overflow the square.
/// Reads clearly at small app-bar sizes where the flat logo was too faint.
class BrandBadge extends StatelessWidget {
  const BrandBadge({this.size = 32, super.key});

  final double size;

  /// Brand indigo — the same fill as the adaptive launcher icon background.
  static const Color _brand = Color(0xFF5A3FE0);

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Semantics(
      label: 'GrabBit',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _brand,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
              ),
            ),
            // The launcher foreground bakes a 75% safe zone, so scale it up past
            // the square (un-clipped) to make the mark fill it and overflow.
            OverflowBox(
              maxWidth: size * 1.45,
              maxHeight: size * 1.45,
              child: Image.asset(
                'assets/brand/generated/icon_foreground.png',
                width: size * 1.45,
                height: size * 1.45,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
