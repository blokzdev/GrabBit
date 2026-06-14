# GrabBit — The Things Engine (the P14–P16 spine)

> **Status: the v1 spine — a three-phase band (P14–P16)**, after the P10–P13 AI/graph pillar; before Windows
> (P17), polish (P18), and launch (P19). It promotes GrabBit from a media store into an **everything library**:
> **P14** Things foundation + MediaObject projection · **P15** curator + AI Thing-extraction from downloads ·
> **P16** universal intake + typed types & GraphRAG. P0–P13 stay media-first; Things is the spine **going
> forward** (downloads project in via the ADR-0003 bridge — not a rewrite). A one-page **vision**, not a PRD —
> each phase authors its own `docs/design/P<N>-PLAN.md` map at its start (CLAUDE.md §7). Strategic decisions
> are locked in `docs/decisions/` (ADR-0001/0002/0003/0004); the inert seams that prepare for it, shaped in
> P12–P13, live in `docs/AI-SPEC.md` §2–6 and `docs/ARCHITECTURE.md` §8.

## Problem

GrabBit v1 is a private library of **downloaded media**. But the things people want to keep from the
web aren't only media — they're recipes, events, places, articles, products. Today those get
flattened into a screenshot or a saved video, losing their structure. A folder of media is **inert**:
you can play it, but the app can't reason about it. The value the user actually wants — *understanding*
their saved corpus — needs the structure, not just the bytes.

## Thesis

**A typed, interlinked personal corpus compounds; a folder of media does not.** If GrabBit stores
what you save as **structured, AI-actionable artifacts** in a typed graph, then on-device AI can
reason across it — relate a recipe to the video it came from, find every event in a place, answer
questions over the whole library. That compounding is the moat: it grows more valuable with every
artifact and **every link** — including the user- and AI-authored connections nobody else has — and
it's only possible because everything is **on-device** (free, private, forever — the GrabBit
principle).

The artifacts are **schema.org Things** (the graph rooted at `Thing`, not just media), stored as
**JSON-LD in a generic typed graph** — schema is *data*, not 823 Dart classes (ADR-0001). The existing
downloader and private library become the **foundation layer**: every downloaded file is a
**MediaObject file-leaf** — the bytes, stored once and canonical — and richer content Things (`Recipe`,
`Event`, `Article`, even documents) **reference** those leaves via edges, so one grab can yield many
artifacts with no byte duplication. Existing downloads become typed MediaObject Things by projection,
with no re-download (ADR-0003). New artifacts are captured by a **curator** that does cheap work cheaply
and calls a small on-device function-calling model only when content must be read semantically
(ADR-0002). Relationships, and the **provenance** that makes every fact and link trustworthy and
re-improvable, are first-class — and AI-inferred ones are **proposed, not silently asserted** (ADR-0004).

## Scope (P14–P16, directional)

- **Generic Thing store** — schema.org Things (the vocabulary rooted at `Thing`) as JSON-LD in a
  `things` table; the schema.org vocabulary bundled as a read-only validation/grounding asset (ADR-0001).
- **MediaObject bridge** — the v1 library becomes Audio/Image/VideoObject Things by projection; no
  re-download, files don't move (ADR-0003). MediaObject is the **file-leaf** (the bytes); content Things
  reference it many-to-many.
- **Relationships + provenance** — three edge kinds (vocabulary / authored / reified), every Thing and
  edge stamped with where it came from, and AI-inferred links **proposed for confirmation** via the P11
  inbox rather than silently asserted (ADR-0004).
- **Curator + narrow-then-fill capture** — three-branch routing (direct-parse / single-tool /
  narrowed-set) over a function-calling small model via `generateStructured` (ADR-0002). Only the
  model-**fill** (branches b/c) is AI-tier-gated; **direct-parse capture, storage, the generic view, and
  the graph are device-universal** — the Things floor runs on every device.
- **A Unified Grab intake** — URL import + uploads + camera + barcode, all routed through the curator.
- **~6 priority types** earn bespoke UI/exporters — **Recipe, Event, Place, Article, Product** + the
  three MediaObjects; the long tail renders via a generic key/value view (ADR-0001).
- **Typed-node GraphRAG** — the P13 "ask your library" harness operates over generic typed nodes, with
  MediaObject as one type among many.

## Non-goals

- **Sequenced after the AI pillar (P14–P16).** Nothing here changes the already-built P0–P13 scope or its
  user-visible behavior; the Things Engine is purely additive, and launch (P19) still comes last.
- **Not a code-generated schema.org** — no per-type Dart classes, no per-type tables.
- **Not a pivot away from downloading.** The downloader + private container remain the foundation; the
  Things layer sits on top of them.
- **Not cloud anything.** Capture, extraction, storage, and reasoning stay on-device — no accounts, no
  telemetry, no sync, consistent with CLAUDE.md §1/§2/§9.
- **Not an authoring tool.** GrabBit captures and organizes Things; it isn't a schema.org editor.

## Success markers

- Existing media appears as typed MediaObject Things with **zero migration friction** (no
  re-download, no file movement).
- A well-marked page (e.g. a recipe with JSON-LD) is captured as a correct typed Thing **with no model
  call**; an unstructured input (screenshot, plaintext) is captured via OCR/embedding-narrowed
  extraction on capable devices, and degrades gracefully (generic capture) on devices below the AI
  tier.
- The long-tail vocabulary is storable/searchable/linkable on day one with **no per-type code**.
- "Ask your library" answers span **multiple Thing types**, not just media, citing the underlying
  Things.
- Building the Things layer on the P10–P13 AI architecture costs **little**, because the
  `generateStructured` seam, the `structured_extraction` capability row, the (planned) empty `things`
  table, and the typed-node GraphRAG harness were shaped during P12–P13.

## Related

- ADRs: `docs/decisions/0001-schema-as-data-not-schema-as-code.md`,
  `0002-narrow-then-fill-curator.md`, `0003-mediaobject-migration-bridge.md`,
  `0004-relationships-provenance-and-the-authored-edge-moat.md`.
- v1 seams: `docs/AI-SPEC.md` §2–6, `docs/design/P-AI-PLAN.md` (P12/P13), `docs/ARCHITECTURE.md` §8,
  `docs/GRAPH-SPEC.md` §10 (graph Things-readiness seam map — why the P13 graph features generalize unchanged).
- Scheduled as the **P14–P16** band in `docs/ROADMAP.md`; sibling entry in `docs/PRD.md` §9; open questions
  tracked in `docs/BACKLOG.md`.
