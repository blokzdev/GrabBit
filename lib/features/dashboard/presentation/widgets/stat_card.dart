import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// A tonal at-a-glance tile: leading icon, a large [value], a [label] and an
/// optional [subtitle]. Tapping (when [onTap] is set) drills into the matching
/// screen. Set [highlight] to tint the card with the brand accent for an
/// attention-worthy stat (e.g. an active download).
class StatCard extends StatelessWidget {
  const StatCard({
    required this.icon,
    required this.value,
    required this.label,
    this.subtitle,
    this.onTap,
    this.highlight = false,
    super.key,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final scheme = theme.colorScheme;
    final iconColor = highlight ? tokens.accent : scheme.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: tokens.spaceXs),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
