# Vendored vocabularies

## `schemaorg-current-https.jsonld`
- **What:** the full official **schema.org** vocabulary (the *current* term set — excludes
  retired/"attic" terms; the `-https` variant uses `https://schema.org/…` IRIs).
- **Version:** **v30.0** (released 2026-03-19), pinned for reproducibility (ADR-0001 "vendor and
  version the asset").
- **Source:** `https://github.com/schemaorg/schemaorg` → `data/releases/30.0/schemaorg-current-https.jsonld`
  (mirror: `https://schema.org/version/30.0/schemaorg-current-https.jsonld`).
- **License:** **CC BY-SA 3.0** — vendored **unmodified**; see `../../THIRD-PARTY-NOTICES.md`.
- **Used by:** `lib/core/things/` (P14a) — parsed into `SchemaOrgVocabulary` for on-device,
  boundary validation of schema.org Things (known `@type`; defined properties). Loaded lazily at
  runtime via `schemaOrgVocabularyProvider`.

To update: replace the file from the pinned release URL above and bump the version recorded here.
