import 'dart:io';

/// The classified files produced by a finished download in its per-task folder.
typedef DownloadOutputs = ({List<File> media, File? thumb, File? info});

const _subtitleExts = {'srt', 'vtt', 'ass', 'ssa', 'lrc', 'sub'};
const _thumbExts = {'jpg', 'jpeg', 'png', 'webp'};

/// Sorts a download folder's files into the media file(s), the thumbnail, and
/// the `.info.json` sidecar. Subtitle sidecars (`.srt`/`.vtt`/`.srv*`/…) and
/// other JSON sidecars are excluded so they're never mistaken for the media —
/// and multiple media files (yt-dlp `--split-chapters`) are all returned.
DownloadOutputs classifyDownloadOutputs(Iterable<File> files) {
  final media = <File>[];
  File? thumb;
  File? info;
  for (final f in files) {
    final lower = f.path.toLowerCase();
    final ext = lower.split('.').last;
    if (lower.endsWith('.info.json')) {
      info = f;
    } else if (ext == 'json') {
      // Other yt-dlp sidecars (e.g. live chat) — ignore.
    } else if (_subtitleExts.contains(ext) || ext.startsWith('srv')) {
      // Subtitle sidecars — not media.
    } else if (_thumbExts.contains(ext)) {
      thumb ??= f;
    } else {
      media.add(f);
    }
  }
  media.sort((a, b) => a.path.compareTo(b.path));
  return (media: media, thumb: thumb, info: info);
}
