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

/// Rotates 90° (clockwise → `transpose=1`, else counter-clockwise `=2`).
/// Works for video and image (output extension drives the encoder).
List<String> rotateArgs({
  required String input,
  required String output,
  required bool clockwise,
}) => ['-y', '-i', input, '-vf', 'transpose=${clockwise ? 1 : 2}', output];

/// Flips vertically (`vflip`) or mirrors horizontally (`hflip`).
List<String> flipArgs({
  required String input,
  required String output,
  required bool vertical,
}) => ['-y', '-i', input, '-vf', vertical ? 'vflip' : 'hflip', output];

/// Reverses video + audio (buffers the whole stream — best for short clips).
List<String> reverseArgs({required String input, required String output}) => [
  '-y',
  '-i',
  input,
  '-vf',
  'reverse',
  '-af',
  'areverse',
  output,
];

/// Strips video, keeping the audio track (output extension picks the codec).
List<String> extractAudioArgs({
  required String input,
  required String output,
}) => ['-y', '-i', input, '-vn', output];

/// Re-containers / converts by output extension (no filters).
List<String> convertArgs({required String input, required String output}) => [
  '-y',
  '-i',
  input,
  output,
];

/// Hard-bakes a subtitle file into the video (`-vf subtitles=`). A re-encode,
/// so it's slower and lossy — but the captions are permanent. The path is
/// single-quoted inside the filter so spaces/specials don't break it.
List<String> burnInSubtitlesArgs({
  required String input,
  required String output,
  required String subtitlePath,
}) => ['-y', '-i', input, '-vf', "subtitles='$subtitlePath'", output];
