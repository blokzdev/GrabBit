import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';

/// The vendored schema.org vocabulary asset (pinned v30.0; see `assets/vocab/`).
const schemaOrgVocabularyAsset = 'assets/vocab/schemaorg-current-https.jsonld';

/// Loads + parses the bundled schema.org vocabulary **lazily** — only when a Thing
/// operation first needs boundary validation, not at app launch — and caches it for
/// the provider's lifetime. The pure [SchemaOrgVocabulary.parse] is unit-tested;
/// this is the runtime wiring (ADR-0001).
final schemaOrgVocabularyProvider = FutureProvider<SchemaOrgVocabulary>(
  (ref) async => SchemaOrgVocabulary.parse(
    await rootBundle.loadString(schemaOrgVocabularyAsset),
  ),
);
