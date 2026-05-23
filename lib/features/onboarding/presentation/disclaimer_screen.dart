import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// One-time, user-responsibility disclaimer shown before first use (PRD §13).
/// Acceptance is persisted in settings; the router redirect gates the app on it.
class DisclaimerScreen extends ConsumerStatefulWidget {
  const DisclaimerScreen({super.key});

  @override
  ConsumerState<DisclaimerScreen> createState() => _DisclaimerScreenState();
}

class _DisclaimerScreenState extends ConsumerState<DisclaimerScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    await ref.read(settingsControllerProvider.notifier).acceptDisclaimer();
    // The router's refreshListenable re-evaluates and leaves /disclaimer.
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: ContentBounds(
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: tokens.spaceMd),
                SvgPicture.asset(
                  'assets/brand/logo.svg',
                  height: 72,
                  semanticsLabel: 'GrabBit',
                ),
                SizedBox(height: tokens.spaceLg),
                Text(
                  'Welcome to GrabBit',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spaceXl),
                Row(
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    SizedBox(width: tokens.spaceSm),
                    Text(
                      'Your responsibility',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceSm),
                const Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Paragraph(
                          'GrabBit is a general-purpose, on-device downloader and '
                          'private media manager. It hosts no content and ships '
                          'with no media.',
                        ),
                        _Paragraph(
                          'You are responsible for how you use it. Only download '
                          'media you have the right to, and comply with the terms '
                          'of service and copyright law of the sites you use.',
                        ),
                        _Paragraph(
                          'Downloads stay in a private in-app library by default; '
                          'nothing is saved to your device gallery unless you '
                          'explicitly export it.',
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                FilledButton(
                  onPressed: _accepting ? null : _accept,
                  child: _accepting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('I understand and agree'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceLg),
      child: Text(text, style: theme.textTheme.bodyLarge),
    );
  }
}
