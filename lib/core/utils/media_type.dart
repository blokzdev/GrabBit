/// Maps a file extension to a library media type (`video` | `audio` | `image`).
String mediaTypeForExt(String ext) {
  const image = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  const audio = {'m4a', 'mp3', 'opus', 'aac', 'ogg', 'wav', 'flac'};
  final e = ext.toLowerCase();
  if (image.contains(e)) return 'image';
  if (audio.contains(e)) return 'audio';
  return 'video';
}

/// Like [mediaTypeForExt] but returns **null** for non-media extensions instead
/// of defaulting to `video`. Used by file import (P16b-3) to branch a picked file
/// into the media-library (MediaItem) path vs the generic-document (Thing) path —
/// only *known* media extensions become library media.
String? mediaTypeForExtOrNull(String ext) {
  const image = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  const audio = {'m4a', 'mp3', 'opus', 'aac', 'ogg', 'wav', 'flac'};
  const video = {
    'mp4',
    'mkv',
    'webm',
    'mov',
    'avi',
    'm4v',
    'flv',
    'wmv',
    'mpeg',
    'mpg',
    '3gp',
    'ts',
  };
  final e = ext.toLowerCase();
  if (image.contains(e)) return 'image';
  if (audio.contains(e)) return 'audio';
  if (video.contains(e)) return 'video';
  return null;
}
