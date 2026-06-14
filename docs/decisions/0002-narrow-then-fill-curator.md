# ADR-0002 — Narrow-then-fill curator architecture

- **Status:** Accepted (P14 Things Engine — architectural foundation)
- **Date:** 2026-05-28
- **Deciders:** Founder/Architect
- **Context band:** v1 / **P14** (the Things Engine; see `docs/things-engine.md`). The already-built
  P0–P13 are unchanged; the only earlier touch is the `generateStructured(...)` seam this ADR motivates,
  shaped inert in P12 (`docs/AI-SPEC.md` §2).

## Context

The P14 Things Engine turns arbitrary inputs — a pasted URL, an uploaded file, a camera capture, a
barcode, a screenshot, a block of plaintext — into typed schema.org Things (ADR-0001). The hard part
is **deciding what type a thing is and filling its properties** without an expensive, error-prone
"throw everything at a big LLM" step on every input.

The forces:

- **On-device = free, forever** (CLAUDE.md §2). But "free" is compute and battery, not zero cost: a
  small-LLM call on a mid/low-end phone is the most expensive step in the pipeline. The cheapest call
  is **the one we don't make**.
- A large fraction of real inputs **already carry structured data**: web pages routinely embed
  `<script type="application/ld+json">` schema.org blocks, OpenGraph tags, or microdata. Recipe sites,
  product pages, articles, and events are especially well-marked. Extracting that needs **no model at
  all**.
- When a model *is* needed, **a smaller, narrower prompt is faster and more accurate.** A
  function-calling model handed *one* tool definition (or a handful) fills it far more reliably than
  one asked to pick from 823 possible types and invent a schema.
- GrabBit already has the upstream signals to route cheaply: a **device-capability/tier system**
  (P12 `DeviceCapabilityService`/`ModelCapabilityMatrix`), an **on-device embedder** (P10, for
  classification by similarity), **ML Kit OCR** (P12, for images/screenshots), and the existing
  **probe/metadata** path from the downloader.

We need an architecture that does the cheap work cheaply and reserves the model for what genuinely
requires reading content semantically.

## Decision

**A `Curator` sits upstream of any LLM call and routes every input through three branches, escalating
cost only as ambiguity demands. A function-calling small model fills typed tool schemas (the
"narrow-then-fill" step) only on the two branches that need it.**

### The three branches

**(a) Direct-parse — no model call.**
When structured data is already present — JSON-LD, OpenGraph, or microdata — the Curator parses it
directly into a Thing (ADR-0001's `things` row), validating `@type` and properties against the
bundled schema.org asset. Zero inference. This is the preferred path and is expected to cover a large
share of URL imports.

**(b) Single-tool — one `generateStructured` call.**
When the input lacks ready structure but a **classifier is confident** about the type (e.g. a
known cooking-blog domain, a barcode that resolves to a Product, a page whose markup strongly implies
`Recipe`), the Curator selects **one** tool definition (the schema for that type) and calls the
function-calling model to **fill** it from the content. One type, one narrow schema, high accuracy.

**(c) Narrowed-set — one `generateStructured` call over 2–5 tool defs.**
When the type is **ambiguous** but bounded, the Curator narrows the 823-type space down to a small
candidate set (**2–5 tool definitions**) using cheap signals — embedding-based classification (P10),
OCR'd text (P12 ML Kit), URL/domain heuristics, MIME type — and lets the model choose among them and
fill the chosen schema. The model never sees the full vocabulary; it disambiguates within a curated
shortlist.

### Division of labor (the principle)

> **The Curator does work that is cheaper than a model call; the model only does what requires
> reading content semantically.** Detection of existing structure, classification, OCR, and narrowing
> are deterministic-or-cheap and run on any device. Filling free-form content into a typed schema is
> the one step that needs the LLM — and it runs against the **smallest schema set** the Curator can
> justify.

### Model & seam

The fill step uses a **function-calling small model** — candidates **FunctionGemma 270M** (Gemma
license — vetting deferred to P12 start per `docs/AI-SPEC.md` §4) and **Qwen3-0.6B** (Apache-2.0).
It is invoked through a new `generateStructured(toolDefs, prompt)` seam on the generation layer
(`docs/AI-SPEC.md` §2) and gated by a `structured_extraction` capability row in `ModelCapabilityMatrix`
(`docs/AI-SPEC.md` §3). Branch (a) requires no model; branches (b)/(c) are **AI-tier-gated** — on a
device that can't run the fill model, the Curator still serves branch (a) and degrades (b)/(c) to a
generic/manual capture rather than crashing (consistent with AI-SPEC §1 graceful gating). Only the
*fill* step is gated this way: capture, storage, the generic key/value view, and the graph itself are
**device-universal**.

### Provenance & confirmation

Every Thing the Curator writes records **which branch produced it** in its `grabbit:` provenance block
(`direct-parse` / `single-tool` / `narrowed-set`; ADR-0004). The branch also sets the trust default:
**branch (a) direct-parse is deterministic and auto-applies**, while **model-filled Things from
branches (b)/(c) are surfaced for confirmation** rather than silently asserted — the suggest-don't-assert
rule (ADR-0004), a natural fit for the **P11 Activity Inbox**.

## Worked examples

These three drive the design and are the acceptance lens for the curator when it ships:

1. **Cooking blog with Recipe JSON-LD → branch (a), direct-parse.**
   The page embeds `<script type="application/ld+json">{"@type":"Recipe", …}`. The Curator detects it,
   validates against the schema.org asset, and writes a `Recipe` Thing **with no model call**. Fast,
   free, exact, and faithful to the publisher's own structured data.

2. **Reddit food screenshot → OCR → branch (c), narrowed-set.**
   An uploaded image has no markup. The Curator runs **ML Kit OCR** to lift text, embeds it (P10) and
   classifies: the content looks food-related but could be a `Recipe`, an `Article`, or a plain
   `ImageObject`. The Curator narrows to those **2–3 tool defs** and calls `generateStructured`; the
   model picks `Recipe` and fills ingredients/steps from the OCR text. (If AI is gated off, it stores
   as an `ImageObject` with the OCR text retained.)

3. **Pasted plaintext → embedding-classification → branch (c), narrowed-set.**
   The user pastes raw text with no URL or markup. The Curator embeds it and, by nearest-type
   similarity, narrows to a small candidate set (e.g. `Event` vs `Article` vs `CreativeWork`), then
   calls `generateStructured` over those defs to classify-and-fill. The full vocabulary is never sent
   to the model.

## Consequences

**Positive**

- The **majority of well-marked inputs cost zero inference** (branch a), and the rest run the model
  against a **minimal schema set**, maximizing accuracy and minimizing latency/battery on-device.
- Cleanly **AI-tier-gated**: branch (a) is device-universal; (b)/(c) layer on for capable devices,
  with a defined degraded path — matching GrabBit's "graceful gating, never a crash" rule.
- The seam (`generateStructured`) is **small and shaped during v1** (P12/P13), so P14 slots in without
  reworking the AI engine contracts.
- Reuses signals GrabBit already builds (embedder, OCR, probe, capability matrix) rather than adding a
  parallel ML stack.

**Negative / obligations**

- **Classifier/narrowing quality is now load-bearing.** A wrong narrow can exclude the correct type.
  Mitigation: conservative narrowing (prefer a slightly larger candidate set when unsure) and a
  manual type-override affordance in the UI when P14 ships.
- **More moving parts than one big prompt.** The Curator is genuine routing logic with several signal
  sources; it must be testable in isolation (deterministic branch selection given fixed signals).
- **Two model candidates carry a license fork** (FunctionGemma's Gemma terms vs. Qwen3's Apache-2.0).
  Per AI-SPEC §4 the decision is **deferred to P12 start**; this ADR locks the *architecture*, not the
  model.
- Branch (a) parsing must be defensive (malformed/partial JSON-LD, hostile markup) and validate at the
  boundary against the schema.org asset.

## Alternatives considered

- **Single big-LLM call per input (no curator).** Rejected: most expensive path run on the cheapest
  inputs; worst accuracy (full-vocabulary type selection) and worst battery cost; impossible to serve
  on low-end devices that should still get direct-parse.
- **Direct-parse only (no model fill ever).** Rejected: abandons unstructured inputs (screenshots,
  plaintext, poorly-marked pages) — exactly the inputs where structured capture is most valuable.
- **Always send the full schema.org vocabulary as tool defs.** Rejected: huge prompts, poor small-model
  accuracy, high latency; the narrowing step exists precisely to avoid this.
- **Rules-only classification (no embeddings/LLM).** Rejected: brittle across the long tail; the
  embedder already exists (P10) and generalizes far better for narrowing than hand-written rules.

## Related

- ADR-0001 — schema-as-data (what a filled Thing is stored as).
- ADR-0003 — MediaObject bridge (existing downloads as Things, no extraction needed).
- ADR-0004 — relationships & provenance (the provenance block branches stamp; suggest-don't-assert for
  branches b/c).
- `docs/AI-SPEC.md` §2 (`generateStructured`), §3 (`structured_extraction` capability + model
  candidates), §4 (licensing/vetting), §5–6 (typed-node GraphRAG).
- `docs/things-engine.md` — P14 vision one-pager.
