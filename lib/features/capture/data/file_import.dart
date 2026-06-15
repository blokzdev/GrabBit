import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// The schema.org type backing an imported non-media file (P16b-3).
const String kImportedDocumentType = 'DigitalDocument';

/// Maps a file extension to a MIME `encodingFormat` for an imported document
/// (P16b-3) — advisory metadata only; unknown extensions yield null.
String? encodingFormatForExt(String ext) {
  const map = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'md': 'text/markdown',
    'csv': 'text/csv',
    'json': 'application/json',
    'xml': 'application/xml',
    'html': 'text/html',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip': 'application/zip',
    'epub': 'application/epub+zip',
    'rtf': 'application/rtf',
  };
  return map[ext.toLowerCase()];
}

/// Builds a user-authored [ThingDoc] for a non-media imported file (P16b-3) — a
/// `DigitalDocument` carrying the file's [name], local [filePath] (as both `url`
/// and `contentUrl`, ADR-0003), optional [encodingFormat]/[sizeBytes], and a
/// `user-authored` `grabbit:provenance` block (`file-import`). Mirrors
/// [buildManualThing]; blank fields are dropped.
ThingDoc buildDocumentThing({
  required String name,
  required String filePath,
  String? encodingFormat,
  int? sizeBytes,
  DateTime Function() now = DateTime.now,
}) {
  final json = <String, dynamic>{
    '@context': 'https://schema.org',
    '@type': kImportedDocumentType,
  };
  final cleanName = name.trim();
  if (cleanName.isNotEmpty) json['name'] = cleanName;
  json['url'] = filePath;
  json['contentUrl'] = filePath;
  final cleanFormat = encodingFormat?.trim();
  if (cleanFormat != null && cleanFormat.isNotEmpty) {
    json['encodingFormat'] = cleanFormat;
  }
  if (sizeBytes != null) json['contentSize'] = sizeBytes.toString();

  json[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
    provenance: Provenance.userAuthored,
    capturedAt: now(),
    sourceRef: 'file-import',
  );
  return ThingDoc(json);
}
