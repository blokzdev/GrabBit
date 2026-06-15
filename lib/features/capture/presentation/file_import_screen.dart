import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/core/widgets/error_banner.dart';
import 'package:grabbit/features/capture/presentation/file_import_controller.dart';

/// P16b-3 — file upload: pick a local file and import it. A media file becomes a
/// library item (auto-projected to a MediaObject Thing); any other file becomes a
/// `DigitalDocument` Thing. Deterministic + user-initiated, so it asserts directly.
class FileImportScreen extends ConsumerStatefulWidget {
  const FileImportScreen({super.key});

  @override
  ConsumerState<FileImportScreen> createState() => _FileImportScreenState();
}

class _FileImportScreenState extends ConsumerState<FileImportScreen> {
  bool _busy = false;
  FileImportError? _error;

  Future<void> _pick() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await ref.read(fileImportControllerProvider).pickAndImport();
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result) {
      case null:
        // Cancelled — nothing picked.
        break;
      case FileImportedMedia(:final itemId):
        router.pop();
        _confirm(messenger, router, '/item/$itemId');
      case FileImportedThing(:final thingId):
        router.pop();
        _confirm(messenger, router, '/thing/$thingId');
      case FileImportError():
        setState(() => _error = result);
    }
  }

  void _confirm(
    ScaffoldMessengerState messenger,
    GoRouter router,
    String route,
  ) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to your library'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.push(route),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Grab a file')),
      body: ContentBounds(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            Text(
              'Import a file from your device into your private library. Photos, '
              'video, and audio join your media; anything else is saved as a '
              'document Thing.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: tokens.spaceLg),
            if (_error != null) ...[
              ErrorBanner(message: _error!.message),
              SizedBox(height: tokens.spaceMd),
            ],
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(_busy ? 'Importing…' : 'Choose a file'),
            ),
          ],
        ),
      ),
    );
  }
}
