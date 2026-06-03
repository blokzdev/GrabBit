import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/empty_state.dart';
import 'package:grabbit/features/ai/data/chat_repository.dart';
import 'package:grabbit/features/ai/presentation/ask_chat.dart';
import 'package:grabbit/features/ai/presentation/ask_controller.dart';
import 'package:grabbit/features/library/presentation/ai_summary.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// The "Ask your library" GraphRAG chat (P13d-2a): ask a natural-language
/// question and get a grounded, streamed answer that cites library items. Each
/// turn re-retrieves fresh sources + a bounded slice of history. Reached from the
/// Dashboard; generation-gated (an on-ramp routes to AI settings when no model).
class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final text = _input.text.trim();
    if (text.isEmpty || ref.read(askControllerProvider).busy) return;

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final engine = ref.read(generationEngineProvider);
    final enabled =
        ref.read(settingsControllerProvider).value?.generationEnabled ?? false;
    // Only probe the model when enabled — never load a model the user hasn't
    // opted into. `ensureReady` does not download.
    final modelReady = enabled && await engine.ensureReady();
    final action = aiSummaryAction(
      eligible: ref.read(activeGenerationModelProvider) != null,
      enabled: enabled,
      modelReady: modelReady,
    );
    switch (action) {
      case AiSummaryAction.unavailable:
        return;
      case AiSummaryAction.offerSetup:
      case AiSummaryAction.offerDownload:
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Set up on-device text generation to ask'),
            ),
          );
        await router.push('/settings/ai');
      case AiSummaryAction.summarizeNow:
        _input.clear();
        await ref.read(askControllerProvider.notifier).send(text);
        _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final state = ref.watch(askControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ask your library')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _transcript(state)),
            if (state.error != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: tokens.spaceLg),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _InputBar(controller: _input, busy: state.busy, onSend: _onSend),
          ],
        ),
      ),
    );
  }

  Widget _transcript(AskState state) {
    final tokens = GrabBitTokens.of(context);
    final chatId = state.chatId;
    if (chatId == null) {
      return const EmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'Ask your library',
        message:
            'Ask a question and get an answer grounded in your downloads, with '
            'links to the items it used.',
      );
    }

    final messages =
        ref.watch(chatMessagesProvider(chatId)).asData?.value ?? const [];
    final streaming = state.streaming;
    final hasStreaming = state.busy && streaming != null;

    return ListView(
      controller: _scroll,
      padding: EdgeInsets.all(tokens.spaceLg),
      children: [
        for (final m in messages) _MessageBubble(message: m),
        if (hasStreaming) _StreamingBubble(text: streaming),
      ],
    );
  }
}

/// A persisted user/assistant message. Assistant bubbles render tappable `[n]`
/// citations + a "Sources" footer that deep-links the cited items.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == kRoleUser;
    if (isUser) return _Bubble(isUser: true, child: Text(message.content));

    final citations = decodeCitations(message.citationsJson);
    return _Bubble(
      isUser: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _answerBody(context, message.content, citations),
          if (citations.isNotEmpty) _SourcesFooter(citations: citations),
        ],
      ),
    );
  }
}

class _StreamingBubble extends StatelessWidget {
  const _StreamingBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return _Bubble(
      isUser: false,
      child: text.isEmpty
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(text)),
                SizedBox(width: tokens.spaceSm),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
    );
  }
}

/// Renders an answer as rich text with inline, tappable `[n]` citation badges.
Widget _answerBody(
  BuildContext context,
  String content,
  List<Citation> citations,
) {
  final scheme = Theme.of(context).colorScheme;
  final spans = parseCitationSpans(content, citations);
  return Text.rich(
    TextSpan(
      children: [
        for (final s in spans)
          if (s.isCitation)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: InkWell(
                onTap: () => context.push('/item/${s.citation!.itemId}'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Text(
                    s.text,
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            )
          else
            TextSpan(text: s.text),
      ],
    ),
  );
}

/// Cited items as tappable chips beneath an answer.
class _SourcesFooter extends StatelessWidget {
  const _SourcesFooter({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(top: tokens.spaceSm),
      child: Wrap(
        spacing: tokens.spaceSm,
        runSpacing: tokens.spaceXs,
        children: [
          for (final c in citations)
            ActionChip(
              avatar: const Icon(Icons.link, size: 16),
              label: Text(
                '[${c.index}] ${c.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => context.push('/item/${c.itemId}'),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.child});

  final bool isUser;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: tokens.spaceMd),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spaceMd,
          vertical: tokens.spaceSm,
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(tokens.radiusLg),
        ),
        child: child,
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        tokens.spaceMd,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !busy,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: 'Ask about your library…',
              ),
            ),
          ),
          SizedBox(width: tokens.spaceSm),
          IconButton.filled(
            onPressed: busy ? null : onSend,
            icon: const Icon(Icons.send),
            tooltip: 'Ask',
          ),
        ],
      ),
    );
  }
}
