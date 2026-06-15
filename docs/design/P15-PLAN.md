# P15 — Curator + AI Thing-extraction from downloads: subphase plan

> The sub-roadmap for **P15** (see `docs/ROADMAP.md` and the vision one-pager `docs/things-engine.md`).
> P15 is the **second phase of the Things Engine band (P14–P16)** — and the band's **marquee payoff**: the
> on-device AI **curator** reads what you download (transcript / AI summary / description / OCR) and
> **extracts structured schema.org Things** — a cooking video → a `Recipe`, a vlog → a `Place`/`Event`. It
> activates the long-shaped but **inert** `generateStructured` function-calling seam (`GenerationEngine`,
> P12f) and runs the **narrow-then-fill** routing of ADR-0002. Every extraction is a **suggestion, not an
> assertion** (ADR-0004): nothing touches the canonical `things` table or the graph until the user confirms,
> via a confirmation sheet surfaced through the **P11 Activity Inbox**. The phase makes the typed library
> **tangible** with a **Things Browser (v1)** — browse/filter by `@type` over the new Things plus P14's
> `MediaObject` projection. P15 is **device-universal** except for the **model fill** itself: capture,
> storage, the Browser, and the confirm flow run on every device; only the AI step is tier-gated and
> **gracefully disabled** with a friendly reason where unsupported. Deep contracts: `docs/decisions/`
> (ADR-0001 schema-as-data · ADR-0002 narrow-then-fill curator · ADR-0004 suggest-don't-assert/provenance),
> `docs/AI-SPEC.md` §2/§5–6, `docs/GRAPH-SPEC.md` §10.

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named `claude/p15<sub>-<topic>`. Each
  keeps CI green (`dart format` · `flutter analyze` · `flutter test`), runs `build_runner` if codegen
  (drift/riverpod/freezed/json) changed, and updates `docs/VERIFICATION.md` for new user-facing/on-device
  behaviour.
- **Each subphase gets its own plan** (plan → approve → execute, CLAUDE.md §7). This doc is the **map**: it
  locks the decomposition + phase-level decisions; per-subphase design happens at that subphase's start.
- **One schema migration:** the only DB change lands once in **P15c** — **v15→v16**, the `thing_suggestions`
  table (pending, unconfirmed extractions). The `things`/`thing_edges` tables are **reused as-is**; do not
  bump the schema elsewhere in the phase.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). **P15b** is pure-Dart and
  ships as a standalone green-CI PR; the subphases that touch the real model, the DB, the inbox, or UI —
  **P15a** (real function-calling fill), **P15c** (extraction service), **P15d** (confirmation + inbox),
  **P15e** (Browser), **P15f** (auto-extract) — need APK spot-checks and are **batched** into the P15
  consolidated on-device pass.
- **Build on existing seams, don't fork them:** the inert `generateStructured`/`StructuredToolDef`/
  `StructuredResult` contracts (`lib/core/ai/generation_engine.dart`, `structured_generation.dart`); the
  `ModelCapabilityMatrix` per-capability gating + `DeviceTier` probe; the P14 `ThingRepository`/
  `ThingEdgeRepository`/`Provenance` + `grabbitProvenanceBlock`/`SchemaOrgVocabulary`
  (`propertiesFor`/`validateThingDoc`)/MediaObject projection; the P13 auto-*-on-download pattern +
  `autoSummaryDecision` (`queue_controller.dart`); the P11 `NotificationCenter.post` (`ai` category); and the
  "View as Thing" generic render (`item_detail_screen.dart`).
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Fill model = the resident generation model via `flutter_gemma` function-calling.** No bespoke model, no
  FunctionGemma (Gemma-license + an extra download). Bump `flutter_gemma 0.16.1 → 0.16.5` — function-calling
  for **Gemma 4 E2B** landed there (Qwen3-0.6B/Qwen2.5-1.5B already honor tools). The seam becomes a thin
  **1:1 adapter**: `StructuredToolDef{name, description, parameters}` → flutter_gemma `Tool{name, description,
  parameters}`; `FunctionCallResponse{name, args}` → `StructuredResult{toolName, arguments}`. The curator's
  two narrowing branches map onto `ToolChoice`: **single-tool (confident) → `ToolChoice.required`**;
  **narrowed-set (ambiguous) → `ToolChoice.auto`**. This **dissolves the long-deferred FunctionGemma-vs-Qwen3
  license fork** — every eligible model is **Apache-2.0**.
- **`structured_extraction` capability matrix** (mirrors the generation tiers minus the non-FC SmolLM2):
  **low → none** (gated off, friendly reason); **mid → Qwen3-0.6B**; **high → Qwen3-0.6B + Qwen2.5-1.5B +
  Gemma 4 E2B**, **recommended Gemma 4 E2B** (strongest, Apache-2.0). SmolLM2-135M is excluded — it ignores
  tools. This fills the empty `eligibleStructuredExtractionModels`/`recommendedStructuredExtractionModel`
  stubs.
- **Narrow-then-fill (ADR-0002), branches (b)+(c) only.** P15 covers **unstructured download text**:
  single-tool when the classifier is confident, narrowed-set (2–5 candidate types) when ambiguous. Branch (a)
  **direct-parse** (structured JSON-LD/OpenGraph/microdata) + universal intake is **P16**. Tool schemas are
  **small curated subsets** of priority-type fields (web: <20 props, depth <3), built from the bundled vocab
  via `SchemaOrgVocabulary.propertiesFor(type)` — never the full ~1010 types.
- **Suggest-don't-assert (ADR-0004).** Extractions are **pending suggestions** in a new `thing_suggestions`
  table — never written to canonical `things`/the graph until the user confirms. On **accept** →
  `upsertThing` + an authored `upsertEdge` from the new Thing to its source `MediaObject`, stamped
  `grabbit:provenance` (`single-tool`|`narrowed-set` · `modelId` · `confidence` · `sourceRef`); on **reject**
  → discarded. Confirmation is surfaced through the **P11 Activity Inbox**.
- **On-demand first.** The core trigger is an **"Extract Things"** action on item detail;
  auto-extract-on-download is a later **opt-in (P15f)** mirroring `autoSummarizeOnDownload`/OCR/tag.
- **Device-universal floor.** Capture, storage, the Things Browser, and the confirm flow run on **every
  device**; only the **model fill** is tier-gated. Ineligible devices show a friendly disabled reason, and the
  Browser still works over the projected `MediaObject`s.
- **Validate at the boundary.** Model output is run through `validateThingDoc` (advisory), unknown props
  dropped, **before** it becomes a suggestion. Model imperfection stays safe because nothing is asserted
  without confirmation (CLAUDE.md §8).
- **Things Browser v1 = browse/filter by `@type` + generic render.** Bespoke per-type cards/exporters and the
  full type-aware browser are **P16**.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P15a — `generateStructured` impl + `structured_extraction` gating *(engine; APK)*
Make the inert function-calling seam real — the precondition for the curator.
- Map `StructuredToolDef` → flutter_gemma `Tool`, pass `tools` + `toolChoice` when creating the chat, and
  parse the model's `FunctionCallResponse{name, args}` → `StructuredResult` on the **flutter_gemma-backed**
  `GenerationEngine` (`flutter_gemma_generation_engine.dart`). `UnavailableGenerationEngine` keeps throwing
  `unavailable` (graceful on ineligible tiers/platforms).
- Bump `flutter_gemma 0.16.1 → 0.16.5` (Gemma 4 E2B function-calling); justify in the commit + record in
  `docs/SPEC.md`.
- Fill `eligibleStructuredExtractionModels`/`recommendedStructuredExtractionModel` in `ModelCapabilityMatrix`
  (mid: Qwen3-0.6B; high: Qwen3-0.6B + Qwen2.5-1.5B + Gemma 4 E2B, recommended Gemma 4 E2B; low: none).
- **Exit / review:** on a capable device, `generateStructured` fills a one-tool schema from a prompt → a
  valid `StructuredResult`; the low tier is gated off. CI covers the adapter mapping (fake/contract test) +
  the matrix rows. *(APK: real on-device model fill.)*
- **Status:** shipped — `flutter_gemma` bumped to `^0.16.5`; `generateStructured` implemented on
  `FlutterGemmaGenerationEngine` via a pure `structured_tool_adapter.dart` (`toGemmaTool` /
  `toolChoiceFor` — 1 candidate→`required`, ≥2→`auto` / `structuredResultFrom`), passing
  `tools` + `supportsFunctionCalls: true` + `toolChoice` to `createChat` and returning the first
  `FunctionCall`/`ParallelFunctionCall` response (text-only → `generateFailed`). Matrix rows filled
  (low none · mid Qwen3-0.6B · high Qwen3-0.6B + Qwen2.5-1.5B + Gemma 4 E2B, recommended Gemma 4 E2B;
  SmolLM2 excluded). Stale `unsupported` doc comments retired. CI green (adapter mapping + matrix rows
  + Unavailable fallback). **The real on-device model fill is batched into the P15 consolidated pass →
  stays `[~]` until then** (CLAUDE.md §7).

### `[x]` P15b — The Curator: classify → tool-schema → validated ThingDoc *(pure Dart; CI)*
The pure curator (ADR-0002 routing) + tool-schema builder + result assembly — no I/O, fully unit-testable.
- **Classify** with cheap signals (keywords/tags/site/MIME; optional embedder similarity to type exemplars) →
  a small candidate set of priority types (Recipe/Event/Place/Article/Product).
- **Build** a small `StructuredToolDef` per candidate from `SchemaOrgVocabulary.propertiesFor(type)` — a
  curated field subset (web: <20 props, depth <3), with the candidate count selecting the branch (1 → single-
  tool/`required`; 2–5 → narrowed-set/`auto`).
- **Assemble:** `StructuredResult.arguments` → `validateThingDoc` (advisory) → drop unknown props → a
  `ThingDoc` stamped via `grabbitProvenanceBlock(single-tool|narrowed-set, modelId, confidence, sourceRef,
  capturedAt)`.
- **Exit / review:** fixture text + a **fake** `generateStructured` → a valid `Recipe` `ThingDoc` with
  provenance and only-known props; branch selection covered by unit tests. *(CI-discharged — no on-device
  behaviour.)*
- **Status:** shipped — `lib/core/things/curator/`: `priority_types.dart` (the 5-type catalog + curated <20-prop
  field subsets, **vocab-validated** so curation can't drift), `thing_classifier.dart` (pure keyword/host/
  media-type scoring → single-tool vs narrowed-set + per-type confidence), `curator.dart` (`buildToolDef`
  JSON-schema, prompt, and the injected-`generateStructured` orchestration → boundary-validated, provenance-
  stamped `ThingDoc`; `null` on no-extract, rethrows `unavailable`). 35 unit tests (catalog/classifier/curator)
  over the real vocab + a fake engine. Real-model fill efficacy is exercised in P15c's APK check. Pure-Dart, no
  codegen — **CI-discharged → `[x]` on merge.** The optional embedder-similarity scorer is deferred
  (`docs/BACKLOG.md`, *From P15b*).

### `[~]` P15c — Extraction service + on-demand trigger + pending suggestions *(data + UI; APK; the one schema bump)*
Wire the curator to real item text, persist its output as **pending** suggestions, and expose the on-demand
trigger.
- `ThingExtractionService`: gather the best available text (`aiSummary ?? transcript ?? description ??
  ocrText` via `MetadataRepository`), run the **Curator** over the **active generation model**, and persist
  results as **pending suggestions** in a new **`thing_suggestions`** Drift table — **the one P15 schema bump
  (v15→v16)** — (`id`, `sourceItemId`, `type`, `jsonld`, `confidence`, `createdAt`), **not** in `things`. A
  hand-written repository/provider (Drift row types throw `InvalidTypeException` under codegen, CLAUDE.md §8).
- **Capability-gated** (`structured_extraction`) through a pure decision helper mirroring `autoSummaryDecision`
  (`extractThingsDecision(hasText, modelReady)` → extract / needsModel / skip); graceful no-op + friendly
  reason on low/ineligible.
- Add an **"Extract Things"** action on item detail (visible on capable devices in **both** Simple/Advanced;
  the raw "View as Thing (JSON-LD)" diagnostic stays Advanced-only).
- **Exit / review:** tapping "Extract Things" on a capable device yields persisted **pending** suggestions
  (nothing in `things` yet); ineligible shows a friendly reason; the **v15→v16** upgrade is tested. CI: the
  decision helper + suggestion persistence + migration. *(APK: real extraction over a real library, offline.)*
- **Status:** shipped — `thing_suggestions` table + **v15→v16** migration (`database.dart` + migration test);
  `ThingSuggestionRepository` (`replaceForItem` = idempotent re-run) + provider; the `structured_extraction`
  providers `structuredExtractionSupported`/`activeStructuredExtractionModel` (`generation_provider.dart`);
  the 4-state `extractThingsAction` (mirrors `aiSummaryAction` — the manual on-ramp, *not* the 3-state
  background `autoSummaryDecision`, which is P15f); `ThingExtractionService` (gather text → Curator → persist,
  `ExtractionOutcome`); and the **"Extract Things"** item-detail action (gated on `structuredExtractionSupported`,
  routes setup/download → AI settings). 16 new CI tests (migration · repo · decision · service over the real
  vocab + a fake engine). **CI-green; the real-extraction APK check is batched into the P15 close → stays
  `[~]`** (§7).

### `[~]` P15d — Confirmation flow + Activity Inbox integration *(UI; APK)*
Close the suggest-don't-assert loop: the user confirms before anything is asserted (ADR-0004).
- A **confirmation surface** — a route-reachable `SuggestionReviewScreen` at `/item/:id/suggestions`
  (the inbox deep-links via `context.push`, and the app has no route-based sheets) — renders a pending
  suggestion (generic key/value via `suggestionDisplayFields`, confidence chip) with **Accept / Edit /
  Reject**. **Accept** → `upsertThing(thing_<micros>)` + `upsertEdge(subject: thing, object: sourceItemId,
  predicate: isBasedOn, provenance: userAuthored)` → delete the suggestion. **Reject** → confirm dialog →
  delete (writes nothing). **Edit** → a minimal inline editor (string fields / comma-joined lists) → "Save &
  Accept" runs the same accept path. The Thing keeps its curator provenance; the **edge** is user-authored.
- Post an actionable `NotificationCategory.ai` inbox entry per extraction ("Confirm extracted Recipe?") via
  the shared `postSuggestionNotification` helper, with `targetRoute` to the screen + `itemId` + `dedupeKey`
  (coalesces repeats); item detail also shows a "Review" SnackBar action.
- **Exit / review:** confirming an extracted `Recipe` asserts it in `things` and links it (`isBasedOn`) to its
  `MediaObject`; rejecting writes nothing. CI green: the accept/reject/edit write path + the inbox entry +
  `suggestionDisplayFields` (service test) + a review-screen widget test. **The APK pass (inbox entry →
  screen → assert, on device) is batched into the P15 close → stays `[~]`** (§7).

### `[ ]` P15e — Things Browser (v1) *(UI; APK)*
The first visible payoff of the pivot — the "everything library" becomes tangible.
- A surface that **browses + filters** the typed Things by `@type` (the new Recipe/Event/… plus the projected
  `MediaObject`s), tapping into the generic render or the linked media item. Reuses `watchThingsByType` + a new
  **all-types** query (distinct `@type`s with counts); a nav/route entry; available in **both** UI modes.
- **Exit / review:** the Browser lists + filters Things by type over a real library; tapping a Thing opens its
  render/linked item. CI: the all-types query + a widget test. *(APK: over a real, mixed library.)*

### `[ ]` P15f — Auto-extract-on-download opt-in + P15 phase close *(UI + docs; APK)*
The opt-in automation, then close the phase.
- An opt-in **`autoExtractOnDownload`** setting (default off; mirrors the P13 auto-* toggles): on download
  complete, if enabled **and** the model is ready, extract in the background → **suggestions via the inbox**
  (**never** auto-asserted). Plugs into `queue_controller._persistCompleted` **after** the auto-tag block,
  reusing `extractThingsDecision`; per-item failures never fail the download.
- **Phase close:** add `docs/VERIFICATION.md` rows + a **"P15 — consolidated cross-feature on-device pass"**
  (on-demand extract over a real library · the confirm/reject loop · inbox entries · the Browser · auto-extract
  · graceful gating on an incapable tier); flip the P15 markers per the §7 earned-`[x]` rule; update the
  ROADMAP/`things-engine.md` status; route any deferrals to `docs/BACKLOG.md`.
- **Exit / review:** the consolidated on-device pass closes P15 (→ **P16**, universal intake + typed types &
  GraphRAG).

---

## Deferred (out of P15 scope → P16 / BACKLOG)
- **Branch (a) direct-parse + universal "Grab anything" intake** (URL/file/web-article/camera/barcode, with
  structured JSON-LD/OpenGraph/microdata parsed without the model) → **P16**.
- **Bespoke per-type cards/exporters + the full type-aware Things Browser** → **P16** (P15 ships browse/filter
  + generic render only).
- **Reified relationships** (an edge promoted to a `Comment`/`Note`/`Role` Thing) + an **authored-edge
  authoring UI** → **P16**.
- **Thing-level embedding index** (so extracted non-media Things are semantically searchable / appear in "Ask
  your library") → the dedicated phase already in `docs/BACKLOG.md` (sequence with P15/P16); P15 reuses media
  vectors as P14e shipped.
- **FunctionGemma 270M as a specialized rung** → **not pursued** (Gemma-license + extra download; Gemma 4 E2B
  covers the capable tier under Apache-2.0).
