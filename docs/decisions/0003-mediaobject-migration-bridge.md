# ADR-0003 — MediaObject as the migration bridge

- **Status:** Accepted (P14 Things Engine — architectural foundation)
- **Date:** 2026-05-28
- **Deciders:** Founder/Architect
- **Context band:** v1 / **P14** (the Things Engine; see `docs/things-engine.md`). The already-built
  P0–P13 are unchanged.

## Context

GrabBit ships v1 with a mature media library: the canonical Drift tables `media_items` +
`media_metadata` hold every downloaded video/audio/image plus its captured metadata and
caption-derived transcript (`docs/SPEC.md` §3, `docs/ARCHITECTURE.md` §4). The P14 Things Engine
(ADR-0001) introduces a generic `things` store of schema.org Things. The obvious risk in any
"reframe media as one artifact type among many" move is a **disruptive migration** — re-processing or
re-downloading the existing library to fit a new model.

The key observation that de-risks it: schema.org already models media. Under
`CreativeWork → MediaObject` sit **`AudioObject`**, **`ImageObject`**, and **`VideoObject`** — and
their properties (`contentUrl`, `duration`, `width`, `height`, `uploadDate`, `transcript`,
`thumbnailUrl`, `contentSize`, `encodingFormat`, …) **map almost 1:1 onto GrabBit's existing
columns.** GrabBit's `type` enum (`video|audio|image`) maps directly onto the three subtypes. So the
existing library can *become* typed Things by **projection** — no re-download, no file movement, no
re-extraction.

This makes MediaObject the natural **migration bridge**: the first concrete Thing types GrabBit
supports are exactly the ones it already has full data for, which both proves the Things model end to
end and turns the entire existing library into first-class graph citizens for free.

## Decision

**The three schema.org MediaObject subtypes — `AudioObject`, `ImageObject`, `VideoObject` — are the
bridge by which existing downloads become typed Things, via a field-by-field projection of the
existing `media_items` / `media_metadata` rows into JSON-LD. No re-download, no file move, no
re-extraction.**

- GrabBit's `media_items.type` maps to `@type`: `video → VideoObject`, `audio → AudioObject`,
  `image → ImageObject` (all `rdfs:subClassOf MediaObject ⊂ CreativeWork`).
- **Existing media tables stay canonical for the file-backed lifecycle.** `file_path`,
  `storage_state`, and the on-disk files keep their current owner; the MediaObject Thing **references**
  them. The Thing's JSON-LD is the canonical *Thing-level* payload (ADR-0001), produced by projecting
  the rows below. The projection is **rebuildable and idempotent** — the same discipline as the Cozo
  index and the FTS backfill — so a Thing view can always be regenerated from the media tables.

### MediaObject is the file-leaf

In the Things graph (rooted at schema.org `Thing`, ADR-0001), Things fall into two operational classes.
**File-backed Things** are `MediaObject` and its subtypes (`Audio`/`Image`/`VideoObject`,
`DataDownload`, …): they carry the **bytes** — `contentUrl`, `contentSize`, `encodingFormat` — and are
the one class whose canonical substrate is the media tables. **Pure-metadata Things** — `Recipe`,
`Event`, `Place`, `Person`, `Product`, `Article` — own no bytes; they are *works/entities* that
**reference** file-leaves via edges (ADR-0004). So `MediaObject` is the **universal file-leaf**: the
single place the Thing graph touches the filesystem, the migration bridge, and the **fallback** type
for any file intake that yields nothing richer (a download with no further extraction stays "just" a
MediaObject, and can be enriched later — provenance per ADR-0004).

**Documents fit with no gap.** A document is a `DigitalDocument` (a `CreativeWork` — a *sibling* of
`MediaObject`, not a child), whose **bytes are still a `MediaObject`/`DataDownload`** attached via
`encoding`. "File-backed" always bottoms out at a MediaObject; the document is the *work* that
references it. So adding documents (or any non-media artifact) needs no new file substrate — just a
content Thing pointing at a file-leaf.

**Content↔file is many-to-many.** One file-leaf can back **many** content Things — a single downloaded
video can yield a `Recipe`, an `Event`, and a transcript-derived `Article`, each linked to that one
`VideoObject` (with `Clip`/`startOffset` for segments) — and one work can span **many** file-leaves.
Bytes are stored once; the artifacts referencing them are unbounded (the "one grab, many artifacts"
driver). Edge mechanics live in ADR-0004.

### Field-by-field mapping

Canonical media columns → schema.org MediaObject (CreativeWork) properties:

| GrabBit column (`media_items` / `media_metadata`) | schema.org property | Notes |
|---|---|---|
| `media_items.id` | `@id` | GrabBit-owned stable identifier (the `things.id` for this Thing). |
| `media_items.type` (`video\|audio\|image`) | `@type` | → `VideoObject` / `AudioObject` / `ImageObject`. |
| `media_items.title` | `name` | CreativeWork title. |
| `media_metadata.description` | `description` | — |
| `media_items.file_path` | `contentUrl` | Local file reference; stays owned by `media_items` (private/on-device). |
| `media_metadata.original_url` / `media_items.source_url` | `url` / `mainEntityOfPage` | The source page the media came from. |
| `media_items.duration_sec` | `duration` | Serialized as ISO-8601 duration (e.g. `PT3M12S`). |
| `media_items.size_bytes` | `contentSize` | Bytes. |
| `media_items.width` | `width` | Image/video pixel width (the P10i-c–captured dims). |
| `media_items.height` | `height` | Image/video pixel height. |
| `media_items.thumb_path` | `thumbnailUrl` / `thumbnail` (`ImageObject`) | Local thumbnail reference. |
| `media_items.created_at` | `dateCreated` | GrabBit ingest time (distinct from `uploadDate`). |
| `media_metadata.upload_date` | `uploadDate` | Original publication date (a native MediaObject property). |
| `media_metadata.uploader` / `uploader_id` / `channel_id` | `author` / `creator` | A `Person`/`Organization` node (graph edge target). |
| `media_items.site` | `publisher` / `provider` | The source platform (e.g. an `Organization`). |
| `media_metadata.transcript` | `transcript` | Native on `VideoObject`/`AudioObject`. |
| `media_metadata.tags` (+ `media_tags`) | `keywords` | — |
| `media_metadata.playlist_id` / `playlist_title` | `isPartOf` | A `CreativeWorkSeries`/collection node (graph edge target). |
| *(derived from container/extension)* | `encodingFormat` | MIME/codec, derivable from the file; not a stored column today. |

**GrabBit-private fields with no standard schema.org property** — `storage_state`, `is_favorite`,
`last_accessed_at`, `folder_id`, `notes`, `content_hash`, `transcript_cues` (timed caption lines),
`source_id`/`playlist`-internal ids — are retained under a **GrabBit extension namespace** within the
JSON-LD (e.g. a `grabbit:` prefixed property block), not forced onto ill-fitting standard terms. They
remain app-private state; `transcript_cues` in particular is a GrabBit timing extension over the
standard `transcript`.

### The existing graph is already multi-type

The P10 Cozo graph already holds **non-media nodes** — uploader, playlist, tag, site —
(`docs/GRAPH-SPEC.md`), so "everything is a Thing" *formalizes* a graph GrabBit already runs rather
than inventing one. Those nodes map onto schema.org Thing types: **uploader → `Person`/`Organization`**
(the `author`/`creator` edge target), **playlist → `CreativeWorkSeries`** (`isPartOf`), **site →
`Organization`/`WebSite`** (`publisher`/`provider`), **tag → `DefinedTerm`** (`keywords`). The
MediaObject bridge is the first *file-backed* Thing type; these entity nodes are the first
*pure-metadata* Thing types, and the edges between them already exist.

## Consequences

**Positive**

- **The entire existing library becomes typed Things with zero user-visible migration cost** — no
  re-download, no re-encode, no re-transcription. Files never move.
- Proves the Things model (ADR-0001) and the generic graph keying (ADR-0002 typed nodes) against
  real, complete data on day one — MediaObject is the reference implementation of "a Thing."
- Media items immediately participate in GraphRAG and cross-type relationships (e.g. a `Recipe`
  Thing can link to the `VideoObject` it was extracted from) once other types arrive.
- Round-trippable: because the projection is rebuildable from canonical media tables, a schema/asset
  change just re-projects — no data at risk.

**Negative / obligations**

- **Two representations of media coexist** (the canonical media tables + the projected MediaObject
  Thing). We keep them honest by making the projection the **only** writer of the Thing view and
  treating the media tables as canonical for file-lifecycle fields — i.e. one-directional projection,
  not dual editing. The exact persistence shape (materialized `things` rows vs. on-read view) is a P14
  implementation choice; this ADR fixes the *mapping contract*, not the storage mechanism.
- **The committed direction is the *logical* spine, not a physical merge.** Things are GrabBit's
  conceptual/graph spine (everything is a Thing; ADR-0001), with `MediaObject` as the file-leaf and the
  media tables as its **canonical physical substrate** — zero migration, zero v1 change. **Physically
  absorbing `media_items`/`media_metadata` into the generic `things` table (a full physical spine) is a
  deferred, open question**, not a commitment — it carries real file-lifecycle migration weight (see the
  rejected alternative below) and is unscheduled. The `things` id space is kept **alignable with
  `media_items.id`** so the choice stays open without rework.
- **A few properties need light derivation** (`duration` → ISO-8601, `encodingFormat` from
  container); these are pure transforms, no new capture.
- **Extension-namespace properties are non-standard**, so they don't export to external schema.org
  consumers — acceptable, since they're app-private state, and the standard properties export cleanly.

## Alternatives considered

- **Re-ingest the library through the P14 extraction pipeline (ADR-0002) to "rebuild" media as
  Things.** Rejected: needless re-download/re-processing of data we already hold completely; slow,
  battery-hostile, and risky for no fidelity gain.
- **Invent a GrabBit-proprietary media Thing type instead of using MediaObject.** Rejected: throws
  away schema.org's existing, well-supported media vocabulary and the clean 1:1 mapping, and breaks
  interoperability/grounding for no benefit.
- **Move media fully into the generic `things` table and retire `media_items` (the full *physical*
  spine).** Rejected *for the bridge* and **deferred as an open P14+ question** (logged in BACKLOG, by
  PR 3/3): the file-lifecycle/storage-state machinery (export, scoped storage, lock) is built on the
  media tables; re-homing it is a large, risky change orthogonal to the Things model. The **logical**
  spine (projection, media tables canonical) gets the benefit now without the upheaval; the physical
  merge can be revisited later if it ever pays for itself.

## Related

- ADR-0001 — schema-as-data (the `things` store the projection targets).
- ADR-0002 — narrow-then-fill curator (how *non-media* Things are populated; media needs no
  extraction).
- ADR-0004 — relationships & provenance (the `grabbit:` extension namespace; the edges by which content
  Things reference these file-leaves; many-to-many content↔file).
- `docs/SPEC.md` §3 (the canonical media schema), `docs/ARCHITECTURE.md` §4, `docs/GRAPH-SPEC.md`.
- `docs/things-engine.md` — P14 vision one-pager.
