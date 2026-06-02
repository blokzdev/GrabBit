import 'dart:io';

import 'package:grabbit/core/utils/media_type.dart';

/// The classified files produced by a finished download in its per-task folder.
typedef DownloadOutputs = ({List<File> media, File? thumb, File? info});

const _subtitleExts = {'srt', 'vtt', 'ass', 'ssa', 'lrc', 'sub'};

/// Sorts a download folder's files into the media file(s), the thumbnail, and
/// the `.info.json` sidecar. Subtitle sidecars (`.srt`/`.vtt`/`.srv*`/…) and
/// other JSON sidecars are excluded so they're never mistaken for the media —
/// and multiple media files (yt-dlp `--split-chapters`) are all returned.
///
/// Image files are **tentative thumbnails**: alongside a video/audio download an
/// image is the thumbnail sidecar, but an **image-only** download (a photo or a
/// carousel of photos) has no video/audio — there the images *are* the media
/// (P13b-3), so they become image library items rather than being discarded.
DownloadOutputs classifyDownloadOutputs(Iterable<File> files) {
  final media = <File>[]; // video / audio
  final images = <File>[]; // image files — thumbnail(s) or the media itself
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
    } else if (mediaTypeForExt(ext) == 'image') {
      images.add(f);
    } else {
      media.add(f);
    }
  }
  media.sort((a, b) => a.path.compareTo(b.path));
  // Video/audio present → images are thumbnail sidecars (keep the first).
  if (media.isNotEmpty) {
    images.sort((a, b) => a.path.compareTo(b.path));
    return (
      media: media,
      thumb: images.isEmpty ? null : images.first,
      info: info,
    );
  }
  // Image download → the image is the media. A carousel expands to one task
  // (folder) per photo, so multiple images here means the photo PLUS yt-dlp's
  // `--write-thumbnail` sidecar — keep the largest as the photo and the next as
  // its thumbnail (rather than minting a duplicate item).
  if (images.length <= 1) {
    return (media: images, thumb: null, info: info);
  }
  images.sort((a, b) => _sizeOf(b).compareTo(_sizeOf(a)));
  return (media: [images.first], thumb: images[1], info: info);
}

/// File size in bytes, or 0 when it can't be read (e.g. a missing path in a
/// unit test) — used only to pick the largest image as the media.
int _sizeOf(File f) {
  try {
    return f.lengthSync();
  } on FileSystemException {
    return 0;
  }
}
