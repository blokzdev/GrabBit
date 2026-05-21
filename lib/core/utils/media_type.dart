/// Maps a file extension to a library media type (`video` | `audio` | `image`).
String mediaTypeForExt(String ext) {
  const image = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  const audio = {'m4a', 'mp3', 'opus', 'aac', 'ogg', 'wav', 'flac'};
  final e = ext.toLowerCase();
  if (image.contains(e)) return 'image';
  if (audio.contains(e)) return 'audio';
  return 'video';
}
