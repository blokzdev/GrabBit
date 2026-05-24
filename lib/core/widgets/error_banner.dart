import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Visual intent for [ErrorBanner]: a real [error] (red) vs an informational
/// [notice] (e.g. a link that isn't supported yet — not actually a failure).
enum BannerTone { error, notice }

/// An inline status banner shown within a screen body (not a full-screen state).
/// Callers pass any contextual [actions] (e.g. an "Update engine" button) so
/// this stays free of feature-specific routing. Optional [details] (e.g. the raw
/// yt-dlp stderr) are revealed, and copyable, under a "Details" toggle.
class ErrorBanner extends StatefulWidget {
  const ErrorBanner({
    required this.message,
    this.actions,
    this.details,
    this.tone = BannerTone.error,
    super.key,
  });

  final String message;
  final List<Widget>? actions;
  final String? details;
  final BannerTone tone;

  @override
  State<ErrorBanner> createState() => _ErrorBannerState();
}

class _ErrorBannerState extends State<ErrorBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final isError = widget.tone == BannerTone.error;
    final background = isError
        ? scheme.errorContainer
        : scheme.tertiaryContainer;
    final foreground = isError
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    final details = widget.details?.trim();
    // Only offer details when they add information beyond the friendly message.
    final hasDetails =
        details != null && details.isNotEmpty && details != widget.message;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.info_outline,
                color: foreground,
              ),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: Text(
                  widget.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
          if (hasDetails)
            _DetailsSection(
              details: details,
              foreground: foreground,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
          if (widget.actions != null && widget.actions!.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: tokens.spaceSm, children: widget.actions!),
            ),
        ],
      ),
    );
  }
}

class _DetailsSection extends StatelessWidget {
  const _DetailsSection({
    required this.details,
    required this.foreground,
    required this.expanded,
    required this.onToggle,
  });

  final String details;
  final Color foreground;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(expanded ? 'Hide details' : 'Details'),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(tokens.spaceSm),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(tokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: foreground,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: details));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Error details copied')));
  }
}
