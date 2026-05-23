import 'package:flutter/material.dart';
import 'package:grabbit/core/layout/window_size.dart';

/// A top-level navigation destination, rendered as a [NavigationBar] item on
/// Compact widths and a [NavigationRail] item on Medium+ widths. [icon] may be
/// a badge-wrapped widget.
class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.label,
    this.selectedIcon,
  });

  final Widget icon;
  final Widget? selectedIcon;
  final String label;
}

/// Wraps a branch [child] with size-class-driven navigation chrome: a bottom
/// [NavigationBar] on Compact, a [NavigationRail] on Medium/Expanded, and an
/// extended rail on Large/desktop. Inner screens keep their own [AppBar]s.
class AdaptiveNavigationScaffold extends StatelessWidget {
  const AdaptiveNavigationScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.child,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final size = WindowSizeClass.of(context);

    if (!size.useNavigationRail) {
      return Scaffold(
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.icon,
                selectedIcon: d.selectedIcon,
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = size.useExtendedRail;
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              selectedIndex: selectedIndex,
              onDestinationSelected: onSelect,
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}
