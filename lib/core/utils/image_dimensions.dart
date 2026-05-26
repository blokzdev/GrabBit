import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Reads an image's pixel dimensions from its encoded [bytes] using a
/// header-only decode (no pixel data is materialised). Returns null when the
/// format is unrecognised or the header is malformed.
(int width, int height)? imageDimensions(Uint8List bytes) {
  try {
    final info = img.findDecoderForData(bytes)?.startDecode(bytes);
    if (info == null || info.width <= 0 || info.height <= 0) return null;
    return (info.width, info.height);
  } catch (_) {
    // Some decoders read past the buffer on truncated/garbage data.
    return null;
  }
}

/// Reads [file]'s pixel dimensions, returning null if it's missing, unreadable,
/// or not a decodable image.
Future<(int width, int height)?> readImageDimensions(File file) async {
  try {
    return imageDimensions(await file.readAsBytes());
  } catch (_) {
    return null;
  }
}
