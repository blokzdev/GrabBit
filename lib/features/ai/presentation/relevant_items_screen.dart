import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/library/presentation/media_grid.dart';
import 'package:grabbit/features/library/presentation/semantic_search_provider.dart';

/// Retrieval-only "Ask your library" fallback (P13d-3) for low/ineligible tiers
/// that can't run the generation model: instead of a written answer, surface the
/// **most relevant items** for a question via on-device semantic retrieval. Fully
/// ephemeral — nothing is persisted (no chats), and tapping an item opens it.
class RelevantItemsScreen extends ConsumerStatefulWidget {
  const RelevantItemsScreen({super.key});

  @override
  ConsumerState<RelevantItemsScreen> createState() =>
      _RelevantItemsScreenState();
}

class _RelevantItemsScreenState extends ConsumerState<RelevantItemsScreen> {
  final _input = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _search() {
    final q = _input.text.trim();
    if (q == _query) return;
    setState(() => _query = q);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final ready = ref.watch(semanticSearchReadyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ask your library')),
      body: SafeArea(
        child: Column(
          children: [
            _FramingBanner(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                tokens.spaceSm,
                tokens.spaceLg,
                tokens.spaceSm,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: const InputDecoration(
                        hintText: 'What are you looking for?',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spaceSm),
                  IconButton.filled(
                    onPressed: _search,
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Find',
                  ),
                ],
              ),
            ),
            Expanded(child: _body(ready)),
          ],
        ),
      ),
    );
  }

  Widget _body(AsyncValue<bool> ready) {
    // Retrieval needs the embedder + the user's Smart-search opt-in; offer the
    // on-ramp rather than a misleading "no results".
    if (ready.asData?.value == false) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'Search isn\'t ready',
        message:
            'Turn on Smart search (and finish setting up the on-device model) '
            'to find items in your library.',
        action: FilledButton.icon(
          onPressed: () => context.push('/settings/ai'),
          icon: const Icon(Icons.settings_outlined),
          label: const Text('Open AI settings'),
        ),
      );
    }
    if (ready.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_query.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Find items in your library',
        message:
            'Type what you\'re looking for and GrabBit surfaces the most '
            'relevant items — fully on-device.',
      );
    }

    final results = ref.watch(semanticResultsProvider(_query));
    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => EmptyState(
        icon: Icons.error_outline,
        title: 'Couldn\'t search',
        message: '$e',
      ),
      data: (items) => items.isEmpty
          ? const EmptyState(
              icon: Icons.search_off_outlined,
              title: 'No matching items',
              message: 'Try different words.',
            )
          : MediaGrid(items: items),
    );
  }
}

/// Explains, once, that this device shows relevant items instead of a written
/// answer.
class _FramingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        0,
      ),
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: scheme.onSurfaceVariant),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: Text(
              'This device shows the most relevant items rather than a written '
              'answer.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
