import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// A small, primary-colored section label for grouping form/list content
/// (settings sections, grouped lists). Pass [icon] for a leading glyph.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {this.icon, super.key});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final label = Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.primary,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceLg,
        tokens.spaceLg,
        tokens.spaceXs,
      ),
      child: icon == null
          ? label
          : Row(
              children: [
                Icon(icon, size: 18, color: theme.colorScheme.primary),
                SizedBox(width: tokens.spaceSm),
                Expanded(child: label),
              ],
            ),
    );
  }
}
