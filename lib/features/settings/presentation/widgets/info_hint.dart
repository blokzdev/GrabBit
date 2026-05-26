import 'package:flutter/material.dart';
import 'package:grabbit/core/theme/tokens.dart';

/// Plain-language help for a setting. Attached to a control (not free-floating)
/// so the explanation sits with the thing it explains. Rendered by the settings
/// tiles via [InfoHintButton]; opening it is a **tap** (not a long-press), so it
/// is discoverable on touch — unlike a bare [Tooltip].
@immutable
class InfoHint {
  const InfoHint({required this.title, required this.body});

  final String title;
  final String body;
}

/// A tappable `info` affordance that opens [hint] as a modal bottom sheet.
/// Keeps a [Tooltip] semantics label for accessibility and desktop hover.
class InfoHintButton extends StatelessWidget {
  const InfoHintButton(this.hint, {super.key});

  final InfoHint hint;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.info_outline),
      tooltip: hint.title,
      onPressed: () => showInfoHintSheet(context, hint),
    );
  }
}

/// Shows [hint] in a Material 3 modal bottom sheet (touch-first help surface).
Future<void> showInfoHintSheet(BuildContext context, InfoHint hint) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      final tokens = GrabBitTokens.of(context);
      return SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            0,
            tokens.spaceLg,
            tokens.spaceLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  SizedBox(width: tokens.spaceSm),
                  Expanded(
                    child: Text(hint.title, style: theme.textTheme.titleMedium),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
              Text(hint.body, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    },
  );
}
