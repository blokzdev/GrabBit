/// Formats a byte count as `B`/`KB`/`MB`/`GB` (one decimal at MB and above).
/// Returns an empty string for null or negative input.
String formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) return '';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var size = bytes / 1024;
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  // KB whole, MB+ one decimal.
  final text = unit == 0 ? size.round().toString() : size.toStringAsFixed(1);
  return '$text ${units[unit]}';
}
