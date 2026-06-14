# GrabBit — On-Device Edge AI Spec

Status: Draft v0.1 · Last updated: 2026-05-24

> Implementation-level source of truth for GrabBit's **on-device AI**. Captures the engine
> abstraction, device-capability tiering, runtime/model choices + licensing rules, the feature set,
> and the local-GraphRAG design + feasibility evidence — so the research/decision record survives a
> context or session loss. Pairs with `docs/GRAPH-SPEC.md` (the graph+vector store that indexes the
> embeddings produced here and serves GraphRAG retrieval) and is referenced by
> `docs/design/P-AI-PLAN.md` (the delivery sub-roadmap). Lands across **P10, P12–P13**.

---

## 1. Principles

- **On-device = free, forever.** All AI here runs locally; it costs us nothing and is free to the
  user. **No cloud, no account, no credits, no telemetry.** (v3/cloud is dropped — see ROADMAP.)
- **AI is core to the vision**, not a bolt-on: the AI work (P10, P12–P13) lands mid-plan, the Things
  Engine builds on it (P14), and the launch phase (P19) is **last** — we ship the full envisioned scope.
- **Graceful capability-gating, never a crash or silent no-op.** Every AI feature is gated on a
  measured device tier; unsupported features are clearly disabled with a friendly reason.
- **Always-available floor.** Where possible a zero-dependency, pure-Dart baseline (e.g. extractive
  TextRank summaries, deterministic + vector graph features) runs on *any* device; heavier
  model-backed tiers layer on top for capable hardware.
- **Swappable.** Everything sits behind per-capability engine interfaces (`EmbedderEngine`,
  `GenerationEngine`; mirror `DownloadEngine` / `GraphStore`). They leave a *theoretical* seam for a
  future cloud impl, but that is **unplanned**.

---

## 2. On-device inference engines & device tiering

`lib/core/ai/` (mirrors `lib/core/engine/` and `lib/core/graph/`). **As-built reconciliation:** rather than
one mega-interface, each capability has its **own engine** bound to its own model + lifecycle — because the
models differ wildly (a 384-d embedder vs a multi-GB LLM) and a device's *active* embedder may be a runtime
(onnx) that can't generate. Each is capability-gated by the device tier; an ineligible device gets a
graceful `Unavailable…Engine` no-op (§1).

```dart
// Embeddings (P10) — EmbedderEngine (renamed from InferenceEngine in P12d).
abstract interface class EmbedderEngine {
  EmbedderModel get model;
  Future<List<double>> embed(String text);
  Future<List<List<double>>> embedBatch(List<String> texts);
  // + isAvailable / dimension / downloadModel / ensureReady / close
}

// Generation (P12d; separate, streaming).
abstract interface class GenerationEngine {
  GenerationModel get model;
  Stream<String> generate(String prompt, {String? systemPrompt});
  // + isAvailable / downloadModel / ensureReady / close
}

// Later: a TranscriptionEngine (P12e, whisper) and a generateStructured seam
// (P12f forward seam, ADR-0002) follow the same per-capability shape.
```

- **`generateStructured(toolDefs, prompt)`** is a **function-calling / typed-tool-fill** seam: given a
  small set of tool definitions it returns a structured result filling one. **Shaped in P12f** (on
  `GenerationEngine`, with `StructuredToolDef`/`StructuredResult` types) and **inert in v1** — no v1
  feature calls it and no shipped engine implements it (concrete impls throw
  `InferenceErrorCode.unsupported`); it is gated by the `structured_extraction` capability (§3). Shaping
  it on the generation layer now is what lets the **Things Engine** curator's fill step slot in
  without reworking the AI engine contracts. The real impl + the function-calling **model-license fork**
  (FunctionGemma 270M vs Qwen3-0.6B) land with the curator in **P15** *(forward seam — `docs/decisions/0002-narrow-then-fill-curator.md`)*.

- **`DeviceCapabilityService`** computes a `DeviceProfile { ramMB, soc, hasNpu, hasGpu, osVersion,
  freeStorageMB }` → a **device tier** (e.g. low / mid / high). *(P12a ships the RAM-primary subset —
  `ramMb`/`sdkInt`/`soc` via a Pigeon `DeviceHostApi`; `hasNpu`/`hasGpu` are best-effort/deferred — see
  `docs/BACKLOG.md`. Free-storage gating lives in `ModelDownloadService`, which reads live free space via
  `DiskSpaceService` at download time, so `freeStorageMB` on the profile stays unused/deferred.)*
- **Model catalog + `ModelDownloadService` (P12b).** File-based models (onnxruntime, whisper) declare
  their assets as `ModelFile { url, sha256, sizeBytes, filename }`; `ModelDownloadService` fetches each
  with progress, verifies **SHA-256**, and caches it under app-private `<appSupport>/models/<modelId>/`
  (atomic verify-then-rename, idempotent, free-space-guarded). The **flutter_gemma** embedder (Gecko)
  keeps its own plugin-managed download (no app-side `ModelFile`/hash).
- **`ModelCapabilityMatrix`** maps `feature → eligibleModels[byTier]`, driving capability-gating and
  the model-selector UI. (Context: 2026 flagships handle ~4B params at Q4; tiny 0.5–1B models fit
  broadly — gate accordingly.) Feature rows include `embeddings`, `generation`, `transcription`,
  `ocr`/`translation`, plus a **`structured_extraction`** row — the AI-tier-gated capability backing
  `generateStructured`; it is **unused before P14** and exists only so the P14 curator's fill step
  is already gated *(forward seam for the P14 Things Engine — `docs/decisions/0002-narrow-then-fill-curator.md`)*.
- **Separation from `GraphStore`:** `embed()` *produces* vectors; `GraphStore` *stores/searches*
  them (see `GRAPH-SPEC.md`). Only `GraphSyncService` calls both.
- **Engine selection (P10g-2):** `embedderEngineFor(EmbedderModel)` maps a model to its runtime engine
  (routing on `EmbedderModel.runtime`); `activeEmbedderModelProvider` is the single seam choosing *which*
  model — it returns `defaultEmbedder` today and is the override point for `ModelCapabilityMatrix` (P12).

---

## 3. Runtime & embedder

- **LLM runtime: [`flutter_gemma`](https://pub.dev/packages/flutter_gemma)** — a maintained Flutter
  plugin wrapping **MediaPipe LLM Inference / LiteRT-LM** (Google's recommended on-device runtime;
  GPU acceleration, function calling, thinking mode). Runs Gemma 3 270M/1B, **Qwen3-0.6B**,
  Phi-4-Mini, SmolLM-135M, Gemma 3n E2B, etc., and **provides text embeddings and on-device RAG** —
  so one runtime family covers embeddings → generation → RAG.
- **Embedder (P10): `flutter_gemma`'s text-embedding support, loaded embedder-only** — the same
  plugin that backs the P12 LLM, so this tier stays device-universal. **Pinned model (P10g-1):
  Gecko 256** (`litert-community/Gecko-110m-en` → `Gecko_256_quant.tflite` + `sentencepiece.model`),
  110M params, **768-d** vectors, **256-token** window, ~114 MB, **Apache-2.0 + ungated** (no
  HuggingFace token). P10g-1 moved up from the seq64 export so the embed doc can carry a real
  **transcript** slice; the seq512/1024 variants share the tokenizer + dimension. The pinned id + dim
  live in `lib/core/ai/model_catalog.dart`; P10b-2b keys the Cozo HNSW schema + graph fingerprint off
  them so a model change → re-embed. **P10g-2** made selection pluggable: an `EmbedderRuntime` discriminator
  + an `embedderEngineFor(model)` factory (routes a model to its runtime engine; unsupported →
  `UnavailableEmbedderEngine`) + an `activeEmbedderModelProvider` seam (returns `defaultEmbedder`; the P12
  override point). A **multilingual** second engine (`paraphrase-multilingual-MiniLM-L12-v2`, Apache-2.0,
  onnxruntime — **P12**, as a capability-matrix embedder option) plugs into that factory, with Gecko as the
  universal fallback. P12c-3 makes it **user-selectable** (a persisted `selectedEmbedderModelId` override,
  gated to mid/high-tier Android via `eligibleEmbedders`; opt-in, default stays Gecko); selecting it
  re-embeds the library, and an unknown/ineligible id or non-Android host **falls back to Gecko** so search
  never breaks. Its **XLM-RoBERTa SentencePiece (Unigram) tokenizer is hand-rolled in pure Dart**
  (`MultilingualEmbedderTokenizer`, P12c-1) — NFKC (verified equivalent to XLM-R's `Precompiled` charsmap)
  + metaspace + Unigram Viterbi, loaded from the model's HF `tokenizer.json` and **golden-fixture-tested
  to reproduce HuggingFace ids exactly** (the `dart_*` SentencePiece packages don't handle XLM-R faithfully). **Known limitation (until P12):** the active model is `Gecko-110m-**en**` (English) —
  non-English transcripts/content still embed (degraded vector, never a crash), so semantic search /
  "related" quality on non-English material is reduced until the multilingual engine lands. **Capability-driven behaviour — window
  selection (256 vs 512), model upgrade/downgrade, automated graceful degradation/disable — is owned by the
  P12 device-capability/tier system** (`DeviceCapabilityService`/`ModelCapabilityMatrix`, §2), which the
  probe it builds makes possible. *(EmbeddingGemma-300M was evaluated and **dropped**: HF-license-gated —
  off the Apache-2.0/MIT preference — and unnecessary once Gecko's ungated longer-context exports were
  found.)* **Avoid** the unmaintained `mediapipe_text` pub plugin (v0.0.1, stale/experimental).
- **Opt-in, never auto (P10b-2a).** A `semanticSearchEnabled` setting gates the embedder; toggling it
  on (in Settings or the first-run screen) downloads the model with progress, off = no model use —
  consistent with the gated yt-dlp auto-update and the no-surprise-data principle. A first-run
  **"Set up AI features (or skip)"** screen (`/ai-setup`), sequenced after the disclaimer, offers the
  opt-in to genuinely new users only (`aiSetupSeen` defaults true on existing installs;
  `acceptDisclaimer()` clears it). On unsupported devices the `UnavailableEmbedderEngine` no-ops and
  everything else keeps working — embeddings are an enhancement, not a dependency.
- **Transcription (engine P12e; richer UX P13): whisper.cpp** via
  [`whisper_ggml_plus`](https://pub.dev/packages/whisper_ggml_plus) (chosen at P12e — FFI to
  whisper.cpp, MIT, cross-platform incl. Windows; accepts a `modelPath` so models are app-managed via
  `ModelDownloadService`, and emits `fromTs/toTs/text` segments mapped to `TranscriptCue`), over
  [`whisper_kit`](https://pub.dev/packages/whisper_kit) (Android-only, younger). Multilingual ggml
  ladder tier-gated (tiny→large-v3-turbo q5_0). Output feeds the existing P10f transcript pipeline as
  the **fallback when a source ships no caption sidecars**.
- **OCR / translation:** ML Kit where it fits.
- **On-demand model download** + integrity check + caching keeps the install lean (models are **not**
  bundled).

---

## 4. Model catalog & licensing rule

**Licensing rule (firm now):** because GrabBit is distributed **off-store**, prefer
**Apache-2.0 / MIT** models for clean redistribution. **Confirm the current best models at P12 start**
(the field moves fast) — the table below is the candidate set as of 2026-05.

| Tier | Candidates | License | Notes |
|---|---|---|---|
| **Light (<0.5–~0.6B)** | **SmolLM-135M**, **Qwen3-0.6B** | **Apache-2.0** | Clean; low-end-device floor. |
| **Mid (~1–3B)** | **Phi-4-Mini** | **MIT** | Clean. |
| **Mid (capable)** | **Gemma 3 1B / 3n E2B** | **Gemma** (custom use-policy) | Usable + strong, **but vet Gemma's use policy before bundling** — it carries prohibited-use terms. |
| **Embedder** | **Gecko 256** (110M, 768-d, 256-tok, ~114 MB) · multilingual: **MiniLM-L12-v2** (P12c-2: onnxruntime, int8 ~118 MB, 384-d, 128-tok) | **Apache-2.0**, ungated | Universal tier; embeddings only. Pinned P10g-1; pluggable P10g-2; MiniLM shipped P12c-2 (self-test-gated until P12c-3). |
| **Generation (P12d)** — user-choosable, tier-eligible ladder | small **SmolLM2-135M** (143 MB) · balanced **Qwen3-0.6B** *(recommended)* (614 MB) · large **Qwen2.5-1.5B** q8 (1.6 GB) · flagship **Gemma-4 E2B** (2.59 GB) | **Apache-2.0**, ungated | All real `litert-community` `.litertlm` files via flutter_gemma (plugin-managed, no app-side hash; pre-download free-storage guard). low=[] (gated); mid=[small, balanced]; high=[balanced, large, flagship]. **Flagship = Gemma-4 E2B** (Gemma 4 is **Apache-2.0 + ungated**, *unlike* the gated Gemma-3 license; Qwen3-4B has no LiteRT build). **No Gemma-3** (custom use-policy/token-gated) and **no Gemini Nano** (AICore-managed, non-redistributable — unusable for a sideloaded app). |
| **Transcription** | whisper.cpp (tiny→large-v3-turbo) | MIT | Size-gated by tier. |
| **Function-calling** (`structured_extraction`) | **Qwen3-0.6B** · **FunctionGemma 270M** | **Apache-2.0** · **Gemma** (custom) | Backs `generateStructured` (§2). Qwen3-0.6B is clean; FunctionGemma carries Gemma's use-policy. **License fork deferred to P12 start** (architecture locked, model not). *(forward seam — ADR-0002.)* |

---

## 5. Feature set by phase

### P10 — baseline (device-universal; no LLM)
- **Embeddings** (Gecko 256, 768-d) → indexed in Cozo HNSW, **cached + incremental** via
  `GraphSyncService.backfillEmbeddings()` (P10b-2b done; see `GRAPH-SPEC.md` §5–§6). **P10g-1** moved the
  embedder up to the 256-token Gecko export and added a window-capped **transcript** slice to the embed doc
  (title/uploader/playlist/tags/description/transcript) so semantic search/related run on spoken content.
  Full long-transcript **multivector chunking** for passage retrieval is deferred to **P13/GraphRAG**.
- **Semantic search** (vector) complementing the existing `LIKE` search *(P10c-a, shipped)*.
- **Related / "More like this"** *(P10c-b, shipped)*; **entity hubs** *(P10c-c — navigable hubs in
  c-1, the tag co-occurrence "Related tags" strip in c-2; cross-type creator/playlist ranking
  deferred, see `BACKLOG.md`)*; **tag suggestions** *(P10c-c-2, shipped)*; **proactive grouping** —
  a Duplicates auto-album *(P10c-d-1, shipped)* + Suggested similarity albums *(P10c-d-2, shipped)*; and
  **interactive graph viz** — render *(P10c-e, shipped)* + interaction *(P10c-f, shipped)* — read via
  `GraphQueryService`; graph features detailed in `GRAPH-SPEC.md` §7. **(P10c graph pillar complete.)**
- **Extractive summaries (TextRank)** — zero-dependency, pure-Dart floor; the always-available TL;DR.
  *(P10e shipped)* v1 input was the item **description**; *(P10f-1 shipped)* a de-duplicated
  **transcript** parsed from caption sidecars (`MediaMetadata.transcript`) is now the preferred source
  (`transcript ?? description`) and also feeds the semantic index (**P10g**), full-text search
  (**P10h**, FTS5), and future GraphRAG retrieval.

### P12 — tiered edge-LLM engine (minimal feature surface)
- `DeviceCapabilityService` + tiers + `ModelCapabilityMatrix`; model catalog + download + integrity +
  caching; `flutter_gemma` generation impl; whisper.cpp transcription impl; capability-gating.
- **`structured_extraction`** capability + the `generateStructured` seam (§2) are **shaped here** —
  defined, gated, but driven by no feature before P14 *(forward seam for the P14 Things Engine — ADR-0002)*.

### P13 — LLM feature surface & polish
- **Transcription**, **abstractive summarization** (layered on the P10 TextRank floor),
  **translation**, **OCR** — all capability-gated.
- **Natural-language "Ask your library" chat as local GraphRAG** (§6).
- **Smart auto-tagging** feeding existing tags/facets; **model selector UX**.
- **Advanced graph analytics & viz** (clustered auto-albums, centrality "Rediscover", path/bridge) —
  see `GRAPH-SPEC.md` §7.

---

## 6. Local GraphRAG — "Ask your library"

Fully on-device natural-language Q&A over the private library:

1. **Retrieve** via `GraphStore` (`GRAPH-SPEC.md`): hybrid **vector search + graph re-rank** (built
   and tested in P10) selects the most relevant nodes + their graph neighborhood.
2. **Generate** via `GenerationEngine` (`flutter_gemma`): the retrieved context + question feed a
   small local LLM, which answers grounded in (and citing) the user's nodes.

The harness operates over **generic typed nodes**, not a media-only collection: the v1 graph's media +
entity nodes (uploader/playlist/tag/site) are one case, and a future typed-**Thing** corpus is the
general case — so the retrieval/generation loop needs no rework when richer types arrive *(forward seam
for the P14 Things Engine — `docs/decisions/0001-schema-as-data-not-schema-as-code.md`,
`docs/decisions/0004-relationships-provenance-and-the-authored-edge-moat.md`)*.

> **Thing-level embedding index — deferred to a dedicated phase (P15/P16).** P14e makes retrieval *hydration*
> Thing-aware but **reuses the media-keyed vectors** (a MediaObject's `id == media_items.id`). **Non-MediaObject**
> Things — AI-extracted (P15) or deterministically imported (P16: `Recipe`/`Event`/`Place`/…) — own no media
> vector, so they aren't recalled by "Ask" until they have their own embeddings. A future phase adds a
> `thing_embedding` relation keyed by `things.id` (built from the Thing's JSON-LD text); its hits flow through
> P14e's `hydrateNodes` seam (recall vs. resolve/cite), converging toward keying embeddings on `things.id`
> uniformly. See `docs/BACKLOG.md`.

**Feasibility (affirmed):** Google AI Edge ships on-device RAG + function-calling libraries for SLMs
(Gemma 3n); `flutter_gemma` has built-in on-device RAG; the **MobileRAG** approach runs a ~33M
embedder + Qwen2.5-0.5B generation on phones. **RAM-gated** (the HNSW index lives in RAM; our
libraries are modest) — capable devices get full generation; lighter devices fall back to retrieval +
extractive answers.

---

## 7. Privacy

All inference, embeddings, transcripts, and the graph index stay **on-device**. No network calls for
AI (only the one-time model download from a trusted host, integrity-checked). No telemetry, no
analytics — consistent with CLAUDE.md §9 and PRD.

## 8. Error taxonomy (additions to `docs/SPEC.md` §6)

`modelDownloadFailed`, `modelIntegrityFailed`, `modelUnsupportedOnDevice` (gating, not an error to
the user — disable with reason), `inferenceFailed`, `transcriptionFailed`, `indexUnavailable`. Map
each to a friendly message; never crash; gate rather than fail where the device can't run a model.
