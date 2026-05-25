import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// A compact centered empty/error state sized for a dashboard chart card (the
/// full-screen [EmptyState]/[ErrorView] are too tall for a ~220px tile). Pass
/// [onRetry] for the error variant.
class ChartMessage extends StatelessWidget {
  const ChartMessage({
    required this.icon,
    required this.title,
    this.onRetry,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    final scheme = theme.colorScheme;
    final isError = onRetry != null;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 36,
              color: isError ? scheme.error : scheme.onSurfaceVariant,
            ),
            SizedBox(height: tokens.spaceSm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...[
              SizedBox(height: tokens.spaceSm),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
