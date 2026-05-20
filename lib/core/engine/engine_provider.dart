import 'dart:io';

import 'package:grabbit/core/engine/android_ytdlp_engine.dart';
import 'package:grabbit/core/engine/download_engine.dart';
import 'package:grabbit/core/engine/windows_process_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'engine_provider.g.dart';

/// Selects the correct [DownloadEngine] for the host platform. UI and queue
/// code depend on this provider, never a concrete engine.
@Riverpod(keepAlive: true)
DownloadEngine downloadEngine(Ref ref) {
  if (Platform.isAndroid) return AndroidYtDlpEngine();
  if (Platform.isWindows) return const WindowsProcessEngine();
  throw UnsupportedError('No download engine for ${Platform.operatingSystem}');
}
