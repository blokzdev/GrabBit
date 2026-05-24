/// Parsed bits of a yt-dlp progress line (P9d queue dashboard). youtubedl-android
/// hands us the raw line (e.g. `[download]  45.2% of ~100.00MiB at 1.50MiB/s ETA
/// 00:33`); the library extracts percent/ETA itself, so here we recover the two
/// fields it drops: download speed and total size. Best-effort — `Unknown`,
/// missing, or unrecognized values yield null.
typedef ProgressLine = ({double? speedBps, int? totalBytes});

final _speed = RegExp(r'at\s+([\d.]+)\s*([KMGT]?i?B)/s', caseSensitive: false);
final _total = RegExp(
  r'of\s+~?\s*([\d.]+)\s*([KMGT]?i?B)',
  caseSensitive: false,
);

ProgressLine parseProgressLine(String? line) {
  if (line == null || line.isEmpty) return (speedBps: null, totalBytes: null);
  final speed = _bytes(_speed.firstMatch(line));
  final total = _bytes(_total.firstMatch(line));
  return (speedBps: speed, totalBytes: total?.round());
}

/// `<number> <unit>` from a match → bytes (binary units), or null.
double? _bytes(RegExpMatch? m) {
  if (m == null) return null;
  final n = double.tryParse(m.group(1)!);
  return n == null ? null : n * _unit(m.group(2)!);
}

double _unit(String unit) => switch (unit.toUpperCase()[0]) {
  'K' => 1024,
  'M' => 1024 * 1024,
  'G' => 1024 * 1024 * 1024,
  'T' => 1024.0 * 1024 * 1024 * 1024,
  _ => 1, // bytes
};
