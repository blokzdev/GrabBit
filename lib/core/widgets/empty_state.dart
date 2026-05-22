import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// A friendly, centered empty state: icon + title + optional message and a
/// single primary action. Used wherever a list/grid has no content yet.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: theme.colorScheme.primary),
            SizedBox(height: tokens.spaceLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (message != null) ...[
              SizedBox(height: tokens.spaceSm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[SizedBox(height: tokens.spaceLg), action!],
          ],
        ),
      ),
    );
  }
}
