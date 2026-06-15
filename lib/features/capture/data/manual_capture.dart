import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// The schema.org type backing a free-form "Note" in manual entry (P16b-1).
const String kManualNoteType = 'NoteDigitalDocument';

/// Builds a user-authored [ThingDoc] from manual-entry fields (P16b-1) — the
/// deterministic, no-model intake path. Assembles sparse JSON-LD ([type] plus the
/// non-blank [name]/[description]/[url]) and stamps a `user-authored`
/// `grabbit:provenance` block (ADR-0004). Blank fields are dropped so the doc
/// carries only what the user actually entered.
ThingDoc buildManualThing({
  required String type,
  required String name,
  String? description,
  String? url,
  DateTime Function() now = DateTime.now,
}) {
  final json = <String, dynamic>{
    '@context': 'https://schema.org',
    '@type': type.trim(),
  };
  final cleanName = name.trim();
  if (cleanName.isNotEmpty) json['name'] = cleanName;
  final cleanDescription = description?.trim();
  if (cleanDescription != null && cleanDescription.isNotEmpty) {
    json['description'] = cleanDescription;
  }
  final cleanUrl = url?.trim();
  if (cleanUrl != null && cleanUrl.isNotEmpty) json['url'] = cleanUrl;

  json[kGrabbitProvenanceKey] = grabbitProvenanceBlock(
    provenance: Provenance.userAuthored,
    capturedAt: now(),
    sourceRef: 'manual',
  );
  return ThingDoc(json);
}
