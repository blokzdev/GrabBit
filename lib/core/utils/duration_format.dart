/// Formats a duration in whole [seconds] as `M:SS`, or `H:MM:SS` when an hour
/// or longer. Returns an empty string for null or negative input.
String formatDuration(int? seconds) {
  if (seconds == null || seconds < 0) return '';
  final d = Duration(seconds: seconds);
  final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    final mins = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '${d.inHours}:$mins:$secs';
  }
  return '${d.inMinutes}:$secs';
}
