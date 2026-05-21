import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/engine/android_ffmpeg_tools_engine.dart';
import 'package:grabbit/core/engine/media_tools_engine.dart';

/// Platform-keyed media-editing engine. Windows `ffmpeg.exe` arrives in P8.
final mediaToolsEngineProvider = Provider<MediaToolsEngine>((ref) {
  if (Platform.isAndroid) return AndroidFfmpegToolsEngine();
  throw UnsupportedError(
    'Media editing is Android-only for now (Windows arrives in P8).',
  );
});
