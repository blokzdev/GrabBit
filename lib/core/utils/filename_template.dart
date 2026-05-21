/// Curated, user-facing filename tokens. Users build a pattern from these
/// friendly `{tokens}`; we translate them to yt-dlp output-template fields for
/// the download `-o`, and to sample values for the Settings live preview.
///
/// The pattern names the real downloaded file (yt-dlp renders the fields at
/// download time); the extension is always appended, so a user can't produce a
/// file without one.
class FilenameToken {
  const FilenameToken({
    required this.key,
    required this.label,
    required this.ytDlp,
    required this.sample,
  });

  /// The `{key}` users type / insert.
  final String key;

  /// Human label for the Settings chip.
  final String label;

  /// yt-dlp output-template field this maps to (null = handled app-side).
  final String? ytDlp;

  /// Value used in the Settings preview.
  final String sample;
}

/// The palette shown as chips in Settings, in display order.
const filenameTokens = <FilenameToken>[
  FilenameToken(
    key: 'title',
    label: 'Title',
    ytDlp: '%(title)s',
    sample: 'Never Gonna Give You Up',
  ),
  FilenameToken(
    key: 'channel',
    label: 'Channel',
    ytDlp: '%(uploader)s',
    sample: 'Rick Astley',
  ),
  FilenameToken(
    key: 'username',
    label: 'Username',
    ytDlp: '%(uploader_id)s',
    sample: 'rickastleyofficial',
  ),
  FilenameToken(key: 'id', label: 'ID', ytDlp: '%(id)s', sample: 'dQw4w9WgXcQ'),
  FilenameToken(
    key: 'date',
    label: 'Date',
    ytDlp: '%(upload_date)s',
    sample: '20091025',
  ),
  FilenameToken(
    key: 'site',
    label: 'Site',
    ytDlp: '%(extractor)s',
    sample: 'youtube',
  ),
  FilenameToken(
    key: 'quality',
    label: 'Quality',
    ytDlp: '%(resolution)s',
    sample: '1080p',
  ),
  // App-side: substituted from the item's batch position before download.
  FilenameToken(key: 'num', label: 'Number', ytDlp: null, sample: '01'),
];

const _fallbackTemplate = '%(title)s.%(ext)s';
final _tokenPattern = RegExp(r'\{(\w+)\}');

/// Resolves a curated [pattern] into a yt-dlp output template (with a trailing
/// `.%(ext)s`). [index] is the 1-based batch position for `{num}` (single
/// downloads pass 1). Unknown `{tokens}` are dropped; an empty result falls back
/// to [_fallbackTemplate] so a download can never end up unnamed.
String resolveOutputTemplate(String pattern, {int index = 1}) {
  final byKey = {for (final t in filenameTokens) t.key: t};
  var out = pattern.replaceAllMapped(_tokenPattern, (m) {
    final token = byKey[m.group(1)];
    if (token == null) return '';
    if (token.key == 'num') return index.toString().padLeft(2, '0');
    return token.ytDlp ?? '';
  });
  // Strip path separators so the pattern can't escape the per-task folder.
  out = out.replaceAll(RegExp(r'[/\\]+'), '-').trim();
  if (out.isEmpty) return _fallbackTemplate;
  return '$out.%(ext)s';
}

/// Human-readable preview of [pattern] using each token's sample value, with a
/// representative extension — for the Settings screen.
String renderPreview(String pattern, {String ext = 'mp4'}) {
  final byKey = {for (final t in filenameTokens) t.key: t};
  final name = pattern
      .replaceAllMapped(_tokenPattern, (m) => byKey[m.group(1)]?.sample ?? '')
      .replaceAll(RegExp(r'[/\\]+'), '-')
      .trim();
  return '${name.isEmpty ? filenameTokens.first.sample : name}.$ext';
}
