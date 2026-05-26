import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/section_header.dart';

/// A titled, icon-led settings section: a [SectionHeader] above a rounded card
/// holding the section's rows. The shared building block for every settings
/// group (landing sections and the P10j sub-screens).
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title, icon: icon),
        Card(
          margin: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceLg,
          ),
          color: theme.colorScheme.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusLg),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
