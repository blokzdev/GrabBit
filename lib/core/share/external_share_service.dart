import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outbound interactions with the OS: sharing downloaded files via the system
/// share sheet and opening source links in the browser (P9g). A no-op
/// elsewhere / in tests so callers stay platform-agnostic and testable.
abstract class ExternalShareService {
  Future<void> shareFiles(List<String> paths);
  Future<void> openUrl(String url);
}

class PlatformExternalShareService implements ExternalShareService {
  @override
  Future<void> shareFiles(List<String> paths) async {
    final files = [for (final p in paths) XFile(p)];
    if (files.isEmpty) return;
    await SharePlus.instance.share(ShareParams(files: files));
  }

  @override
  Future<void> openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class NoopExternalShareService implements ExternalShareService {
  @override
  Future<void> shareFiles(List<String> paths) async {}
  @override
  Future<void> openUrl(String url) async {}
}

final externalShareServiceProvider = Provider<ExternalShareService>(
  (ref) => Platform.isAndroid
      ? PlatformExternalShareService()
      : NoopExternalShareService(),
);
