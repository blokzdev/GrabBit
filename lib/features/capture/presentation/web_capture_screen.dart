import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_banner.dart';
import 'package:grabbit/features/capture/presentation/web_capture_controller.dart';
import 'package:grabbit/features/downloader/data/share_intake_service.dart';

/// P16b-2 — web-article capture: paste a URL, fetch the page, and capture a Thing
/// (the unified pipeline decides: structured markup asserts directly; a markup-
/// less page on a capable device routes to review; otherwise offer manual entry).
class WebCaptureScreen extends ConsumerStatefulWidget {
  const WebCaptureScreen({super.key});

  @override
  ConsumerState<WebCaptureScreen> createState() => _WebCaptureScreenState();
}

class _WebCaptureScreenState extends ConsumerState<WebCaptureScreen> {
  final _url = TextEditingController();
  bool _busy = false;
  WebCaptureError? _error;
  bool _nothingFound = false;

  @override
  void initState() {
    super.initState();
    // A link shared into the app lands here pre-filled when the user chose to
    // grab it as a Thing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeSharedUrl());
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  void _consumeSharedUrl() {
    if (!mounted) return;
    final url = ref.read(pendingSharedUrlProvider.notifier).take();
    if (url == null || url.isEmpty) return;
    _url
      ..text = url
      ..selection = TextSelection.collapsed(offset: url.length);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    _url
      ..text = text.trim()
      ..selection = TextSelection.collapsed(offset: text.trim().length);
  }

  Future<void> _grab() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _nothingFound = false;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final controller = await ref.read(webCaptureControllerProvider.future);
    final result = await controller.capture(url);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case WebCaptureCommitted(:final thingId):
        router.pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text('Added to your library'),
              action: SnackBarAction(
                label: 'View',
                onPressed: () => router.push('/thing/$thingId'),
              ),
            ),
          );
      case WebCaptureReview(:final captureId):
        unawaited(router.push('/capture/$captureId/suggestions'));
      case WebCaptureNothingFound():
        setState(() => _nothingFound = true);
      case WebCaptureError():
        setState(() => _error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Grab a web page')),
      body: ContentBounds(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Page address',
                hintText: 'https://…',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: 'Paste',
                  onPressed: _busy ? null : _paste,
                ),
              ),
              onSubmitted: (_) {
                if (!_busy) unawaited(_grab());
              },
            ),
            SizedBox(height: tokens.spaceMd),
            if (_error != null) ...[
              ErrorBanner(message: _error!.message),
              SizedBox(height: tokens.spaceMd),
            ],
            if (_nothingFound) ...[
              ErrorBanner(
                tone: BannerTone.notice,
                message:
                    "We couldn't find structured info on this page. You can add "
                    'it to your library manually.',
                actions: [
                  TextButton(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      router.pop();
                      router.push('/grab/manual');
                    },
                    child: const Text('Add manually'),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceMd),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _grab,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.travel_explore),
              label: Text(_busy ? 'Fetching…' : 'Grab'),
            ),
          ],
        ),
      ),
    );
  }
}
