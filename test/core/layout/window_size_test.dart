import 'package:flutter_test/flutter_test.dart';
import 'package:grabbit/core/layout/window_size.dart';

void main() {
  group('WindowSizeClass.fromWidth', () {
    test('maps widths to the Material window-size bands', () {
      expect(WindowSizeClass.fromWidth(599), WindowSizeClass.compact);
      expect(WindowSizeClass.fromWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(839), WindowSizeClass.medium);
      expect(WindowSizeClass.fromWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1199), WindowSizeClass.expanded);
      expect(WindowSizeClass.fromWidth(1200), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1599), WindowSizeClass.large);
      expect(WindowSizeClass.fromWidth(1600), WindowSizeClass.extraLarge);
    });

    test('convenience getters gate the nav chrome', () {
      expect(WindowSizeClass.compact.isCompact, isTrue);
      expect(WindowSizeClass.compact.useNavigationRail, isFalse);
      expect(WindowSizeClass.medium.useNavigationRail, isTrue);
      expect(WindowSizeClass.expanded.useExtendedRail, isFalse);
      expect(WindowSizeClass.large.useExtendedRail, isTrue);
      expect(WindowSizeClass.extraLarge.useExtendedRail, isTrue);
    });
  });
}
