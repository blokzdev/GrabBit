# ADR-0004 — Relationships, provenance & the authored-edge moat

- **Status:** Accepted (Things Engine P14–P16 — architectural foundation)
- **Date:** 2026-05-29
- **Deciders:** Founder/Architect
- **Context band:** v1 / **P14–P16** (the Things Engine; see `docs/things-engine.md`). The already-built
  P0–P13 are unchanged.

## Context

ADR-0001 stores Things as JSON-LD in a generic `things` table and keys a derived graph on `things.id`.
ADR-0003 makes existing media typed `MediaObject` Things by projection. What neither pins down is the
part that actually compounds: **how Things relate to each other, and how we know where each fact and
each link came from.** A folder of typed-but-disconnected Things is barely better than a folder of
media; the value the one-pager calls the moat is the **interlinking**, and a corpus is only
trustworthy — and re-improvable — if every artifact and link carries its **provenance**.

The forces:

- **schema.org is a graph vocabulary, not a flat record format.** A huge fraction of its properties are
  **object-valued** — their value is *another Thing* (`location` → a `Place`, `author` → a `Person`,
  `encoding` → a `MediaObject`, `about` → anything). These are relationships hiding in plain sight; the
  graph should *derive* edges from them rather than invent a parallel relation model.
- **The highest-value links are the ones nobody else has.** A user's note that "this knife technique
  connects this recipe to that tool video," or an AI-surfaced relation between two artifacts, is exactly
  the personal context that makes the corpus a moat. The model must hold relationships that are **not**
  in the schema.org vocabulary — authored by a person or proposed by the AI.
- **Trust is load-bearing.** If the AI silently writes links and facts, the user stops trusting the
  graph. GrabBit's posture is no-surprise (the P11 Activity Inbox exists precisely to surface
  AI/background activity for review). So machine-inferred relations must be **proposed**, not asserted.
- **Models improve.** A Thing extracted by a 270M model today should be re-extractable by a better model
  tomorrow **without losing the original** or its source — which requires recording how each fact got
  there.
- GrabBit's graph is **already multi-type and multi-edge**: the P10 Cozo layer holds media plus
  uploader, playlist, tag, and site nodes with edges between them (`docs/GRAPH-SPEC.md`). This ADR
  generalizes that existing shape to all Things, it doesn't invent it.

## Decision

**Relationships are first-class, derived graph edges of three kinds; every Thing and every authored
edge records its provenance; and machine-inferred Things/edges are proposed for confirmation, never
silently asserted.**

### Terminology (used across the ADRs)

A **Thing** is the canonical JSON-LD record in the `things` table (ADR-0001). A **node** is that same
Thing projected into the Cozo graph — *derived and rebuildable*. **One Thing ↔ one node**: "Thing" is
the storage/vocabulary word, "node" the graph word. This is the existing `media_items`-row ↔
Cozo-media-node duality (`docs/ARCHITECTURE.md` §4, `docs/GRAPH-SPEC.md`) generalized from media to all
Things.

### The three edge kinds (all derived, all rebuildable)

1. **Vocabulary edges.** Any **object-valued JSON-LD property** projects to a typed Thing→Thing edge:
   `encoding`/`associatedMedia` (content↔file), `location` (Event↔Place), `author`/`creator`
   (work↔Person), `about`/`mentions` (work↔topic), `photo`/`image` (anything↔ImageObject), `isPartOf`
   (item↔collection). Deterministic and **auto-projected** — exactly how media→uploader/playlist/tag/
   site edges are built today.

2. **Authored edges.** A user *or* the AI may assert that two nodes relate — even across otherwise
   unrelated types — as a **loosely-typed `relatedTo` edge carrying a label, provenance, confidence,
   and an optional note.** These connections — the ones nobody else has — are the compounding asset.

3. **Reified relationships.** When the link itself **has content** (a user's tip, instruction, or
   context that bridges two nodes), the relationship becomes its own **Thing** — a `Comment`/`Note`
   (or `Role` to *qualify* a relationship) — that `about`s each participant. Promoting an annotated or
   n-ary relationship to a node makes it searchable and linkable like any other Thing.

### Cardinality: content↔file is many-to-many

The `encoding`/`associatedMedia` ↔ `encodesCreativeWork` relationship is **many-to-many**. **One file
can back many works:** a single downloaded video (one `VideoObject` file-leaf, stored once and canonical
in `media_items` per ADR-0003) can simultaneously back a `Recipe`, an `Event`, and an `Article`
extracted from its transcript — each a distinct Thing with its own edge, and `Clip` + `startOffset`/
`endOffset` let a Thing attach to a *segment* of the file. **One work can span many files:** a `Recipe`
whose `encoding` is a video *plus* a hero image *plus* a PDF. Bytes are stored once; the works that
reference them are unbounded — this is the "one grab, many artifacts" value driver.

### Provenance is first-class

Every Thing and every authored edge carries a `grabbit:` extension block (the namespace established in
ADR-0003) recording **how it came to exist**:

- `provenance` ∈ { `direct-parse`, `single-tool`, `narrowed-set` (the ADR-0002 branches),
  `user-authored`, `ai-suggested`, `ai-inferred`, `vector-similarity` },
- `sourceRef` (the input/page/Thing it derived from), `modelId` (when a model produced it),
  `confidence`, `capturedAt`.

Provenance makes the corpus trustworthy, lets a Thing be **re-extracted later with a better model**
without losing the original, and drives the rule below.

### Suggest-don't-assert

**Deterministic results auto-apply; machine-inferred results are proposed.** Direct-parse Things
(ADR-0002 branch a) and vocabulary edges are deterministic and **auto-projected**. **AI-inferred Things
and authored edges are surfaced for confirmation** — a natural fit for the **P11 Activity Inbox** —
and only become asserted on user acceptance. This keeps the graph's growth fast where it's certain and
reviewable where it's inferred, consistent with GrabBit's no-surprise posture.

## Consequences

**Positive**

- The interlinking that makes the corpus a moat is **modeled explicitly**, and the most valuable links —
  user/AI-authored relations — are first-class rather than lost.
- Edges are **derived from the canonical JSON-LD** (vocabulary edges) or stored with full provenance
  (authored edges), so the whole graph stays **rebuildable** — same canonical/derived discipline as the
  rest of the stack.
- Provenance makes **re-extraction** safe (better model later, original preserved) and makes every fact
  auditable.
- Many-to-many content↔file means a single download can yield an unbounded set of artifacts with **no
  byte duplication**.
- Suggest-don't-assert keeps user **trust** intact and reuses the P11 review surface rather than adding a
  new one.

**Negative / obligations**

- **A relationship/annotation store is now part of the graph model** (authored edges + reified
  `Comment`/`Note` Things). It must round-trip through the rebuildable projection like everything else.
- **A review/confirmation flow is required** for AI-inferred Things/edges; until P14 builds it, AI
  inference must default to *proposed* state, never auto-asserted.
- **Authored-edge labels are free-form**, so search/UX over them needs light normalization (the loose
  typing is deliberate, but it isn't free).

## Alternatives considered

- **Model relationships as a dedicated typed edge table per relation.** Rejected: vocabulary edges are
  already implied by the JSON-LD object properties and are re-derivable; a parallel hand-maintained edge
  schema duplicates the vocabulary and fights ADR-0001's "schema is data."
- **Let the AI auto-assert inferred Things/edges with an undo.** Rejected: erodes trust and floods the
  graph with unreviewed noise; "propose via the inbox" gets the growth without the surprise.
- **Keep provenance in a separate audit log rather than on the artifact.** Rejected: provenance is
  needed at read/render/re-extract time and belongs **on** the Thing/edge; a side log desyncs and
  complicates the rebuildable projection.
- **Restrict relationships to the schema.org vocabulary only.** Rejected: that throws away the
  user/AI-authored links that are precisely the moat.

## Related

- ADR-0001 — schema-as-data (the `things` store; object properties that become vocabulary edges).
- ADR-0002 — narrow-then-fill curator (the branches that stamp `provenance`; suggest-don't-assert for
  branches b/c).
- ADR-0003 — MediaObject as the file-leaf and migration bridge (the `grabbit:` extension namespace;
  the canonical bytes that content Things link to).
- `docs/GRAPH-SPEC.md` (the existing multi-type/multi-edge Cozo graph this generalizes),
  `docs/AI-SPEC.md` §5–6 (typed-node GraphRAG), `docs/design/P11-PLAN.md` (the Activity Inbox review
  surface).
- `docs/things-engine.md` — P14–P16 vision one-pager.
