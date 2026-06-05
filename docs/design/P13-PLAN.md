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

#### `[~]` P13a-2 — Opt-in auto-summarize on download *(generation; APK)*
A maintainer-requested follow-up: auto-generate the abstractive summary for newly downloaded items in the
background, **opt-in (default off)**, mirroring the `autoTranscribe` precedent (P12e-3).
- `SettingsModel.autoSummarizeOnDownload` (+ setter); a toggle in the AI-settings generation card, shown only
  when generation is enabled.
- In `queue_controller._persistCompleted` (after the auto-transcribe block, so a just-built transcript is the
  source): for each completed item, gated by `autoSummarizeOnDownload && generationEnabled` and a pure
  `autoSummaryDecision` (skip / needsModel / summarize) — **runs only when the model is already downloaded
  (`ensureReady`, never fetches)**; collects `generate(buildSummaryPrompt(text))` and persists via
  `updateAiSummary`.
- Activity Inbox: a `category: ai` success entry (`summary_$id`), or a one-time "finish setting up summaries"
  nudge (`summary_needs_model`) when opted in but no model is downloaded.
- **Exit / review:** with auto-summarize on + a downloaded model, a finished download gets a summary + an
  inbox entry **offline**; no model → one nudge; default-off / generation-off → nothing auto-runs; the queue
  still drains. APK spot-check.
- **Status:** implemented (CI-green) — settings field + setter, `autoSummaryDecision` (unit-tested), queue
  integration + two inbox posts, the AI-settings toggle, and three queue tests (ready → summary + ai entry;
  no-model → nudge; generation-off → no-op). No schema change (reuses P13a's columns). **Pending APK
  spot-check.** Shares the queue-decoupled-background-AI deferral (inline-before-next-pump like
  `autoTranscribe`) and the LLM+HNSW RAM co-residency check (P13d) — both in `BACKLOG.md`.

### P13b — OCR & Translation (ML Kit) *(native; new deps; APK)*
On-device text intelligence that is **device-universal-ish** — gated on ML Kit + opt-in, not the RAM tier.
**Reordered (maintainer call): OCR leads** — it uses the bundled Latin model (no Google Play Services, fully
offline) so it de-risks the ML Kit dependency before the more complex translation (language-pack downloads +
target-language UX + GMS nuance). Measure APK-size impact in the first ML Kit build.

#### `[~]` P13b-1 — OCR (on-demand) *(native; APK)*
- Extract text from **image** items via ML Kit text recognition (bundled Latin); store it so it is
  **searchable** — feeding the P10h FTS5 index and the semantic embed doc — and shown on item detail.
- **Exit / review:** an image with legible text becomes findable by that text in search; the OCR text persists
  and feeds search/related; gating is graceful where ML Kit is unavailable.
- **Status:** implemented (CI-green) — `google_mlkit_text_recognition` (bundled Latin, no GMS, offline);
  `OcrEngine` interface + `MlKitOcrEngine`/`UnavailableOcrEngine` + factory/provider (mirrors the transcription
  engine seam); `MediaMetadata.ocrText` (**schema v11→v12**) + `media_fts` gains an `ocr` column (table +
  triggers + backfill rebuilt in the v12 migration) so search covers image text; `ocrText` added (capped) to
  the embed doc; `MetadataRepository.updateOcrText`; a `_OcrSection` "Scan text"/"Rescan" action on image
  detail. No opt-in toggle (OCR is free + offline). Tests: OCR FTS search, `updateOcrText` round-trip, v11→v12
  migration (incl. FTS `ocr`), embed-doc inclusion, engine availability. **Pending APK spot-check** (scan a
  real image → text appears + becomes searchable, offline). The widget + native ML Kit call are APK-verified.

#### `[~]` P13b-2 — Translation *(native; new deps; APK)*
- Translate an item's **description + transcript** into the app's language (default) with a target-language
  picker (reuses `_captionLanguages`), via `google_mlkit_translation` + `google_mlkit_language_id`; on-demand
  language-pack download (Wi-Fi-aware). Ephemeral (no cache/schema). Surfaced inline with a "Show original"
  toggle. (Derived AI/TextRank summaries stay original → BACKLOG.)
- **Exit / review:** translate a non-English item's text offline after the pack downloads; no pack ⇒ a clear
  one-time setup prompt; nothing leaves the device.
- **Status:** implemented (CI-green) — `google_mlkit_translation`/`google_mlkit_language_id` (MIT; **no Google
  Play Services** — models download over HTTPS, run offline); `TranslationEngine` seam + `MlKitTranslationEngine`/
  `UnavailableTranslationEngine` + factory/provider (mirrors `OcrEngine`); pure `translateReadiness` decision +
  `translateLanguageForCode` mapping; an autoDispose `itemTranslation(itemId)` controller (screen-scoped, no
  cache); a `Translate…` overflow action → target picker → source detect → ~30 MB pack-download confirm →
  translate; description + transcript render translated with a "Translated from <src> · Show original" toggle.
  Added a one-shot `MetadataRepository.metadataForItem`. **No schema change.** Tests: engine availability +
  BCP mapping, `translateReadiness` truth table, controller with a fake engine. **Pending APK spot-check**
  (the native ML Kit translate/language-id + the pack download); the widget flow is APK-verified.

#### `[~]` P13b-3 — Auto-OCR on download (+ image-download fix) *(follow-up; native; APK)*
- Opt-in (default off) auto-scan of **image** downloads, mirroring P13a-2 auto-summarize: a settings toggle +
  a gated block in `queue_controller._persistCompleted` (runs inline; OCR is cheap + offline) → `updateOcrText`
  → an Activity Inbox entry. Grows search coverage automatically.
- **Precursor fix (maintainer call):** `classifyDownloadOutputs` routed **all** image extensions to `thumb`,
  so a single-image download (a photo/carousel) produced **no media item** — auto-OCR would never fire.
  Fixed: image files are tentative thumbnails, but when a download has **no video/audio**, the images **are**
  the media (→ `image` items). Reuses `mediaTypeForExt` for consistency. This also fixes image downloads
  generally (they now appear in the library, with dimensions, OCR, etc.).
- **Exit / review:** an image-only download becomes an `image` item; with auto-OCR on, it's scanned + becomes
  searchable offline; default-off / video items do nothing; the queue still drains.
- **Status:** implemented (CI-green) — classifier fix (+ tests); `autoOcrOnDownload` setting + setter; pure
  `shouldAutoOcr`; gated auto-OCR block in `_persistCompleted` (`ocrCount` in `_PersistResult`) + an `ai`
  success inbox entry when text is found; an "Image text (OCR)" auto-scan card in AI settings (shown where ML
  Kit runs). Tests: classifier image cases, `shouldAutoOcr` truth table, settings round-trip, and queue cases
  (image+text → `ocrText` + entry; default-off no-op; video skipped). **No schema/deps change.** **Pending
  APK spot-check** (real image download → image item + searchable text + inbox entry, offline).
- **Pre-merge sweep refinements (same PR):** (a) `MediaThumb` now falls back to the image **file** for
  `image` items with a null thumbnail (they were showing a movie-icon placeholder in grid/dashboard/
  collections/hero/related); (b) the classifier collapses an image + its yt-dlp `--write-thumbnail` sidecar
  to **one** item (largest = photo, smaller = thumbnail) so a single image download isn't double-counted;
  (c) quick wins — auto-transcribe skips image items, and `durationSec` is gated to non-image. The
  unconditional `--write-thumbnail` and non-`mediaTypeForExt` image formats are logged in `BACKLOG.md`.

### `[~]` P13c — Smart auto-tagging *(generation; APK)*
LLM-suggested tags feeding the **existing** tag system — builds directly on the P13a generation patterns.
- Prompt the active model with the item's text for candidate tags; parse the **free-text** response (no
  structured seam); present them through the **existing P10c-c-2 suggestion chips** in the metadata editor so
  the user reviews/applies (never auto-writes silently).
- **Generation-tier-gated**; low / ineligible tiers simply don't show the LLM suggestions (the existing
  graph-co-occurrence tag suggestions remain).
- **Exit / review:** a capable device suggests sensible tags from an item's content offline; tapping a chip
  persists the tag via the existing repository path; ineligible devices degrade to the co-occurrence chips.
- **Status:** implemented (CI-green) — **on-demand** (maintainer call): a separate, gated **"AI suggestions"**
  row in the metadata editor (`_AiTagSuggestions`, below the graph `_Suggestions`), hidden when no generation
  model fits the device. Pure `buildTagPrompt` + forgiving `parseTagSuggestions` (split/strip/lowercase/dedupe/
  exclude-applied/cap); an autoDispose `itemAiTags(itemId)` controller (mirrors the P13b-2 translation
  controller) builds the source from title + description/transcript/`ocrText`, generates, parses excluding
  current tags; chips reuse `ActionChip` + `addTagToItem` (never auto-written). Reuses `aiSummaryAction` for
  the on-ramp; one-shot `MetadataRepository.tagNamesForItem`/`mediaItemById`. **No deps/schema.** Tests:
  prompt/parse units, controller (fake engine — excludes applied, lowercases, error path), editor gating
  (low hides / high shows). **Pending APK spot-check** (generate + apply on a real item offline). The
  generate→chips flow is APK-verified. Background **auto-tag-on-download is a deliberate follow-up (P13c-2)**.

#### `[~]` P13c-2 — Opt-in auto-tag on download (marked AI) *(generation; APK)*
Follow-up: the LLM **applies** tags to new downloads in the background, opt-in (default off). Because tags are
user-curated (they drive facets), AI tags are **marked** (provenance) rather than silently mixed in.
- **Schema v12→v13:** `MediaTags.source` (`withDefault('user')`); `addTagToItem(…, {source})` (insertOrIgnore
  keeps an existing link's source → user tags never demoted); `watchAiTagNamesForItem` + provider.
- **Settings** `autoTagOnDownload` (default off) + setter; `_AutoTagTile` in the generation card.
- **Pure** `autoTagDecision` (skip/needsModel/tag). **Queue** (`_persistCompleted`, after auto-OCR): build
  source from title + description/transcript/`ocrText`, `buildTagPrompt` → `generate` → `parseTagSuggestions`
  (exclude applied) → `addTagToItem(source: 'ai')`; `tagCount`/`tagNeedsModel` in `_PersistResult`; an `ai`
  inbox entry ("N tags added") or a "finish setup" nudge.
- **Marking:** the editor + item-detail tag chips show `auto_awesome_outlined` on AI-sourced tags (via
  `aiTagNamesForItemProvider`); AI tags appear as normal search facets.
- **Status:** implemented (CI-green) — schema v13 (+ a defensive table-guard in the migration, mirroring the
  v8 guard-add spirit, so partial older test DBs don't break); repo provenance + provider; settings + tile;
  `autoTagDecision`; queue block + two inbox posts; chip marking in both surfaces. Tests: `autoTagDecision`,
  repo provenance (only-ai set; user not demoted), v12→v13 migration, settings round-trip, queue (applied as
  'ai' + entry; default-off no-op). **No deps.** **Pending APK spot-check** (real download → AI-marked tags +
  facets, offline). A library "hide/filter AI tags" facet is deferred (BACKLOG).

### `[~]` P13d — Local GraphRAG "Ask your library" *(flagship; split into 4 PRs)*
The headline differentiator — natural-language Q&A grounded in the private library, fully on-device
(AI-SPEC §6, GRAPH-SPEC §7). Sequenced **mid-phase** so the generation patterns (P13a/c) are proven first.
**Revised target (maintainer call): a real multi-turn chat**, not single-shot — persistent conversations
(list / continue / rename / archive / delete) on capable tiers, each turn re-retrieving **fresh RAG sources**
plus a **bounded recent-history window** whose depth scales with the device tier; entry from the **Dashboard**.
Incapable / low tiers fall back to an ephemeral **retrieval-only** answer (d-3).

#### `[x]` P13d-1 — Retrieval + context & citation assembly *(pure Dart; CI-verifiable)*
- A pure-Dart **retrieval/context packer** that reuses the P10 semantic substrate (`embedderEngine.embed` →
  `GraphQueryService.vectorSearch`) plus a light `relatedTo` graph re-rank to select the most relevant items
  for a query, then assembles a **bounded, cited** context block (item → deep-linkable source) and a
  **history-aware** generation prompt. No UI, no model, no schema — fully unit-testable.
- **History-aware prompt builder** (`fitHistory` char-budget knob) so d-2 multi-turn drops in cleanly and the
  per-tier history depth is a graceful budget, not a hard mode switch.
- **Status:** implemented (CI-green). New `lib/features/ai/data/`: `rag_context.dart` (pure — `RagSource`,
  `RagChatTurn`, `RagContext`, `kRagSystemPrompt`, `buildSourceSnippet`, `selectRagSources`, `fitHistory`,
  `buildRagPrompt`), `rag_availability.dart` (pure — `RagAvailability {unavailable, retrievalOnly, full}` +
  `ragAvailability(...)`, the d-3 gate), `rag_retriever.dart` (`RagRetriever` + provider: embed → vectorSearch
  → `relatedTo` re-rank → hydrate via `MetadataRepository` → cited context; empty-sources when retrieval isn't
  ready). Tests: prompt/snippet/`fitHistory`/`selectRagSources`, the `ragAvailability` truth table, and the
  retriever with fake embedder + graph + seeded in-memory metadata. **No deps, no schema, no UI.**
- **Exit / review:** for seeded sources, the retriever returns the expected ordered, cited items + a
  well-formed, size-bounded, history-aware prompt; degrades to empty-sources when retrieval is unavailable;
  covered by unit tests. ✓

#### `[~]` P13d-2a — Chat schema + Ask screen (single conversation) *(native; APK)*
- Drift **`chats` + `chat_messages`** schema; a dedicated **"Ask your library"** screen from the Dashboard
  that runs P13d-1's per-turn fresh retrieval + bounded history through `GenerationEngine.generate()` and
  **streams** a grounded answer with **tappable citations** deep-linking to the cited items. Generation-gated
  via `aiSummaryAction` (on-ramp when no model).
- **Status:** implemented (CI-green). **Schema v13→v14** (`Chats`: id/title/createdAt/updatedAt/`archivedAt?`;
  `ChatMessages`: autoinc id, `chatId`→`Chats` FK cascade, role, content, `citationsJson?`, createdAt —
  forward-included so d-2b needs no further migration). New `lib/features/ai/data/chat_repository.dart`
  (`ChatRepository` + `chatRepositoryProvider`/`chatMessagesProvider`); `lib/features/ai/presentation/`
  `ask_chat.dart` (pure — `messagesToHistory`, `encode`/`decodeCitations`, `parseCitationSpans`),
  `ask_controller.dart` (`AskController`: create-on-first-send → append user → re-retrieve with bounded history
  → stream grounded answer → persist with citations; no-sources → graceful reply, no LLM call),
  `ask_screen.dart` (transcript + streaming bubble + inline `[n]`/Sources citations + gated input);
  `dashboard/.../widgets/ask_entry_tile.dart` (auto-hides off the full-generation path); `/ask` route.
  Tests: migration v13→v14 (+ cascade), repo, the pure helpers, the controller (full/no-sources/error), and
  the entry-tile gating. **No new deps.**
- **Exit / review:** ask a natural-language question on a capable device → a streamed, grounded, cited answer
  **offline**; the turn persists; citations navigate. APK spot-check. ✓ (CI parts) · APK owed

#### `[~]` P13d-2b — Conversation list + manage *(native)*
- A conversation **list** with **continue / rename / archive / delete**; resuming a chat re-feeds the bounded
  history into each new turn's prompt.
- **Status:** implemented (CI-green; APK spot-check owed). **List-first** entry — the Dashboard tile (`/ask`)
  now opens a **`ConversationsScreen`** (most-recent-first, "New chat" FAB, empty-state CTA), with continue
  (`/ask/chat/:id`), new chat (`/ask/chat`), and an **`ArchivedChatsScreen`** (`/ask/archived`). `ChatRepository`
  gains `watchChatList({archived})` (one query with a latest-message preview subquery), `renameChat`,
  `setArchived`, `deleteChat` (messages cascade), `watchChatTitle` + `activeChatsProvider`/`archivedChatsProvider`/
  `chatTitleProvider`. `AskController` is now a **family keyed by `String? chatId`** — a seeded id continues a
  thread (history feeds back), `null` creates on first send (the d-2a behaviour); `AskScreen` takes `chatId` and
  shows the live, renamable title. **No schema change** (v14 already carried `title`/`archivedAt`); no new deps.
  Tests: repo (recency/preview ordering, active-vs-archived split, archive toggle, rename incl. blank-ignored,
  cascade delete), the resumable controller (continue feeds prior turns; no new chat), and a `ConversationsScreen`
  widget test (rows/preview, empty-state CTA, row Rename/Archive/Delete menu).
- **Exit / review:** prior chats list, reopen and continue with retained context, and archive/delete/rename
  behave; covered where CI can (provider/repository) + an APK spot-check for the flow. ✓ (CI parts) · APK owed

#### `[~]` P13d-3 — Low-tier fallback + tier-aware depth + RAM co-residency *(native; APK)*
- On ineligible / low tiers (`ragAvailability == retrievalOnly`), fall back to an ephemeral **retrieval-only**
  answer ("here are the most relevant items") — no generation, clearly framed, nothing persisted. Tune the
  **tier-aware history-depth** budget. Validate **LLM + Cozo HNSW RAM co-residency** on real devices (the index
  lives in RAM with the model — BACKLOG from P12d-2) and tune limits.
- **Status:** implemented (CI-green; RAM co-residency + low-tier flow APK-owed). `AskEntryTile` now shows
  whenever the graph is available + the library is non-empty, routing capable tiers → `/ask` and low/ineligible
  tiers → a new **`RelevantItemsScreen`** (`/ask/relevant`): a query → `semanticResultsProvider` → the most
  relevant items in a `MediaGrid` (tap → item), **ephemeral** (no persistence), with an on-ramp when Smart
  search isn't ready. **Tier-aware depth:** `historyBudgetForTier(DeviceTier)` (`ask_chat.dart`; low/mid 1000,
  high 3000) feeds `AskController`'s per-turn `retrieve(historyCharBudget:)` — the concrete RAM lever for mid.
  **No schema, no deps.** Tests: the budget truth table, the controller passing the tier budget, the entry-tile
  retrieval-only visibility + route, and the `RelevantItemsScreen` (results / empty / not-ready on-ramp).
- **Exit / review:** a low-end device gives a useful retrieval-only answer without OOM; a capable device runs
  generation + the live HNSW index together within memory budget (verified on real hardware). ✓ (CI parts) ·
  APK owed (RAM co-residency on real low/mid hardware)

### `[~]` P13e — Advanced graph analytics & viz *(graph; split into 3 PRs)*
The richer graph payoff beyond P10's Duplicates + Suggested-similarity albums (GRAPH-SPEC §7). Runs via
`GraphStore.runScript` / `GraphQueryService`; device-universal (deterministic graph algorithms, no LLM).

#### `[~]` P13e-1 — Community-detection auto-albums *(graph; APK)*
- **Label-propagation / community detection** over the similarity + entity graph → richer auto-albums,
  surfaced in Collections beside the existing auto-albums with one-tap **Save as collection**.
- **Status:** implemented (CI-green; APK spot-check owed). Runs over the **entity graph** (shared
  uploader/playlist/tag + co-download) — **every-device, no embedder** (maintainer call; semantic-similarity +
  tier enhancements → BACKLOG). New `lib/core/graph/community_clustering.dart` (pure **deterministic label
  propagation**, mirrors `near_duplicate_clustering.dart`; prunes over-generic buckets); `cozo_query.dart`
  `entityMembershipScript()` + `coDownloadPairsScript()`; `GraphQueryService.communityClusters()`;
  `clusteredAlbumsProvider` + `clusterLabel` (dominant **tag → uploader → site → title**) reusing the
  `SuggestedAlbum` model + `/suggested-album` screen; a **"Discovered"** section in Collections → Albums. **No
  schema, no deps.** Tests: clusterer (determinism, web-merge, bucket pruning, min/max, dominant tag), the two
  scripts, `communityClusters` decode, the provider (hydrate/label/empty), and the Discovered section.
- **Exit / review:** clusters are coherent on a real library; degrades to nothing when the graph is
  unavailable; saving a cluster creates a normal collection. ✓ (CI parts) · APK owed

#### `[~]` P13e-2 — Centrality "Rediscover" *(graph; APK)*
- **PageRank × staleness** to resurface central-but-stale items; surfaced as a "Rediscover" strip on the
  **Dashboard and Library**.
- **Status:** implemented (CI-green; APK spot-check owed). **PageRank** chosen (deterministic power iteration;
  betweenness is O(V·E) — too costly for a strip, deferred to BACKLOG/e-3). Runs over the **entity item-graph**
  (shared uploader/playlist/tag + co-download), reusing e-1's `entityMembershipScript()`/`coDownloadPairsScript()`
  pulls (decode shared via a private `_entityGraph()` helper) — **every-device, no embedder**. New
  `lib/core/graph/centrality.dart` (pure `buildItemGraph` weighted adjacency + `pageRank`);
  `GraphQueryService.itemCentrality()`; pure `rediscover.dart` `rankRediscover` (`score = centrality ×
  staleness`; staleness = days since `lastAccessedAt ?? createdAt`, capped at 30d; **excludes** items touched
  within 14d); `rediscoverProvider` + a `RediscoverRow` strip (mirrors `RecentMediaRow`, auto-hides when empty)
  on the Dashboard and atop the Library (only when not searching/filtering/selecting). **No schema, no deps.**
  Tests: centrality (weight accumulation, bucket pruning, hub > leaf, determinism, dangling), `itemCentrality`
  decode, `rankRediscover` (fresh-exclusion, staleness weighting, cap, empty), the provider, and the row.
- **Exit / review:** Rediscover surfaces genuinely central, not-recently-opened items; empty/graceful when
  the graph is unavailable. ✓ (CI parts) · APK owed

#### P13e-3 — Path/bridge discovery + graph-view polish *(graph; APK; split into 2 PRs)*
Bundled two distinct deliverables, so split for phone-reviewable PRs: **e-3a** path/bridge discovery, **e-3b**
graph-view polish (which also adds the in-graph path-highlight surface). "Path" surfaces in **both** places —
the chain screen (e-3a) and the graph view (e-3b), reusing the same engine.

##### `[~]` P13e-3a — Path/bridge discovery (connection engine + chain screen) *(graph; APK)*
- **Shortest-path / connectivity** between two **items** ("how are these related?"), rendered as a readable
  connection **chain**.
- **Status:** implemented (CI-green; APK spot-check owed). **Item↔item** shortest path via pure-Dart **BFS**
  over the **bipartite** item↔entity graph (shared uploader/playlist/tag + co-download), reusing e-1/e-2's
  `_entityGraph()` pull — **every-device, no embedder; no new Cozo script, no schema, no deps.** New
  `lib/core/graph/path_finding.dart` (`findItemPath` → `GraphPath`, oversized buckets pruned, deterministic,
  entity hops collapsed to connectors: "same channel"/"same playlist"/"shared tag '…'"/"downloaded together");
  `GraphQueryService.pathBetween()`; `connectionPathProvider` (hydrates to `MediaItem`s); `ConnectionPathScreen`
  (chain of item cards + connectors, route `/item/:id/path?to=<other>`); a reusable searchable `pickLibraryItem`
  bottom sheet; an item-detail **"How is this related to…?"** entry (gated on graph availability). Tests: the
  path engine (direct/multi-hop/co-download/disconnected/same-id/bucket-prune/determinism/labels), `pathBetween`
  decode, the provider (hydrate/missing-node/unavailable), the screen, and the picker.
- **Exit / review:** a path between two items renders and explains the connection; "No connection found" for
  islands; absent when the graph is unavailable. ✓ (CI parts) · APK owed

##### `[~]` P13e-3b — Graph-view polish + in-graph path highlight *(graph; APK)*
- Graph-view interaction/visual polish on the existing `graphview` screen (zoom/fit controls, layout
  stability, relations legend), **plus** the second path surface: highlight the shortest path **inside** the
  graph view (reusing e-3a's `pathBetween`).
- **Status:** implemented (CI-green; APK spot-check owed). Polish: a persistent `TransformationController`
  (pan/zoom survives rebuilds), a **zoom in/out/fit** control cluster, **graph memoization** by structural
  signature (the loading-spinner `setState` no longer re-runs the force-directed layout), and `Semantics`
  node labels. **Path mode** (confirmed shape): a **"Find path…"** app-bar action → `pickLibraryItem` →
  `connectionPathProvider` → the canvas switches to a highlighted **path graph** (`buildPathGraph`: items +
  connector bridge nodes, `BuchheimWalker` linear layout) with a top banner (source → target) and a
  "Back to neighborhood" toggle; path item nodes stay interactive (tap → open, long-press → re-seed the graph).
  `null` → "No connection found". **No new Cozo script, no schema, no deps.** Tests: `buildPathGraph` shape +
  the zoom/find-path controls, the full pick→path-mode→back flow, and the no-connection case.
- **Exit / review:** polish lands without regressing the P10c-e/f interactions; selecting a second item
  highlights/explains the path. ✓ (CI parts) · APK owed — **P13e feature-complete** (all subphases
  implemented; consolidated on-device APK pass owed).

### `[~]` P13f — Capability-gating + model-selector UX polish & phase close *(split into 3 PRs)*
Exploration found gating already consistent (shared `aiSummaryAction` copy; tier-ineligible features hide; the
d-3 low-tier path is wired). So the remaining work is **model-download/management UX** + a translation surface +
the docs close-out. Split for phone-reviewable PRs.

#### `[~]` P13f-1 — Model download & management UX *(settings UI + service)*
- Make model state legible in the picker: **Active / Downloaded / ~MB** per tile, a **"Delete download"**
  affordance for downloaded-but-inactive models (free space, keep the selection), and an **inline determinate
  download progress** indicator (via the engines' already-exposed `onProgress`) replacing the opaque snackbar.
- **Status:** implemented (CI-green; APK owed). `ModelDownloadService` gains `installedModelIds()` +
  `delete(modelId)` (reuses existing `isInstalled`); new `downloadedModelIdsProvider`; the generation +
  transcription model tiles in `ai_settings_screen.dart` show state + delete + progress. Aligned the one outlier
  gating string (`'Translation isn't available …'`). Embedder (Gecko floor) intentionally excluded from delete.
  Tests: service (`installedModelIds`/`delete`), the settings tile state + delete affordance.
- **Exit / review:** the picker clearly shows what's downloaded/active; delete frees space; progress is visible.

#### `[~]` P13f-2 — Translation settings surface *(native ML Kit)*
- A Settings → AI **Translation card** to manage the on-demand ML Kit language models (list downloaded
  languages + sizes, delete to free space), mirroring the OCR card; Android-only, gated elsewhere.
- **Status:** implemented (CI-green; APK spot-check owed). ML Kit exposes no "list downloaded" call, so the
  `TranslationEngine` seam gained `downloadedLanguageCodes()` (probes ML Kit's supported `TranslateLanguage`
  set concurrently) + `deleteModel(code)`; the `Unavailable` engine returns empty / throws. New
  `downloadedTranslationPacksProvider` (mirrors `downloadedModelIdsProvider`); a pure `kTranslationLanguages`
  list + `translationLanguageName(code)` (fallback: upper-cased code) in `translation.dart`. The
  `_TranslationCard` (after `_OcrCard`, hidden where ML Kit can't run): a header + the downloaded packs
  (name · ~30 MB · Downloaded, each with a "Delete language pack" affordance), an empty-state line, and —
  maintainer call — a **"Download a language"** pre-fetch (searchable picker → ~30 MB Wi-Fi confirm →
  download). **No schema, no deps, no settings field.** Tests: the unavailable engine's new methods, the
  name helper (known + fallback + unique codes), and the card (lists packs + delete affordance, empty state,
  hidden when unavailable). **Pending APK spot-check** (real pack download/delete + pre-download, offline).

#### `[x]` P13f-3 — P13 phase close + phase-close convention *(docs; no code)*
- `docs/VERIFICATION.md`: a **"P13 — consolidated cross-feature on-device pass"** checklist — the one owed
  verification for the whole phase (per-subphase rows a–f already landed in their own PRs).
- **`CLAUDE.md` §7 — encode the phase-close convention** (net-new): the marker legend + the earned-`[x]` rule
  (a subphase earns `[x]` only when its per-PR APK/on-device check is done; **batched** checks keep it `[~]`,
  not `[x]`; a pure-Dart/UI/docs subphase is CI-dischargeable); a **top-level phase is closed** by the single
  consolidated cross-feature on-device pass in `VERIFICATION.md` (the holistic gate).
- **Honest markers (maintainer call):** P13's APK checks were **batched** into the consolidated pass, so the
  affected subphases **stay `[~]`** (CI-complete, not yet verified) — they are **not** flipped to `[x]` on the
  promise of a later check. The consolidated pass, when the maintainer runs it, discharges them all + closes
  P13. P13f-3 (docs/CI) and P13d-1 (pure-Dart, CI-covered) are the CI-dischargeable exceptions → `[x]`; P13d's
  parent header is corrected `[x]`→`[~]` (its children d-2a/d-2b/d-3 are still APK-owed).
- **Status:** implemented (docs-only; CI-green). Landed the consolidated VERIFICATION pass, the CLAUDE.md §7
  convention + legend, the honest marker set, the honest P13 summary block (below), the ROADMAP status line,
  and the one missing f-2 BACKLOG entry. **No code.**
- **Exit / review:** every P13 feature has a clear enabled/gated state and its own VERIFICATION row; the phase
  is **code-complete** with exactly one owed item — the consolidated cross-feature on-device pass (→ P14).

> **P13 — code-complete; on-device verification pending.** All P13 subphases are **implemented, CI-green,
> and merged**: abstractive summarization + auto-summarize (P13a/a-2); OCR + translation + auto-OCR and the
> image-download fix (P13b); smart auto-tagging + auto-tag-on-download (P13c/c-2); the local-GraphRAG
> "Ask your library" multi-turn chat + conversation management + retrieval-only fallback (P13d); advanced
> graph analytics — community auto-albums, centrality "Rediscover", path/bridge + graph-view polish (P13e);
> and model/translation-pack management UX + this close (P13f).
>
> **The one owed item for the whole phase is the consolidated cross-feature on-device pass** in
> `docs/VERIFICATION.md` → "P13 — consolidated cross-feature on-device pass". P13's per-PR APK spot-checks
> were deliberately **batched** into it (CLAUDE.md §6/§7), so each affected subphase stays `[~]`
> (CI-complete, not yet verified). **Running that single pass discharges every owed per-subphase check and
> flips all P13 markers — and the phase — to `[x]`**, closing the v1 AI pillar (next: P14 beta & launch).

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
