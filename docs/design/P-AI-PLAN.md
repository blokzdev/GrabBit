# P10, P12–P13 — Edge AI + On-Device Graph: delivery sub-roadmap

Status: Draft v0.1 · Last updated: 2026-05-24

> The **lean** delivery plan (subphases, deliverables, exit criteria) for GrabBit's on-device AI and
> graph pillar. **Deep design lives elsewhere** — this doc references, it does not restate:
> - `docs/GRAPH-SPEC.md` — CozoDB engine, integration, schema, sync, algorithm→feature map.
> - `docs/AI-SPEC.md` — per-capability AI engines, device tiers, runtime/models + licensing, GraphRAG.
>
> Banding context (see `docs/ROADMAP.md`): AI is **core to v1**. v1 ships *after* this work (P14).
> v3/cloud is **dropped** — everything here is on-device and **free forever**.

---

## P10 — Baseline edge AI + Cozo graph/vector foundation  *(device-universal)*

**Goal:** stand up the bundled graph+vector engine and the always-available, no-LLM-required feature
floor. Everything runs on *any* device. Ships as sub-PRs.

- **P10a — Cozo foundation:** `CozoHostApi` Pigeon bridge to `io.github.cozodb:cozo_android:0.7.2`
  (mirrors the youtubedl-android wiring); `GraphStore` interface + Android Cozo impl; SQLite backend
  at `<support>/graph/cozo.db`; the Cozo schema; `GraphStore` conformance tests. *(see GRAPH-SPEC §2,
  §4, §5, §9)*
- **P10b-1 — Graph sync backbone:** `GraphSyncService` projects the canonical Drift library into the
  Cozo graph — deterministic media + entity nodes + edges, idempotent rebuild via `:replace`, a
  debounced Drift-update listener (no repo coupling), startup schema-fingerprint self-heal, and a
  manual "Rebuild graph index" action. Pure-Dart, no new native dep, CI-testable via a fake store.
  *(GRAPH-SPEC §3, §6)*
- **P10b-2 — Embedder + vectors** *(split: the embedder is the heaviest, riskiest piece — a new
  native runtime + a model download)* *(naming note: the `InferenceEngine`/`inferenceEngineFor`/
  `UnavailableInferenceEngine` symbols below were renamed to `EmbedderEngine`/`embedderEngineFor`/
  `UnavailableEmbedderEngine` in P12d — these entries record the original ship)*:
  - **P10b-2a — Embedder foundation + opt-in setup** *(done, #74)*: minimal `InferenceEngine.embed()`
    slice via `flutter_gemma` (Gecko 64, embedder-only, 768-d, ungated ~110 MB — superseded by Gecko 256
    in P10g-1) behind a swappable
    interface; Android impl + graceful `UnavailableInferenceEngine`; **opt-in** model fetch (a
    `semanticSearchEnabled` setting) with progress; a first-run **"Set up AI features (or skip)"**
    screen sequenced after the disclaimer; a "Test embedder" self-test. **No** Cozo vectors yet.
    *(AI-SPEC §3)*
  - **P10b-2b — Vectors + backfill** *(done)*: the HNSW `embedding {id => v:<F32;768>, textHash}`
    relation + `::hnsw` index (created on demand by the sync service, excluded from `graphSchema`);
    `GraphSyncService.backfillEmbeddings()` **caches vectors** (only embeds new/changed items keyed by
    `sha256(modelId+text)`, prunes deleted ids), gated on `ensureReady()`; triggered from the live
    listener, startup, and opt-in; self-test reports the embedding count. `similarTo` + query-time
    vector search stay P10c. *(GRAPH-SPEC §5, §6)*
  - **P10b-3 — Cozo hardening + deterministic quick-wins** *(done)*: close the store on app background
    (lazy reopen); guard the `runScript` JSON decode; track the embedder model/dim in an
    `embedding_meta` sidecar + include the model id in the fingerprint so a model change rebuilds the
    index; Drift↔Cozo count-divergence self-heal; batch embedding (`embedBatch`); and project the
    deterministic **`duplicateOf`** (`contentHash`) + **`coDownloadedWith`** (`createdAt`) edges so
    P10c's near-duplicate feature is a pure query. *(GRAPH-SPEC §3, §6, §8)*
- **P10c — Universal graph features** *(split into per-feature subphases, one PR each):*
  - **P10c-a — Query foundation + semantic search** *(done)*: the read-side spine —
    `GraphQueryService` over `runScript` with pure CozoScript builders in `cozo_query.dart` (the
    `~embedding:idx` vector search), reused by every later subphase — plus **semantic library search**
    (a Text/Smart toggle in the Library search bar, gated on `semanticSearchEnabled && embedder ready`,
    run on submit, ranking the whole library; graceful text-only fallback when AI is off).
  - **P10c-b — Related / "More like this"** *(done)*: `GraphQueryService.relatedTo` blends vector
    similarity (the item's own stored embedding) with deterministic graph neighbours (shared
    uploader/playlist/tag/co-download) via a pure Dart ranker; surfaced as a horizontal "More like
    this" carousel on item detail. Works graph-only without embeddings; excludes exact duplicates.
  - **P10c-c — Entity hubs + tag suggestions** *(split into c-1 / c-2):*
    - **P10c-c-1 — Navigable entity hubs** *(done)*: uploader/playlist/tag/site on item-detail are
      tappable → an `EntityHubScreen` listing that entity's items, reusing `watchFiltered` +
      `MediaGrid` + `GridSortButton` (added a `tag` facet to `LibraryQuery`). Pure Drift, every device,
      no graph dependency.
    - **P10c-c-2 — Graph enrichment** *(done)*: a Cozo tag co-occurrence query
      (`GraphQueryService.coOccurringTags` / `relatedTags`, ranked in `cooccurrence_ranking.dart`)
      powers tappable **tag suggestions** in the metadata editor and a **"Related tags"** strip on each
      entity hub. Pure Datalog, every device; renders nothing when the graph is unavailable.
      (Cross-type related entities — creators/playlists — left as a future enhancement.)
  - **P10c-d — Collections→Albums as the proactive grouping hub** *(reframed: similarity is a
    discovery signal, not cleanup; the Duplicates *screen* stays the exact-hash detail view):*
    - **P10c-d-1 — Duplicates album + bulk cleanup** *(done)*: a distinct, actionable **Duplicates**
      card in Collections→Albums (auto-hidden when clean) with bulk **Clean up** (keep oldest per
      group) + **Review** → the screen; compare detail (date·size + "Keep" badge) on the rows. Pure
      Drift, every device (`dedupe_actions.dart`).
    - **P10c-d-2 — Suggested similarity albums + Save** *(done)*: embedder-gated, query-time vector
      clusters (`GraphQueryService.similarityClusters` → pure `near_duplicate_clustering.dart`)
      surfaced as a **Suggested** album section with one-tap **Save as collection**. Lightweight
      precursor to P13's community-detection auto-albums.
  - **P10c-e — Interactive graph viz: render** *(done)*: `graphview` force-directed render of an item's
    neighborhood (`GraphQueryService.neighborhood`, deterministic edges, no embedder) with pan/zoom +
    a type legend, via item-detail "View in graph".
  - **P10c-f — Interactive graph viz: interaction** *(done)*: tap a media node → its item; tap an
    entity node → expand its media (`entityMedia`, capped via `:limit`); long-press → open hub /
    expand-collapse; edge-type **legend filters**. Pure graph build (expand + filter + dedupe) is
    unit-tested. *(GRAPH-SPEC §7 — graph pillar complete.)*
- **P10d — GrabBit Dashboard** *(capstone that unifies P10c; split into sub-PRs):* a **Dashboard**
  home that becomes the **new default landing (`/`)** and a **5th** nav destination (Library moves to
  `/library`). Visualizes the on-device footprint — storage % by media/file type & platform, library
  stats, recent activity, suggestions, and a graph tile — mostly composing existing providers
  (`sizeByType`/`sizeBySite`/`largestItems`/`recentlyPlayed`/`duplicates`/`suggestedAlbums` + counts)
  with `fl_chart` viz. All on-device, no telemetry.
  - **P10d-1 — Foundation** *(done)*: route/IA change (`/`=Dashboard, `/library`=Library, 5th
    destination), the `dashboard` feature module, the hand-written `dashboardSummaryProvider`, and
    number/text **stat tiles** (library · storage · queue · collections) with honest empty/loading/
    error states. No charts yet.
  - **P10d-2 — Storage & activity visualizations** *(done)*: added `fl_chart`; donut charts for storage
    by type & platform + a library-activity bar chart, with pure unit-tested chart-data mappers.
  - **P10d-3 — Recent / suggestions / graph tiles** *(done)*: "Recently added" + "Recently opened"
    media rows, a suggested-albums list, a duplicates callout, and an "Explore graph" entry card —
    all auto-hiding when empty; the graph card is hidden when the on-device graph is unavailable.
- **P10e — Extractive summaries** *(done)*: zero-dependency pure-Dart **TextRank** floor (`lib/core/text/textrank.dart`)
  over an item's **description**, surfaced as an auto-hiding "Summary" TL;DR on the item-detail screen.
  Runs on any device, no model/network.
- **P10f-1 — Transcript-text capture (pure-Dart)** *(done)*: parse/dedupe the `.vtt/.srt` sidecars
  already on disk (`lib/core/text/transcript_dedup.dart` + `lib/features/library/data/transcript_service.dart`,
  reusing the player's `WebVTTCaptionFile`/`SubRipCaptionFile` parsers — no new dep) into a stored
  `MediaMetadata.transcript` (schema v5). Shown as an auto-hiding "Transcript" section and used as the
  preferred TextRank source (`transcript ?? description`). Built via a manual "Build transcript" action,
  with opt-in Settings toggles for automatic transcription (at download) and lazy backfill (on open).
- **P10f-2 — On-demand caption fetch (native)** *(done)*: a unified **"Get transcript"** action that
  uses local captions first, else fetches them (`skipDownload` → `--skip-download` via Pigeon/Kotlin)
  in a chosen language (curated picker, default = in-app language) into the item's media folder, then
  reuses P10f-1's `extractTranscript`/`updateTranscript`. The fetch runs the engine directly (no queue
  entry). Verified with a debug-APK build. Available-language enumeration deferred (see `BACKLOG.md`).
- **P10f-3 — Auto-download captions setting (pure-Dart)** *(done)*: opt-in setting that grabs captions in
  the in-app language on every download (when no explicit subtitle langs set), feeding auto-transcribe;
  groups the transcript toggles into a dedicated "Transcripts" settings section. Reuses the P8c subtitle
  path (no native change); the in-app default language is `SettingsModel.captionLanguage`.
- **P10f-4 — Timestamped, tap-to-seek transcript** *(done)*: `captionsToTimedTranscript` keeps each
  line's start time; stored as JSON in `MediaMetadata.transcriptCues` (schema v6) via
  `transcript_service.extractTimed`. Item-detail renders a synced scrollable transcript (`_SyncedTranscript`)
  whose lines **seek the player** and highlight/auto-scroll with playback; the player controller is shared
  via a screen-scoped `ValueNotifier`. Groundwork for timestamped GraphRAG citations. Pure-Dart/UI.
- **P10g — Transcript-powered semantic index (multi-engine embedder)** *(complete after g-2)*: include the
  transcript in the embed doc and grow the embedder into a pluggable layer. Sub-PRs:
  - **P10g-1** *(done)*: re-pin `geckoEmbedder` `Gecko_64_quant → Gecko_256_quant` in `model_catalog.dart`
    (768-d unchanged, ~114 MB, 256-token, Apache-2.0/ungated); add a **window-capped** transcript slice to
    `buildEmbeddingDocs` (`embedding_doc.dart`, `_descCap`/`_transcriptCap` — caps are required so the
    appended transcript isn't truncated out of the window); bump `_edgeBuilderVersion`→3
    (`graph_sync_service.dart`) for the one-time re-embed; add an **"Update AI model"** affordance to the
    Settings semantic-search tile (no silent download). Existing runtime; no new model family or hosting.
  - **P10g-2** *(done)*: runtime-agnostic seam — an `EmbedderRuntime` discriminator on `EmbedderModel`, an
    `inferenceEngineFor(model)` factory (`inference_engine_factory.dart`) that routes a model to its runtime
    engine (unsupported runtime/platform → graceful `UnavailableInferenceEngine`, which now carries the
    selected model), and an `activeEmbedderModelProvider` **selection seam** returning `defaultEmbedder`.
    Gecko-only, default unchanged, no consumer changes (all read `engine.model`) — **pure architecture**.
    (Switching models is a model-id change → one re-embed via the existing `_ensureEmbeddingSchema` guard.)
  - *Multilingual embedder → moved to **P12***: the **onnxruntime** + **`paraphrase-multilingual-MiniLM-L12-v2`**
    (Apache-2.0, ungated, 50-lang, 384-d) + on-device tokenizer engine is **install-global, capability+content
    selected** (one shared HNSW index → no per-language mixing) and needs P12's model-download/integrity
    infra, so it lands in P12 as a capability-matrix embedder option (plugged into the g-2 registry seam;
    Gecko stays the fallback). **P10g is complete after g-2.**
  - *Cross-phase*: **P12's device-capability diagnostics + device-tier system**
    (`DeviceCapabilityService`/`ModelCapabilityMatrix`) owns capability-driven behaviour — **window
    selection (256 vs 512), model upgrade/downgrade, automated graceful degradation/disable** (all depend
    on P12's capability probe). Multivector chunking → **P13/GraphRAG**. See `AI-SPEC.md` §3, §5.
- **P10h — Full-text search over transcripts & metadata** *(done)*: SQLite **FTS5** (`media_fts`,
  trigger-synced + backfilled on the v6→v7 migration) over title + description + **transcript**, replacing
  the `LIKE` search in `metadata_repository`, so the library is searchable by spoken content. Adds a
  **Relevance** sort (bm25, auto-selected while searching, overridable) and a **Has-transcript** filter.
- **P10i — Dynamic, type-aware library sort & filter system** *(4 PRs)*: richer, contextual library
  discovery. **P10i-a** — multi-select type filter (+ future formats) + the **type-aware option-narrowing**
  foundation (options adapt to the active type; an inapplicable sort resets to Relevance/Newest and
  inapplicable filters clear). **P10i-b** — duration & upload-date sorts (nulls last). **P10i-c** —
  media-dimension capture: migrate the never-backfilled `width`/`height` columns, capture video dims from
  `.info.json` + image dims by decoding the file (pure-Dart, no native), best-effort on-disk backfill,
  surface resolution. **P10i-d** — duration + downloaded/uploaded date-range filters **and** the
  quality/resolution (HD/4K) filter (backed by P10i-c's dimensions), in a sectioned filter sheet.
  Pure-Dart/UI over `LibraryQuery`/`watchFiltered`.
- **P10j — Settings IA, UX refinement & consistency pass** *(final P10 subphase; 3 PRs — see
  `docs/design/P10j-PLAN.md`)*: information architecture (**Hybrid + search** — a category landing with
  small/stable sections inline and heavy/growth groups, Downloads/Captions/AI, as tap-in sub-screens, plus
  a settings search/quick-jump spanning all) **+ UI/UX refinement**, replacing the long-press `(i)`
  `Tooltip` with a **tappable `InfoHint`** rolled across non-obvious settings with plain-language copy, and
  clarifying the subtitles-vs-transcripts model into one coherent **Captions & transcripts** pipeline
  (UI-only — no change to download behavior). Kept last so it tidies up after the feature subphases.
  Pure-Dart/UI; no schema migration. Sub-PRs:
  - **P10j-a — Foundation:** reusable settings widgets (`SettingsSection`/`SettingsSwitchTile`/
    `SettingsChoiceTile`/`SettingsNavTile`) + a touch-friendly `InfoHint` (modal sheet, replaces the
    long-press tooltip); behavior-preserving.
  - **P10j-b — Captions & transcripts:** merge the subtitle (Downloads) + transcript controls into one
    pipeline section, unify vocabulary, make the hidden auto-caption dependency explicit; 1:1 onto
    existing `SettingsModel` fields, no `download_request_builder` change.
  - **P10j-c — Hybrid IA + search + rollout:** `/settings/downloads` + `/settings/captions` +
    `/settings/ai` sub-screens, a static-indexed settings search/quick-jump, `InfoHint` rollout across
    non-obvious controls, and a **General** section surfacing About/Reset/Clear-cache out of the overflow.

**Exit:** on any device, the Cozo index builds & rebuilds; semantic search + "related" return
sensible results offline; entity hubs and the graph view render; near-dup clusters and tag
suggestions work — all with the small embedder, no LLM.

> **Cross-cutting (P11 Activity Inbox):** AI/graph background activity — model downloads,
> capability-gating "disabled because…" notices, embedding/graph backfills, transcription results —
> surfaces via the on-device **Activity Inbox** (the P11 phase that lands between P10 and the edge-LLM
> work). Producers post through its `NotificationCenter` seam. See `docs/ROADMAP.md` P11.

---

## P12 — Device-tiered edge LLM engine  *(minimal feature surface)*

> **Detailed sub-roadmap: [`docs/design/P12-PLAN.md`](P12-PLAN.md)** (P12a–P12g subphase breakdown +
> phase-level decisions). This section is the lean summary.

**Goal:** enable on-device generation + transcription with graceful capability-gating.

- `DeviceCapabilityService` + device tiers + `ModelCapabilityMatrix`.
- On-demand **model catalog + download + integrity check + caching** (install stays lean).
- Per-capability AI engine impls: **`flutter_gemma`** (`GenerationEngine`; wraps MediaPipe LLM Inference /
  LiteRT-LM) + **whisper.cpp** (transcription; `whisper_ggml_plus` / `whisper_kit`); ML Kit (OCR/translate).
- **Multilingual embedder option** (moved from P10g-3): an **onnxruntime** runtime +
  **`paraphrase-multilingual-MiniLM-L12-v2`** (Apache-2.0, 50-lang, 384-d) + on-device tokenizer, registered
  in `ModelCapabilityMatrix` and plugged into the **P10g-2** registry seam (`inferenceEngineFor` + a new
  `EmbedderRuntime.onnx`). Install-global selection, re-embeds on switch; Gecko stays the universal fallback.
- **Capability-gating**: unsupported features clearly disabled with a friendly reason.
- **Model/licensing**: confirm current best models at phase start; **prefer Apache-2.0/MIT**
  (SmolLM-135M, Qwen3-0.6B, Phi-4-Mini); Gemma usable but **vet its use policy**. *(AI-SPEC §4)*
- **Things-Engine forward seams (inert in v1):** shape the **`generateStructured`** method on the
  generation layer (`GenerationEngine` or a sibling structured seam) + the **`structured_extraction`**
  capability row (AI-SPEC §2–§4), and create the
  **(planned) empty `things` table** (generic JSON-LD store; Drift stays canonical). No v1 feature uses
  them; they exist so the v2 Things Engine slots in cheaply. *(ADR-0001, ADR-0002, ADR-0003;
  `docs/things-engine.md`)*

**Exit:** on a capable device, download a model and generate/transcribe offline; on a low-end device
those are cleanly gated with explanation.

---

## P13 — LLM feature surface & polish (incl. local GraphRAG)

**Goal:** the differentiating payoff, layered on P10 (graph+vector) + P12 (LLM).

- **Transcription, abstractive summarization** (on the P10 TextRank floor), **translation, OCR** —
  all gated.
- **Natural-language "Ask your library" chat as local GraphRAG** — Cozo hybrid retrieval feeds the
  local LLM; fully on-device. *(AI-SPEC §6)* The harness operates over **generic typed nodes** (v1 media
  + entity nodes are one case), so a future typed-Thing corpus needs no harness rework. *(forward seam —
  ADR-0001, ADR-0004)*
- **Advanced graph analytics & viz:** graph-clustered auto-albums (community detection), centrality
  **"Rediscover"**, path/bridge discovery, graph-view polish. *(GRAPH-SPEC §7)*
- **Smart auto-tagging**; **model selector UX**.

**Exit:** ask a natural-language question and get a grounded answer citing library items offline;
auto-albums cluster sensibly; rediscover surfaces central-but-stale items; all gated gracefully on
low-end devices.

---

## Cross-cutting

- **CI unaffected** — Android consumes Cozo as a Maven dep (no NDK/Rust in CI); models download at
  runtime (not bundled). APK/native checks remain the manual `build-apk.yml` + `docs/VERIFICATION.md`.
- **Workflow** (CLAUDE.md §7): one branch per subphase (`claude/p10a-…`), one PR each, CI green +
  VERIFICATION updated. Windows Cozo (C-API/FFI) is deferred to **P15** (GRAPH-SPEC §2.2).
