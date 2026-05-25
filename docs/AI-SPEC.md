# GrabBit — On-Device Edge AI Spec

Status: Draft v0.1 · Last updated: 2026-05-24

> Implementation-level source of truth for GrabBit's **on-device AI**. Captures the engine
> abstraction, device-capability tiering, runtime/model choices + licensing rules, the feature set,
> and the local-GraphRAG design + feasibility evidence — so the research/decision record survives a
> context or session loss. Pairs with `docs/GRAPH-SPEC.md` (the graph+vector store that indexes the
> embeddings produced here and serves GraphRAG retrieval) and is referenced by
> `docs/design/P-AI-PLAN.md` (the delivery sub-roadmap). Lands across **P10–P12**.

---

## 1. Principles

- **On-device = free, forever.** All AI here runs locally; it costs us nothing and is free to the
  user. **No cloud, no account, no credits, no telemetry.** (v3/cloud is dropped — see ROADMAP.)
- **AI is core to v1's vision**, not a v2 add-on: v1 ships *after* the AI work (P10–P12), then
  launches at P13.
- **Graceful capability-gating, never a crash or silent no-op.** Every AI feature is gated on a
  measured device tier; unsupported features are clearly disabled with a friendly reason.
- **Always-available floor.** Where possible a zero-dependency, pure-Dart baseline (e.g. extractive
  TextRank summaries, deterministic + vector graph features) runs on *any* device; heavier
  model-backed tiers layer on top for capable hardware.
- **Swappable.** Everything sits behind the `InferenceEngine` interface (mirrors `DownloadEngine` /
  `GraphStore`). The interface leaves a *theoretical* seam for a future cloud impl, but that is
  **unplanned**.

---

## 2. `InferenceEngine` abstraction & device tiering

`lib/core/ai/` (mirrors `lib/core/engine/` and `lib/core/graph/`):

```dart
abstract interface class InferenceEngine {
  Future<bool> canRun(ModelSpec m, DeviceProfile d);
  Future<List<double>> embed(String text);            // P10 (embeddings)
  Stream<InferenceChunk> generate(InferenceRequest r); // P11+ (LLM)
  Stream<TranscriptChunk> transcribe(AudioRef a);      // P11+ (whisper)
}
```

- **`DeviceCapabilityService`** computes a `DeviceProfile { ramMB, soc, hasNpu, hasGpu, osVersion,
  freeStorageMB }` → a **device tier** (e.g. low / mid / high).
- **`ModelCapabilityMatrix`** maps `feature → eligibleModels[byTier]`, driving capability-gating and
  the model-selector UI. (Context: 2026 flagships handle ~4B params at Q4; tiny 0.5–1B models fit
  broadly — gate accordingly.)
- **Separation from `GraphStore`:** `embed()` *produces* vectors; `GraphStore` *stores/searches*
  them (see `GRAPH-SPEC.md`). Only `GraphSyncService` calls both.

---

## 3. Runtime & embedder

- **LLM runtime: [`flutter_gemma`](https://pub.dev/packages/flutter_gemma)** — a maintained Flutter
  plugin wrapping **MediaPipe LLM Inference / LiteRT-LM** (Google's recommended on-device runtime;
  GPU acceleration, function calling, thinking mode). Runs Gemma 3 270M/1B, **Qwen3-0.6B**,
  Phi-4-Mini, SmolLM-135M, Gemma 3n E2B, etc., and **provides text embeddings and on-device RAG** —
  so one runtime family covers embeddings → generation → RAG.
- **Embedder (P10): `flutter_gemma`'s text-embedding support, loaded embedder-only** — the same
  plugin that backs the P11 LLM, so this tier stays device-universal. **Pinned model (P10b-2a):
  Gecko 64** (`litert-community/Gecko-110m-en` → `Gecko_64_quant.tflite` + `sentencepiece.model`),
  110M params, **768-d** vectors, ~110 MB, **ungated** (no HuggingFace token). Chosen as the smallest
  ungated variant; EmbeddingGemma-300M is more accurate but gated/larger — revisit if quality
  demands. The pinned id + dim live in `lib/core/ai/model_catalog.dart`; P10b-2b keys the Cozo HNSW
  schema + graph fingerprint off them so a model change → re-embed.
  **Avoid** the unmaintained `mediapipe_text` pub plugin (v0.0.1, stale/experimental).
- **Opt-in, never auto (P10b-2a).** A `semanticSearchEnabled` setting gates the embedder; toggling it
  on (in Settings or the first-run screen) downloads the model with progress, off = no model use —
  consistent with the gated yt-dlp auto-update and the no-surprise-data principle. A first-run
  **"Set up AI features (or skip)"** screen (`/ai-setup`), sequenced after the disclaimer, offers the
  opt-in to genuinely new users only (`aiSetupSeen` defaults true on existing installs;
  `acceptDisclaimer()` clears it). On unsupported devices the `UnavailableInferenceEngine` no-ops and
  everything else keeps working — embeddings are an enhancement, not a dependency.
- **Transcription (P12): whisper.cpp** via a maintained Flutter package —
  [`whisper_ggml_plus`](https://pub.dev/packages/whisper_ggml_plus) (cross-platform incl. Windows) or
  [`whisper_kit`](https://pub.dev/packages/whisper_kit) (99 languages, SRT/VTT export).
- **OCR / translation:** ML Kit where it fits.
- **On-demand model download** + integrity check + caching keeps the install lean (models are **not**
  bundled).

---

## 4. Model catalog & licensing rule

**Licensing rule (firm now):** because GrabBit is distributed **off-store**, prefer
**Apache-2.0 / MIT** models for clean redistribution. **Confirm the current best models at P11 start**
(the field moves fast) — the table below is the candidate set as of 2026-05.

| Tier | Candidates | License | Notes |
|---|---|---|---|
| **Light (<0.5–~0.6B)** | **SmolLM-135M**, **Qwen3-0.6B** | **Apache-2.0** | Clean; low-end-device floor. |
| **Mid (~1–3B)** | **Phi-4-Mini** | **MIT** | Clean. |
| **Mid (capable)** | **Gemma 3 1B / 3n E2B** | **Gemma** (custom use-policy) | Usable + strong, **but vet Gemma's use policy before bundling** — it carries prohibited-use terms. |
| **Embedder** | **Gecko 64** (110M, 768-d, ~110 MB, ungated) | (Gemma — verify) | Universal tier; embeddings only. Pinned P10b-2a. |
| **Transcription** | whisper.cpp (tiny→large-v3-turbo) | MIT | Size-gated by tier. |

---

## 5. Feature set by phase

### P10 — baseline (device-universal; no LLM)
- **Embeddings** (Gecko 64, 768-d) → indexed in Cozo HNSW, **cached + incremental** via
  `GraphSyncService.backfillEmbeddings()` (P10b-2b done; see `GRAPH-SPEC.md` §5–§6).
- **Semantic search** (vector) complementing the existing `LIKE` search *(P10c-a, shipped)*.
- **Related / "More like this"** *(P10c-b, shipped)*; **entity hubs** *(P10c-c — navigable hubs in
  c-1, the tag co-occurrence "Related tags" strip in c-2; cross-type creator/playlist ranking
  deferred, see `BACKLOG.md`)*; **tag suggestions** *(P10c-c-2, shipped)*; **proactive grouping** —
  a Duplicates auto-album *(P10c-d-1, shipped)* + Suggested similarity albums *(P10c-d-2, shipped)*; and
  **interactive graph viz** — render *(P10c-e, shipped)* + interaction *(P10c-f, shipped)* — read via
  `GraphQueryService`; graph features detailed in `GRAPH-SPEC.md` §7. **(P10c graph pillar complete.)**
- **Extractive summaries (TextRank)** — zero-dependency, pure-Dart floor over
  descriptions/subtitles/transcripts; the always-available TL;DR.

### P11 — tiered edge-LLM engine (minimal feature surface)
- `DeviceCapabilityService` + tiers + `ModelCapabilityMatrix`; model catalog + download + integrity +
  caching; `flutter_gemma` generation impl; whisper.cpp transcription impl; capability-gating.

### P12 — LLM feature surface & polish
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
   and tested in P10) selects the most relevant items + their graph neighborhood.
2. **Generate** via `InferenceEngine` (`flutter_gemma`): the retrieved context + question feed a
   small local LLM, which answers grounded in (and citing) the user's items.

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
