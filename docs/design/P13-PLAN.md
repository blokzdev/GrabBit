# P13 — LLM feature surface & polish (incl. local GraphRAG): subphase plan

> The sub-roadmap for **P13** (see `docs/ROADMAP.md` and the lean summary in `docs/design/P-AI-PLAN.md`).
> P13 turns the **device-tiered AI engine** P12 shipped — generation (`flutter_gemma`), transcription
> (whisper.cpp), and embeddings (Gecko / multilingual MiniLM) — into the **user-facing AI payoff**, layered
> on the P10 graph + vector index. It ships: **abstractive summarization** (on the P10 TextRank floor),
> **translation + OCR** (ML Kit), the **"Ask your library" local GraphRAG chat**, **smart auto-tagging**,
> **advanced graph analytics** (community-detection auto-albums, centrality "Rediscover", path/bridge), and
> **model-selector UX polish**. Everything stays **on-device = FREE** (CLAUDE.md §1): no cloud, no accounts,
> no telemetry; the only network calls are downloads + the one-time, integrity-checked model fetches P12
> already established. Every AI feature is **gated and graceful** — an ineligible device gets a friendly
> disabled state, never a crash. Deep contracts live in `docs/AI-SPEC.md` §5–§6 and `docs/GRAPH-SPEC.md` §7.
> Much of P13 drives native runtimes (LLM generation, ML Kit), so it is verified on-device.

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named `claude/p13<sub>-<topic>`.
  Each keeps CI green (`dart format` · `flutter analyze` · `flutter test`), runs `build_runner` if codegen
  (freezed/json/drift/riverpod) changed, and updates `docs/VERIFICATION.md` for new user-facing behaviour.
- **Each subphase gets its own plan** (plan → approve → execute, CLAUDE.md §7). This doc is the **map**:
  it locks the decomposition + phase-level decisions; per-subphase design happens at that subphase's start.
- **Schema bumps minimal & named per subphase.** Candidates: a cached abstractive summary, OCR-extracted
  text (to feed the P10h FTS5 index). Bump only when a subphase needs durable storage; name it in that card.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). The generation/ML Kit/
  GraphRAG subphases (**P13a, P13b, P13c, P13d**) need APK spot-checks and are batched; the pure-Dart parts
  (retrieval/context assembly, ranking, graph algorithms run via `runScript`) ship as standalone green-CI PRs.
- **Build on the existing seams**, don't fork them (see Design decisions). P13 adds **no new engine
  abstractions** — it consumes `GenerationEngine`, `GraphQueryService`, `EmbedderEngine`, the model
  catalog/picker, and the existing summary/tag/collections UI.
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Capability-gating, never a crash.** LLM features (summaries, auto-tagging, GraphRAG generation) gate on
  the generation tier via `ModelCapabilityMatrix.eligibleGenerationModels(tier)`; an ineligible device sees a
  muted disabled-reason tile (reuse the P12g `DeviceTierCopy` + disabled-tile pattern) and the feature
  falls back to its non-LLM floor where one exists. **OCR/translate gate on ML Kit availability + opt-in,
  not the RAM tier** — they run on far more devices than the LLM (AI-SPEC §1, §8).
- **Build on existing seams, don't fork.** Reuse, do not re-abstract:
  - `GenerationEngine.generate()` (streaming) via `generationEngineProvider` (`lib/core/ai/generation_provider.dart`)
    — the same path the P12d Labs self-test exercises.
  - `GraphQueryService.relatedTo` / `neighborhood` (`lib/core/graph/graph_query_service.dart`) — the hybrid
    **vector + graph re-rank** retrieval built & tested in P10c-b is the GraphRAG retrieval half.
  - `itemSummaryProvider` + `_SummarySection` on item detail (`lib/features/library/presentation/item_detail_screen.dart`)
    and the TextRank floor (`lib/core/text/textrank.dart`) for summarization.
  - The P10c-c-2 tag-suggestion chip flow (metadata editor) for auto-tagging.
  - The P12g model picker + catalog/download (`ai_settings_screen.dart`, `model_catalog.dart`) for the selector.
- **TextRank stays the always-available floor.** Abstractive summary is a gated **upgrade layered on top** —
  never a replacement. Low/ineligible tiers keep the extractive TL;DR (AI-SPEC §5).
- **Auto-tagging = free-text LLM generation + parse.** Prompt the active model for tags, parse the text, feed
  the existing suggestion chips. `generateStructured` **stays inert**; the FunctionGemma-vs-Qwen3 license fork
  stays deferred to v2 / BACKLOG (avoids pre-building the v2 Things-Engine curator — ADR-0002).
- **ML Kit for OCR/translate** (`google_mlkit_text_recognition`, `google_mlkit_translation`): on-device,
  language packs downloaded on demand by ML Kit; no model bundled. **Measure APK-size impact in the first
  ML Kit APK build** and budget per GRAPH-SPEC/CI discipline.
- **GraphRAG operates over generic typed nodes.** v1 media + entity nodes (uploader/playlist/tag/site) are
  one case; a future typed-**Thing** corpus is the general case, so the retrieve→generate loop needs no
  rework when v2 arrives (forward seam — ADR-0001, ADR-0004). Grounded answers **cite deep-linkable library
  items**; **low/ineligible tiers fall back to retrieval-only** ("here are the relevant items/passages") with
  the extractive summary, no generation. Validate **LLM + HNSW RAM co-residency** on real devices
  (BACKLOG item carried from P12d-2).
- **Sequencing:** lead with **summarization** (smallest real-generation feature — proves the
  generation→feature path + graceful gating end-to-end), then the independent ML Kit work, then auto-tagging,
  then the **GraphRAG flagship mid-phase** once the generation patterns are proven, then graph analytics, then
  polish + close.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P13a — Abstractive summarization *(generation; APK)*
The first **real** generation feature — an LLM TL;DR layered on the existing extractive floor.
- Add an **abstractive summary** path that feeds the active model the item's `transcript ?? description`
  (the same source the TextRank floor uses) and streams a short natural-language summary into a new
  **`_AiSummarySection`** **above** the extractive `_SummarySection` on item detail, clearly labelled
  "AI summary · generated on-device".
- **Opt-in + generation-tier-gated.** Reuse `generationEngineProvider`/`activeGenerationModelProvider` + the
  P12g gating pattern; **low / ineligible tiers keep the extractive TextRank summary** (no regression, no
  empty state). When the device *can* generate but generation isn't enabled, a **`aiSummaryAction`** on-ramp
  (mirroring `transcribe_fallback`) routes to AI settings to enable + download.
- **Cache** the result: `MediaMetadata.aiSummary` + `aiSummaryModelId` (schema **v10→v11** — the one P13a
  migration), written via `MetadataRepository.updateAiSummary`. Instant reopen + model attribution + a
  **Regenerate** action.
- **Exit / review:** on a capable device, an item with text yields a streamed abstractive summary on-device;
  toggling the model off / on a low-end device cleanly shows the extractive floor; cached summaries survive
  restart. APK spot-check (low + high).
- **Status:** implemented (CI-green) — `aiSummary`/`aiSummaryModelId` columns + v11 migration (+ test);
  `MetadataRepository.updateAiSummary` (upsert/clear, tested); pure `buildSummaryPrompt` (head-truncated to a
  char budget; long-transcript chunking deferred) + `aiSummaryAction` decision (both unit-tested); the
  `_AiSummarySection` widget streams `generate()` into a live preview, persists, and offers Regenerate.
  **Pending on-device APK spot-check** (pick a model → Summarize with AI → streamed summary offline →
  persists across restart; low-tier shows only the extractive floor; the on-ramp routes to AI settings). The
  end-to-end widget flow is APK-verified (the item-detail screen's player/related shimmer makes a full
  `pumpAndSettle` widget test unreliable — same boundary as the P10f-2 transcript flow).

### `[ ]` P13b — Translation & OCR (ML Kit) *(native; new deps; APK; split into 2 PRs)*
On-device text intelligence that is **device-universal-ish** — gated on ML Kit + opt-in, not the RAM tier.
Adds `google_mlkit_translation` / `google_mlkit_text_recognition`; measure APK-size impact in the first build.

#### `[ ]` P13b-1 — Translation *(native; APK)*
- Translate an item's **description / transcript / summary** into the user's chosen language on-device, with
  on-demand ML Kit language-pack download (opt-in, progress, integrity managed by ML Kit). Surface on item
  detail next to the original text.
- **Exit / review:** translate a non-English item's text offline after the pack downloads; no pack ⇒ a clear
  one-time setup prompt; nothing leaves the device.

#### `[ ]` P13b-2 — OCR *(native; APK)*
- Extract text from **image downloads** via ML Kit text recognition; store it (one schema bump if needed) so
  it is **searchable** — feeding the P10h FTS5 index and the semantic embed doc — and shown on item detail.
- **Exit / review:** an image with legible text becomes findable by that text in search; the OCR text persists
  and feeds search/related; gating is graceful where ML Kit is unavailable.

### `[ ]` P13c — Smart auto-tagging *(generation; APK)*
LLM-suggested tags feeding the **existing** tag system — builds directly on the P13a generation patterns.
- Prompt the active model with the item's text for candidate tags; parse the **free-text** response (no
  structured seam); present them through the **existing P10c-c-2 suggestion chips** in the metadata editor so
  the user reviews/applies (never auto-writes silently).
- **Generation-tier-gated**; low / ineligible tiers simply don't show the LLM suggestions (the existing
  graph-co-occurrence tag suggestions remain).
- **Exit / review:** a capable device suggests sensible tags from an item's content offline; tapping a chip
  persists the tag via the existing repository path; ineligible devices degrade to the co-occurrence chips.

### `[ ]` P13d — Local GraphRAG "Ask your library" *(flagship; split into 3 PRs)*
The headline differentiator — natural-language Q&A grounded in the private library, fully on-device
(AI-SPEC §6, GRAPH-SPEC §7). Sequenced **mid-phase** so the generation patterns (P13a/c) are proven first.

#### `[ ]` P13d-1 — Retrieval + context & citation assembly *(pure Dart; CI-verifiable)*
- A pure-Dart **retrieval/context packer** that reuses `GraphQueryService.relatedTo` (vector + graph re-rank)
  and `neighborhood` to select the most relevant nodes + their graph neighborhood for a query, then assembles
  a **bounded, cited** context block (node → deep-linkable item) and the generation prompt. No UI, no model —
  fully unit-testable.
- **Exit / review:** for a seeded graph, the packer returns the expected relevant nodes + a well-formed,
  size-bounded prompt with stable citations; covered by unit tests.

#### `[ ]` P13d-2 — Chat UI + streaming grounded answer + citations *(native; APK)*
- A dedicated **"Ask your library"** screen (reached from Dashboard/Library) that runs P13d-1's context
  through `GenerationEngine.generate()` and **streams** a grounded answer with **tappable citations** that
  deep-link to the cited library items.
- **Exit / review:** ask a natural-language question on a capable device and get a streamed, grounded answer
  citing real library items **offline**; citations navigate correctly. APK spot-check.

#### `[ ]` P13d-3 — Low-tier fallback + RAM co-residency validation *(native; APK)*
- On ineligible / low tiers, fall back to **retrieval-only** ("here are the most relevant items") plus the
  extractive summary — no generation, clearly framed. Validate **LLM + Cozo HNSW RAM co-residency** on real
  devices (the index lives in RAM with the model — BACKLOG from P12d-2) and tune limits.
- **Exit / review:** a low-end device gives a useful retrieval-only answer without OOM; a capable device runs
  generation + the live HNSW index together within memory budget (verified on real hardware).

### `[ ]` P13e — Advanced graph analytics & viz *(graph; split into 3 PRs)*
The richer graph payoff beyond P10's Duplicates + Suggested-similarity albums (GRAPH-SPEC §7). Runs via
`GraphStore.runScript` / `GraphQueryService`; device-universal (deterministic graph algorithms, no LLM).

#### `[ ]` P13e-1 — Community-detection auto-albums *(graph; APK)*
- **Label-propagation / community detection** over the similarity + entity graph → richer auto-albums,
  surfaced in Collections beside the existing auto-albums with one-tap **Save as collection**.
- **Exit / review:** clusters are coherent on a real library; degrades to nothing when the graph is
  unavailable; saving a cluster creates a normal collection.

#### `[ ]` P13e-2 — Centrality "Rediscover" *(graph; APK)*
- **PageRank / betweenness × `lastAccessedAt`** to resurface central-but-stale items; surfaced as a
  "Rediscover" strip (Dashboard/Library).
- **Exit / review:** Rediscover surfaces genuinely central, not-recently-opened items; empty/ graceful when
  the graph is unavailable.

#### `[ ]` P13e-3 — Path/bridge discovery + graph-view polish *(graph; APK)*
- **Shortest-path / connectivity** between two items or entities ("how are these related?"), plus graph-view
  interaction/visual polish on the existing `graphview` screen.
- **Exit / review:** a path between two nodes renders and explains the connection; graph-view polish lands
  without regressing the P10c-e/f interactions.

### `[ ]` P13f — Capability-gating + model-selector UX polish & phase close *(pure Dart/UI; minimal)*
- **Model-selector UX polish** across the now-real AI features (the P12g picker was built for the engine
  surface); any **manual transcription-trigger UX** gaps (transcription itself shipped in P12e — fold in only
  what's missing); consistent per-feature gating copy.
- `docs/VERIFICATION.md` rows for every new user-facing behaviour; consolidate the owed on-device pass; flip
  P13a–P13f + the P13 summary to done; route deferrals to `docs/BACKLOG.md`.
- **Exit / review:** every P13 feature shows a clear enabled/gated state; opt-ins persist across restart;
  **P13 complete** — and with it the v1 AI pillar (next: P14 beta & launch).

> **✅ P13 complete.** _(Filled in at phase close — what shipped across P13a–P13f + the consolidated
> on-device verification pass.)_

---

## Deferred (cut from P13 → `docs/BACKLOG.md` or a later band)
- **Real `generateStructured` + the FunctionGemma-vs-Qwen3 license fork** → v2 / BACKLOG (auto-tagging uses
  free-text generation; the structured seam stays inert per ADR-0002).
- **Smart auto-tagging as the v2 Things-Engine curator** — P13's free-text tagging is deliberately
  lightweight; the narrow-then-fill structured curator is the v2 Things Engine (ADR-0002, `docs/things-engine.md`).
- **Long-transcript multivector chunking** for GraphRAG passage retrieval — only if modest-library retrieval
  proves insufficient (AI-SPEC §5; carried from P10g-1 / BACKLOG).
- **Cloud inference** — out of scope permanently (the AI engines' cloud seam is theoretical/unplanned;
  CLAUDE.md §1).
