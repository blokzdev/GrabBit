import 'package:flutter/widgets.dart';

/// Material 3 window-size-class breakpoints (logical pixels of the window's
/// width). Layout adapts to the *window* size, not the device type, so a folded
/// foldable reads as [WindowSizeClass.compact] and the same code unfolds to
/// [WindowSizeClass.medium]/[expanded] and scales up to desktop windows.
const double kBreakpointMedium = 600;
const double kBreakpointExpanded = 840;
const double kBreakpointLarge = 1200;
const double kBreakpointExtraLarge = 1600;

enum WindowSizeClass {
  compact,
  medium,
  expanded,
  large,
  extraLarge;

  static WindowSizeClass fromWidth(double width) {
    if (width < kBreakpointMedium) return WindowSizeClass.compact;
    if (width < kBreakpointExpanded) return WindowSizeClass.medium;
    if (width < kBreakpointLarge) return WindowSizeClass.expanded;
    if (width < kBreakpointExtraLarge) return WindowSizeClass.large;
    return WindowSizeClass.extraLarge;
  }

  /// The class for the current window, from `MediaQuery.sizeOf(context).width`.
  static WindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == WindowSizeClass.compact;

  /// Show a [NavigationRail] instead of a bottom navigation bar at Medium+.
  bool get useNavigationRail => index >= WindowSizeClass.medium.index;

  /// Use an extended (labels-always-visible) rail on Large+ / desktop widths.
  bool get useExtendedRail => index >= WindowSizeClass.large.index;
}
