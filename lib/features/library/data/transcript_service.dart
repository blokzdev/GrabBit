import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/text/transcript_dedup.dart';
import 'package:grabbit/core/utils/subtitle_files.dart';
import 'package:video_player/video_player.dart';

/// Builds plain-text transcripts (P10f) from the caption sidecars yt-dlp
/// already wrote next to a downloaded file. Reuses the same `.vtt`/`.srt`
/// parsers the player uses for subtitle tracks — no new dependency.
class TranscriptService {
  const TranscriptService();

  // `.ass`/`.ssa` aren't parseable by the video_player caption readers.
  static const _parseableExts = {'vtt', 'srt'};

  /// Extracts a de-duplicated transcript from the caption sidecar beside
  /// [mediaPath], preferring [preferLang] when several languages are present.
  /// Returns `null` when no parseable caption file exists or it yields no text.
  Future<String?> extractTranscript(
    String mediaPath, {
    String? preferLang,
  }) async {
    final sidecars = subtitleSidecars(
      mediaPath,
    ).where((f) => _parseableExts.contains(_ext(f.path))).toList();
    if (sidecars.isEmpty) return null;

    final chosen = _pick(sidecars, preferLang);
    final content = await chosen.readAsString();
    try {
      final ClosedCaptionFile parsed = _ext(chosen.path) == 'vtt'
          ? WebVTTCaptionFile(content)
          : SubRipCaptionFile(content);
      final text = captionsToTranscript([
        for (final c in parsed.captions) c.text,
      ]);
      return text.isEmpty ? null : text;
    } on Exception {
      return null;
    }
  }

  File _pick(List<File> files, String? preferLang) {
    if (preferLang != null && preferLang.isNotEmpty) {
      final lang = preferLang.toLowerCase();
      for (final f in files) {
        if (subtitleLabel(f.path).toLowerCase() == lang) return f;
      }
    }
    return files.first;
  }

  String _ext(String path) => path.split('.').last.toLowerCase();
}

final transcriptServiceProvider = Provider<TranscriptService>(
  (ref) => const TranscriptService(),
);
