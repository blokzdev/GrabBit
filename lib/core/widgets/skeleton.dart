import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart'
    show mediaGridDelegate;

/// A single placeholder block. Wrap a group of these in [Shimmer] for the sweep.
class Skeleton extends StatelessWidget {
  const Skeleton({
    this.width,
    this.height,
    this.radius,
    this.shape = BoxShape.rectangle,
    super.key,
  });

  final double? width;
  final double? height;
  final double? radius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(radius ?? tokens.radiusMd)
            : null,
      ),
    );
  }
}

/// Drives a lightweight horizontal highlight sweep across its [child]'s opaque
/// pixels (the [Skeleton] blocks). No package — one repeating controller.
class Shimmer extends StatefulWidget {
  const Shimmer({required this.child, super.key});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      scheme.surface.withValues(alpha: 0.6),
      base,
    );
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => LinearGradient(
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(_controller.value),
        ).createShader(bounds),
        child: child,
      ),
    );
  }
}

/// Slides a gradient from left (-width) to right (+width) as [t] goes 0→1.
class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.t);
  final double t;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues((t * 2 - 1) * bounds.width, 0, 0);
}

/// A shimmering grid placeholder matching the media grid's tile shape.
class MediaGridSkeleton extends StatelessWidget {
  const MediaGridSkeleton({this.count = 12, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Shimmer(
      child: GridView.builder(
        padding: EdgeInsets.all(tokens.spaceMd),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: mediaGridDelegate,
        itemCount: count,
        itemBuilder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Skeleton(radius: tokens.radiusMd)),
            SizedBox(height: tokens.spaceSm),
            Skeleton(height: 12, width: 120, radius: tokens.radiusSm),
          ],
        ),
      ),
    );
  }
}

/// A shimmering list of tile placeholders (queue, generic lists).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({this.count = 8, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, _) => const ListTileSkeleton(),
      ),
    );
  }
}

/// A single list-row placeholder: title bar, progress bar, status bar.
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spaceLg,
        vertical: tokens.spaceMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton(height: 14, width: 200, radius: tokens.radiusSm),
          SizedBox(height: tokens.spaceSm),
          Skeleton(height: 8, radius: tokens.radiusSm),
          SizedBox(height: tokens.spaceSm),
          Skeleton(height: 10, width: 80, radius: tokens.radiusSm),
        ],
      ),
    );
  }
}
