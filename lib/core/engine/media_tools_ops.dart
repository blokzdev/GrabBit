/// Pure ffmpeg argument builders for the Media Studio (P6). Kept separate from
/// the engine so they're unit-testable without the native plugin.
library;

String _sec(Duration d) => (d.inMilliseconds / 1000).toStringAsFixed(3);

/// Lossless trim via stream-copy (fast; keyframe-aligned). Input-seeks to
/// [start] then keeps [duration].
List<String> trimArgs({
  required String input,
  required String output,
  required Duration start,
  required Duration duration,
}) => [
  '-y',
  '-ss',
  _sec(start),
  '-i',
  input,
  '-t',
  _sec(duration),
  '-c',
  'copy',
  output,
];

/// Extracts a single frame at [at] as an image.
List<String> frameArgs({
  required String input,
  required String output,
  required Duration at,
}) => [
  '-y',
  '-ss',
  _sec(at),
  '-i',
  input,
  '-frames:v',
  '1',
  '-q:v',
  '2',
  output,
];
