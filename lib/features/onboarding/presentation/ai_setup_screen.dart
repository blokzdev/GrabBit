import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grabbit/core/ai/embedder_engine_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/graph/graph_sync_provider.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// One-time, opt-in first-run screen offering to set up the on-device AI
/// features (semantic search). Shown only to genuinely new users, sequenced
/// after the disclaimer (see `startupRedirect`). "Set up" enables semantic
/// search and downloads the embedder with a progress bar; "Skip" leaves it off.
/// Either choice marks the screen seen so it never shows again. Everything works
/// without AI, so this is purely additive.
class AiSetupScreen extends ConsumerStatefulWidget {
  const AiSetupScreen({super.key});

  @override
  ConsumerState<AiSetupScreen> createState() => _AiSetupScreenState();
}

class _AiSetupScreenState extends ConsumerState<AiSetupScreen> {
  bool _busy = false;
  double? _progress;
  String? _error;

  Future<void> _skip() async {
    setState(() => _busy = true);
    await ref.read(settingsControllerProvider.notifier).markAiSetupSeen();
    // The router's refreshListenable re-evaluates and leaves /ai-setup.
  }

  Future<void> _setUp() async {
    final controller = ref.read(settingsControllerProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    await controller.setSemanticSearchEnabled(true);
    try {
      await ref
          .read(embedderEngineProvider)
          .downloadModel(
            onProgress: (p) {
              if (mounted) setState(() => _progress = p);
            },
          );
    } on InferenceException catch (e) {
      // The model couldn't be fetched (e.g. unsupported device or offline).
      // Revert the opt-in and surface the reason — the rest of the app, and the
      // graph's metadata features, work fine without embeddings.
      await controller.setSemanticSearchEnabled(false);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = e.code == InferenceErrorCode.unavailable
            ? 'On-device AI isn\'t available on this device. You can still use '
                  'everything else.'
            : 'Couldn\'t download the model. You can try again later from '
                  'Settings.';
      });
      return;
    }
    // Build the vector index in the background — the user shouldn't wait on the
    // onboarding screen for it, and it's resumable/cached on later launches.
    unawaited(ref.read(graphSyncServiceProvider).backfillEmbeddings());
    await controller.markAiSetupSeen();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = GrabBitTokens.of(context);
    final model = ref.read(embedderEngineProvider).model;
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
                  'Set up AI features',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spaceXl),
                Row(
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                    SizedBox(width: tokens.spaceSm),
                    Text(
                      'On-device & private',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceSm),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Paragraph(
                          'GrabBit can search your library by meaning — find '
                          'media by what it\'s about, not just its title — and '
                          'surface similar items. This runs entirely on your '
                          'device; nothing leaves it.',
                        ),
                        _Paragraph(
                          'Setting it up downloads a small model (about '
                          '${model.approxDownloadMb} MB), one time. You can do '
                          'this now, or later in Settings.',
                        ),
                        const _Paragraph(
                          'It\'s optional — everything else in GrabBit works '
                          'without it.',
                        ),
                        if (_error != null) ...[
                          SizedBox(height: tokens.spaceSm),
                          Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_busy && _progress != null) ...[
                  LinearProgressIndicator(value: _progress),
                  SizedBox(height: tokens.spaceXs),
                  Text(
                    'Downloading model… ${(_progress! * 100).round()}%',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: tokens.spaceLg),
                ],
                FilledButton(
                  onPressed: _busy ? null : _setUp,
                  child: const Text('Set up'),
                ),
                SizedBox(height: tokens.spaceSm),
                TextButton(
                  onPressed: _busy ? null : _skip,
                  child: const Text('Skip for now'),
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
