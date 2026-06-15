import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grabbit/core/theme/tokens.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/widgets/content_bounds.dart';
import 'package:grabbit/features/capture/data/barcode_capture.dart';
import 'package:grabbit/features/capture/presentation/camera_permission.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

/// P16b-4 — scan a product/book barcode with the camera and add a skeleton
/// `Product` (GTIN) or `Book` (ISBN) Thing. On-device only (no product lookup);
/// deterministic + user-initiated, so it asserts directly on confirm.
class BarcodeScanScreen extends ConsumerStatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  ConsumerState<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends ConsumerState<BarcodeScanScreen> {
  PermissionStatus? _status;
  MobileScannerController? _controller;
  BarcodeMatch? _match; // a classified detection awaiting confirmation
  bool _unrecognized = false; // a detection that isn't a product/book barcode
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermission());
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final status = await ref.read(cameraPermissionProvider).request();
    if (!mounted) return;
    setState(() {
      _status = status;
      if (status.isGranted) _controller ??= MobileScannerController();
    });
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;
    _handled = true;
    unawaited(_controller?.stop());
    setState(() {
      final match = classifyBarcode(raw);
      if (match == null) {
        _unrecognized = true;
      } else {
        _match = match;
      }
    });
  }

  void _scanAgain() {
    setState(() {
      _match = null;
      _unrecognized = false;
      _handled = false;
    });
    unawaited(_controller?.start());
  }

  Future<void> _add() async {
    final match = _match;
    if (match == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final id = await ref
        .read(captureCommitServiceProvider)
        .commitThing(buildBarcodeThing(match));
    if (!mounted) return;
    router.pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Added to your library'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () => router.push('/thing/$id'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan a barcode')),
      body: ContentBounds(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final status = _status;
    if (status == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!status.isGranted) {
      return _PermissionView(
        permanentlyDenied: status.isPermanentlyDenied,
        onRetry: _requestPermission,
        onOpenSettings: () => ref.read(cameraPermissionProvider).openSettings(),
      );
    }
    if (_match != null || _unrecognized) {
      return _ResultView(match: _match, onAdd: _add, onScanAgain: _scanAgain);
    }
    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        Expanded(
          child: MobileScanner(controller: controller, onDetect: _onDetect),
        ),
        Padding(
          padding: EdgeInsets.all(GrabBitTokens.of(context).spaceLg),
          child: Text(
            'Point the camera at a product or book barcode.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 48),
            SizedBox(height: tokens.spaceMd),
            Text(
              permanentlyDenied
                  ? 'Camera access is turned off. Enable it in Settings to scan '
                        'barcodes.'
                  : 'GrabBit needs camera access to scan barcodes.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            SizedBox(height: tokens.spaceLg),
            permanentlyDenied
                ? FilledButton.icon(
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Open settings'),
                  )
                : FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Allow camera'),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.match,
    required this.onAdd,
    required this.onScanAgain,
  });

  final BarcodeMatch? match;
  final VoidCallback onAdd;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final tokens = GrabBitTokens.of(context);
    final m = match;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(m == null ? Icons.help_outline : Icons.qr_code_2, size: 48),
            SizedBox(height: tokens.spaceMd),
            if (m == null)
              Text(
                "That doesn't look like a product or book barcode.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              )
            else ...[
              Text(
                'Found a ${m.type}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                '${m.idProp.toUpperCase()} ${m.idValue}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            SizedBox(height: tokens.spaceLg),
            if (m != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add to library'),
              ),
            SizedBox(height: tokens.spaceSm),
            TextButton(onPressed: onScanAgain, child: const Text('Scan again')),
          ],
        ),
      ),
    );
  }
}
