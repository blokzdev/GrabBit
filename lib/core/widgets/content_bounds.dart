import 'package:flutter/widgets.dart';

/// Caps and centers content on wide windows so single-column screens (and
/// galleries) stop stretching edge-to-edge on tablets, unfolded foldables and
/// desktops. Below [maxWidth] it is a transparent pass-through.
class ContentBounds extends StatelessWidget {
  const ContentBounds({super.key, required this.child, this.maxWidth = 640});

  /// Reading-width default for single-column forms, lists and detail text.
  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
