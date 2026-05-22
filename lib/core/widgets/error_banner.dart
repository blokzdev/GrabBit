import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// An inline error banner shown within a screen body (not a full-screen state).
/// Callers pass any contextual [actions] (e.g. an "Update engine" button) so
/// this stays free of feature-specific routing.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({required this.message, this.actions, super.key});

  final String message;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (actions != null && actions!.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: tokens.spaceSm, children: actions!),
            ),
        ],
      ),
    );
  }
}
