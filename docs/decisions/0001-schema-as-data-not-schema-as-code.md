# ADR-0001 — Schema-as-data, not schema-as-code

- **Status:** Accepted (v2 Things Engine — architectural foundation, not yet scheduled)
- **Date:** 2026-05-28
- **Deciders:** Founder/Architect
- **Context band:** v2 (the Things Engine; see `docs/things-engine.md`). v1 (P12→P13→P14)
  is unchanged by this decision.

> **About this format.** GrabBit's Architecture Decision Records live in `docs/decisions/`,
> numbered `NNNN-kebab-title.md`. Each ADR is tight and self-contained: **Context** (the forces
> in play), **Decision** (what we commit to, phrased as decided), **Consequences** (what becomes
> easy/hard, and the obligations we take on), and **Alternatives considered** (what we rejected and
> why). ADRs are immutable once Accepted; we supersede rather than rewrite. This is the first ADR,
> so it establishes the format; subsequent ADRs reuse it.

---

## Context

The expanded GrabBit vision (v2) reframes the app as a **domain-agnostic local library of
structured, AI-actionable artifacts** — schema.org *Things* (Recipe, Event, Place, Article,
Product, and the Audio/Image/VideoObject media types) — not only downloaded media. The compounding
value is a **typed, interlinked personal corpus**: a folder of media is inert, but a graph of typed
Things with relationships is something on-device AI can reason over (memory-as-moat).

schema.org is a **vocabulary of ~823 types** rooted at a single top type, **`Thing`**, and arranged
beneath it in a deep `rdfs:subClassOf` hierarchy — with peer top-level branches including
`CreativeWork` (which holds `MediaObject`, `Recipe`, `Article`, `DigitalDocument`, …), **`Event`**,
**`Place`**, **`Person`**, **`Organization`**, **`Product`**, and `Intangible`. Each type carries
dozens of properties, most optional and many shared. Note our priority types **span branches**:
`Recipe`/`Article`/the MediaObjects are CreativeWorks, but **`Event`/`Place`/`Product` are not** — they
hang directly off `Thing`. So a generic store must be rooted at **`Thing`**, not `CreativeWork`. Two
implementation shapes were on the table:

1. **Schema-as-code** — generate (or hand-write) a Dart class per schema.org type, with typed fields,
   and a Drift table (or column set) per type.
2. **Schema-as-data** — store Things generically as JSON-LD and treat the schema.org vocabulary as a
   bundled **reference asset**, with bespoke code reserved for the handful of types that earn it.

The forces:

- The hierarchy is **large, evolving, and mostly long-tail.** Generating 823 classes (and keeping
  them in sync with schema.org releases) is a recurring maintenance tax for types almost no user will
  ever touch. It also bloats the binary and the analyzer surface.
- GrabBit's storage is **already correctly layered**: Drift (SQLite) is the canonical store, and the
  Cozo graph/vector index is a *derived, rebuildable* projection keyed by `MediaItems.id`
  (`docs/ARCHITECTURE.md` §4, `docs/GRAPH-SPEC.md`). A generic typed-row store fits this grain.
- JSON-LD is schema.org's native serialization. Most extraction sources (web pages with `<script
  type="application/ld+json">`, OG/microdata lifted into JSON-LD, LLM tool-call outputs) already
  produce JSON-LD-shaped data, so storing it verbatim avoids a lossy object-mapping round-trip.
- A small set of types (**~6 priority types**) genuinely warrant first-class UX and exporters; the
  rest only need to be *stored, searched, linked, and viewed* — a generic capability.

## Decision

**The v2 Things Engine stores schema.org Things as JSON-LD in a single generic `things` table; it
does not model the schema.org hierarchy as Dart classes or per-type tables.**

Concretely (design language — no schema bump or code lands in the foundation-docs initiative):

1. **Generic storage.** A `things` Drift table holds, at minimum:
   - `id` (stable primary key, GrabBit-owned),
   - `type` (the schema.org `@type`, e.g. `Recipe`, `VideoObject`),
   - `jsonld` (the full JSON-LD document as text — the canonical payload),
   - a few **promoted/indexed columns** denormalized out of the JSON-LD for query/sort/FTS:
     `name`, `url`, `created_at` (and others only as query needs prove out).

   The promoted columns are a **cache of the JSON-LD**, never a second source of truth; on conflict,
   the `jsonld` document wins and the columns are re-derived. This mirrors the existing
   "Drift canonical / Cozo derived" discipline one level down.

2. **Schema.org as a bundled read-only asset.** The schema.org JSON-LD **context + type/property
   definitions** ship as a read-only app asset, used for (a) **validation** (is this `@type` known;
   are these properties defined on it), (b) **AI grounding** (the curator and function-calling model
   read type/property definitions to fill tool schemas — see ADR-0002), and (c) **generic rendering**
   (label/expected-type lookups for the key/value view). The full ~823-type hierarchy comes **"for
   free"** as data; we vendor and version the asset, we do not transcribe it into Dart.

3. **Long-tail vs. priority types.** Any Thing whose `@type` we recognize renders through a
   **generic, schema-driven key/value view** (property → value, grouped/labelled via the asset).
   The **~6 priority types** — **Recipe, Event, Place, Article, Product**, plus the three
   **MediaObject** subtypes (Audio/Image/VideoObject; see ADR-0003) — earn **bespoke UI and exporters**
   when their phase comes. Bespoke types still store their canonical data as JSON-LD in the same
   `things` table; the bespoke layer is *presentation/export over the same rows*, not a separate store.

4. **The graph indexes Things generically.** Cozo nodes/edges and the HNSW vector index are keyed on
   `things.id` with `type` as a node attribute — so GraphRAG and graph features operate over **generic
   typed nodes** (ADR-0002 §worked-examples; `docs/AI-SPEC.md` §5–6), MediaObject being one type among
   many rather than a special case. A **Thing** is the canonical JSON-LD record here; its **node** is
   the derived Cozo projection (one Thing ↔ one node). How relationships become **edges** (vocabulary,
   authored, and reified) and how each Thing/edge carries **provenance** is fixed in **ADR-0004**.

## Consequences

**Positive**

- The entire schema.org vocabulary is supported on day one as storable/searchable/linkable data, with
  **zero per-type code** and **zero codegen** to maintain across schema.org releases (bump the asset).
- Storage stays aligned with the existing canonical/derived architecture; the graph and FTS layers
  treat Things uniformly.
- Bespoke effort is spent only where it pays off (the ~6 priority types), and bespoke UX is additive
  over the generic store rather than a fork of it.
- Extraction pipelines can persist JSON-LD verbatim (direct-parse branch, ADR-0002) with no object
  mapping, preserving fidelity and provenance.

**Negative / obligations**

- **No compile-time typing of Thing properties.** Property access is dynamic (JSON-LD traversal),
  so validation must happen **at the boundary** (on write/import) against the schema.org asset —
  consistent with CLAUDE.md §8 "validate only at boundaries." We accept dynamic access as the price
  of not maintaining 823 classes.
- **Promoted columns require a derivation discipline.** Whenever the promoted set changes, existing
  rows must be re-derived from `jsonld` (a rebuildable, idempotent backfill — same shape as the
  existing FTS/dimension backfills).
- **Asset versioning.** We own keeping the bundled schema.org asset reasonably current and
  documenting its version; a stale asset degrades validation/grounding but never corrupts data
  (unknown types still store).
- Querying deep into JSON-LD beyond the promoted columns needs either more promoted columns or JSON1
  expressions; we add promoted columns lazily as real query needs appear, not speculatively.

## Alternatives considered

- **Generate a Dart class per schema.org type (schema-as-code).** Rejected: ~823 classes + per-type
  tables is a large, perpetually-stale maintenance surface and binary/analyzer bloat for
  overwhelmingly long-tail types, with little benefit over dynamic JSON-LD given boundary validation.
- **Per-type tables for priority types + generic table for the rest (hybrid storage).** Rejected as
  the *storage* model: it splits Things across two stores and complicates the graph/FTS keying and
  migrations. The priority types instead get bespoke **UI/exporters over the same generic rows** —
  the benefit without the split. (Promoted columns already give priority-type queries their hot path.)
- **A schemaless blob with no validation or asset.** Rejected: loses the AI-grounding and
  validation value of the vocabulary, and makes the long-tail key/value view unlabelled and
  unsortable.

## Related

- `docs/things-engine.md` — the v2 vision one-pager.
- ADR-0002 — narrow-then-fill curator (how Things get *populated*).
- ADR-0003 — MediaObject as the migration bridge (how existing downloads *become* Things).
- ADR-0004 — relationships, provenance & the authored-edge moat (how Things *relate*, and how each
  Thing/edge records where it came from).
- `docs/GRAPH-SPEC.md`, `docs/AI-SPEC.md` — the graph + AI layers that index/reason over Things.
