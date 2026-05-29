# P12 — Device-tiered edge LLM engine: subphase plan

> The sub-roadmap for **P12** (see `docs/ROADMAP.md` and the lean summary in `docs/design/P-AI-PLAN.md`).
> P12 grows GrabBit's on-device AI from **embeddings-only** (P10) into a **device-tiered LLM engine**:
> text **generation** (`flutter_gemma`), speech **transcription** (whisper.cpp), and a **multilingual
> embedder** — every capability **gated on a measured device tier** and **opt-in**, degrading gracefully
> (never a crash) on hardware that can't run it. Everything stays **on-device = FREE** (CLAUDE.md §1): no
> cloud, no accounts, the only network call is a one-time, integrity-checked model download. P12 is a
> **minimal feature surface** — it ships the *runtimes + gating*, not the user-facing AI features (those
> are **P13**). Deep contracts live in `docs/AI-SPEC.md` §2–§4. Much of P12 is native (`flutter_gemma`
> generation, whisper.cpp, an onnxruntime embedder), so it is verified on-device.

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named `claude/p12<sub>-<topic>`.
  Each keeps CI green (`dart format` · `flutter analyze` · `flutter test`), runs `build_runner` if codegen
  (freezed/json/drift/riverpod) changed, and updates `docs/VERIFICATION.md`.
- **One schema migration:** the only DB change lands once in **P12f** (v9→v10: the empty `things` table).
  Do not bump the schema elsewhere in the phase.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). **P12a, P12b, P12f, P12g**
  are pure-Dart/UI and ship as standalone green-CI PRs; the native subphases — **P12c** (onnxruntime
  embedder), **P12d** (LLM generation), **P12e** (whisper) — need APK spot-checks and are batched.
- **Build on the existing seams**, don't fork them: `InferenceEngine` (`lib/core/ai/inference_engine.dart`),
  the runtime switch in `inference_engine_factory.dart`, the `activeEmbedderModelProvider` selection seam
  (`inference_engine_provider.dart`, the P10g-2 override point), the `flutter_gemma` download-with-progress
  pattern, `UnavailableInferenceEngine`, `model_catalog.dart`/`EmbedderRuntime`, and the
  `semanticSearchEnabled`/first-run opt-in pattern (`lib/features/settings/`).
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Capability-gating, never a crash.** Every P12 capability is gated on the measured device tier; an
  ineligible device sees the feature **disabled with a friendly reason**, and the engine no-ops via
  `UnavailableInferenceEngine` (AI-SPEC §1).
- **Opt-in + on-demand models.** Generation, transcription, and the multilingual embedder are each
  **opt-in** (mirroring `semanticSearchEnabled`); models are **downloaded on demand**, integrity-checked
  (SHA-256), and cached in app-private storage — the install stays lean, no model is bundled.
- **`InferenceEngine` contract reconciliation.** The real interface is embeddings-only and its shape
  differs from AI-SPEC §2's documented signatures. P12d/P12e **evolve the real interface** (add
  `generate`/`transcribe`) and **update AI-SPEC §2** to match — one source of truth.
- **Model licensing (AI-SPEC §4).** Prefer **Apache-2.0/MIT**; the plain generation model (P12d) is
  Apache/MIT (SmolLM-135M / Qwen3-0.6B / Phi-4-Mini). The **FunctionGemma-vs-Qwen3 license fork** for
  function-calling is resolved at **P12f** (the seam can land with a gated/no-op impl if the model pick
  slips); Gemma anything requires vetting its use policy before bundling.
- **whisper package** (`whisper_ggml_plus` vs `whisper_kit`) is decided at **P12e**.
- **Minimal feature surface.** P12 exposes only opt-in toggles, capability state, a basic model selector,
  and self-test tiles. The user-facing AI features (summaries, "Ask your library", auto-tagging, the
  transcription UX) are **P13**. **ML Kit OCR/translate is deferred to P13** (listed there as gated
  features).
- **Things-Engine seams are inert in v1.** P12f shapes them (`generateStructured`, the
  `structured_extraction` matrix row, the empty `things` table) so the v2 Things Engine slots in cheaply;
  no v1 feature calls them (ADR-0001/0002/0003, `docs/things-engine.md`).

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P12a — Device capability, tiers & `ModelCapabilityMatrix` *(mostly pure Dart + thin native probe)*
The gating brain every later subphase plugs into.
- **`DeviceCapabilityService`** → a `DeviceProfile { ramMB, soc, hasNpu, hasGpu, osVersion, freeStorageMB }`
  → a **device tier** (low / mid / high). Thin native probe (RAM/SoC/free-storage) via a small platform
  channel; the scoring logic is pure-Dart + testable.
- **`ModelCapabilityMatrix`** — `feature → eligibleModels[byTier]`, seeded with the existing `embeddings`
  row; later subphases add `generation`, `transcription`, `multilingual-embeddings`, and (P12f)
  `structured_extraction` rows. Drives gating + the model-selector UI (AI-SPEC §2).
- Make `activeEmbedderModelProvider` (`inference_engine_provider.dart`) **tier-aware** — consult the
  matrix instead of always returning `defaultEmbedder` — a real, testable behaviour change now.
- **Exit / review:** tier scoring reflects actual hardware (verified on ≥2 real devices — one low, one
  mid); embedder selection respects the tier; ineligible features report a clear reason.
- **Status:** implemented (CI-green) — Pigeon `DeviceHostApi` (`ActivityManager.MemoryInfo.totalMem` +
  `Build.*`) → `DeviceProfile{ramMb,sdkInt,soc,model}` → RAM-primary `tierFor`; sync `activeDeviceTier`
  notifier; `ModelCapabilityMatrix.embedderFor(tier)` (Gecko at all tiers); `activeEmbedderModel` routed
  through it; debug tier log at launch. **As-built deviations:** `freeStorageMb` deferred to **P12b**
  (where download-gating uses it); `hasNpu/hasGpu` deferred (BACKLOG); the matrix carries only the
  embedder dimension (the `AiFeature` rows land with their subphases — no dead code). **Pending
  on-device spot-check** of the tier probe on two phones.

### `[~]` P12b — Model catalog + download / integrity / caching *(pure Dart; reuses the flutter_gemma pattern)*
Generalize the embedder-only asset plumbing into shared infra.
- Extend `model_catalog.dart` beyond `EmbedderModel` to model **kinds** (embedder / LLM / transcription),
  each carrying id, file URLs, **SHA-256**, approx size, and runtime; grow the `EmbedderRuntime`/runtime
  enum.
- A catalog-driven **`ModelDownloadService`**: on-demand fetch with progress, **SHA-256 integrity check**,
  app-private cache, idempotent re-install — generalizing the `flutter_gemma` builder/progress flow.
- Extend the `inference_engine_factory.dart` switch for the new runtimes (stubbed until P12c–P12e).
- **Exit / review:** a catalog entry downloads, verifies, and caches; a corrupted/!matching-hash file is
  rejected with `InferenceErrorCode.downloadFailed`; re-install is a no-op.
- **Status:** implemented (CI-green) — `ModelFile{url,sha256,sizeBytes,filename}`; generic
  `ModelDownloadService` (`ensureDownloaded(modelId, files)` → streamed download + progress + streamed
  SHA-256 verify + atomic `.part`→rename + idempotent skip + `DiskSpaceService` free-space guard +
  in-flight de-dupe), `dart:io HttpClient` byte source behind an injected `ModelByteSource`;
  `EmbedderRuntime.onnx` + `EmbedderModel.files` + factory stub. Full unit coverage (download/verify/
  cache/reject/idempotent/space-guard/streamed-digest). **As-built (maintainer-confirmed) deferrals:**
  typed `LlmModel`/`TranscriptionModel` classes + `ModelKind` → P12d/e (no dead code); the concrete
  MiniLM catalog entry (real URL/SHA-256/size) → P12c; download **resume/Range** → BACKLOG. **No
  on-device row** — infra not yet called live (first live download is P12c).

### P12c — Multilingual embedder (onnxruntime + MiniLM-L12-v2) *(native — split into 3 PRs)*
The first real model through the new infra — de-risks before the LLM lift. *(Moved from P10g-3.)* Keeps
**`paraphrase-multilingual-MiniLM-L12-v2`** (Apache-2.0, 50-lang, 384-d, ~90 MB); **install-global**
selection; **re-embed on switch** via the existing P10b-2b machinery (fingerprint `…​.embedderModelId` +
`_ensureEmbeddingSchema` re-keys the Cozo HNSW at the new dim + `sha256(modelId+text)` cache); **Gecko
stays the universal fallback**. **Decisions:** tokenizer **hand-rolled** in pure Dart (the `dart_*`
SentencePiece packages don't faithfully tokenize XLM-R); ONNX plugin **`onnxruntime_v2`** (16KB-page +
GPU); split risk-first into:

#### `[~]` P12c-1 — XLM-R Unigram tokenizer *(pure-Dart, CI; no native, no behaviour change)*
- `MultilingualEmbedderTokenizer` (`lib/core/ai/multilingual_tokenizer.dart`): NFKC (verified
  XLM-R-charsmap-equivalent) + whitespace/metaspace + Unigram Viterbi + `<unk>`-merge + `<s>`/`</s>` +
  truncation; loads the model's HF `tokenizer.json`. **Fidelity-gated** by golden vectors (the HF
  `tokenizers` oracle) committed as fixtures — proven HF-byte-exact in CI, offline.
- **Status:** implemented (CI-green). Dep: `unorm_dart` (pure-Dart NFKC). No live consumer until c-2.

#### `[~]` P12c-2 — onnx runtime + `OnnxEmbedderInferenceEngine` *(native; APK)*
- Add `onnxruntime_v2`; MiniLM catalog entry (`model.onnx` + `tokenizer.json` as P12b `ModelFile`s w/
  real URL/SHA-256/size; `runtime: onnx`, `dim 384`, 128-tok window). Engine: download → `createSession`
  → tokenize → run → mean-pool (masked) → L2-normalize → 384-d. Gated behind a **self-test tile** (no
  active-model change). Exit: on-device multilingual embed + sane cross-lingual similarity; 16KB device OK.
- **Status:** implemented (CI-green). `OnnxEmbedderInferenceEngine` (`OrtSession.fromFile`; int64
  `input_ids`/`attention_mask`/`token_type_ids`=zeros, fed adaptively per `session.inputNames`; pools
  `last_hidden_state`); pinned `model_quantized.onnx` (118 MB int8) + the `tokenizer.json` c-1 was tested
  against; `EmbedderModel.maxTokens` (Gecko 256 / MiniLM 128); factory takes `{downloads}`; multilingual
  self-test tile. Pure `meanPool`/`l2Normalize` + catalog + non-Android-fallback unit-tested. **Pending
  on-device APK spot-check** (cross-lingual similarity + 16KB device + int8 quality; fp16 235 MB is the
  fallback if quality is poor).

#### `[ ]` P12c-3 — Selection + re-embed + Gecko fallback + minimal UX *(native; APK)*
- Register MiniLM in the matrix (tier-gated) + persisted install-global override; switch drives re-embed;
  Gecko fallback when onnx unavailable. Exit: non-English search visibly improves; re-embed completes;
  revert works; low-end stays Gecko.

### `[ ]` P12d — Edge LLM generation (`flutter_gemma`) *(native — the big lift; needs an APK build)*
- **Reconcile the contract:** add `generate(...)` to `InferenceEngine` (streaming chunks) and **update
  AI-SPEC §2** to the real signature; implement generation in `FlutterGemmaInferenceEngine` (today
  embedder-only) wrapping MediaPipe LLM Inference / LiteRT-LM.
- **Tier-selected Apache/MIT model** (candidates: SmolLM-135M / Qwen3-0.6B / Phi-4-Mini — confirm best at
  build time per AI-SPEC §4); opt-in + capability-gated; graceful no-op when ineligible.
- **No feature surface** — only a **Labs self-test tile** (prompt → streamed completion) proves it works;
  real generation features are P13.
- **Exit / review:** on a capable device, opt in → download → generate a multi-turn completion **offline**;
  a low-end device shows the capability cleanly gated with a reason.

### `[ ]` P12e — Whisper transcription (whisper.cpp) *(native — needs an APK build)*
- Add the dep (**decide `whisper_ggml_plus` vs `whisper_kit`** here); add `transcribe(...)` to the
  contract (and AI-SPEC §2); a tiered whisper model (tiny → small) selected by the matrix; opt-in +
  gated.
- Output (text + timed cues) feeds the **existing** `MediaMetadata.transcript` / `transcriptCues`
  pipeline — **only when caption sidecars are absent** (complements P10f; whisper is the fallback when a
  source ships no captions).
- **Exit / review:** transcribe a caption-less clip **offline** → transcript + tap-to-seek cues saved to
  the item; a low-end device gates it with a reason; a captioned item still prefers its sidecar.

### `[ ]` P12f — Things-Engine forward seams + empty `things` table *(pure Dart + the one Drift migration)*
Thin, inert scaffolding so the v2 Things Engine slots in cheaply — no v1 behaviour change.
- Add **`generateStructured(toolDefs, prompt)`** to `InferenceEngine` (scaffold/minimal impl gated by the
  new **`structured_extraction`** matrix row); resolve the **function-calling model license fork** here
  (or land the seam with a gated/no-op impl and log the deferred model pick).
- Create the **empty `things` Drift table (DDL only)** — **schemaVersion 9→10**, `id` alignable to
  `media_items.id`, JSON-LD + promoted columns per ADR-0001 — with an upgrade-path migration + schema
  test. **Drift stays canonical.**
- **Exit / review:** a v9 install upgrades to v10 with no data loss (migration test); `generateStructured`
  + the capability row exist but are **unused**; no user-visible change. *(ADR-0001/0002/0003.)*

### `[ ]` P12g — Capability-gating UX, AI settings & phase close *(pure Dart/UI; minimal)*
- AI-settings opt-in tiles for **generation**, **transcription**, and the **multilingual embedder**
  (mirroring the `semanticSearchEnabled` tile), each with an `InfoHint`; a **basic model selector**;
  per-capability **"disabled — <reason>"** state from the matrix; self-test tiles; first-run/Labs surface
  (minimal).
- `docs/VERIFICATION.md` rows for every new opt-in/gated behaviour; flip P12a–P12g + the P12 summary to
  done.
- **Exit / review:** each capability shows enabled/gated state with a reason; opt-ins persist across
  restart; the model selector switches the active model; **P12 complete.**

---

## Deferred (cut from P12 → `docs/BACKLOG.md` or a later phase)
- **ML Kit OCR / translate features** → **P13** (listed there as gated features; P12 wires no OCR/translate).
- **Real AI feature surface** (summaries, "Ask your library" GraphRAG, auto-tagging, transcription UX,
  model tone/style prefs) → **P13**.
- **Cloud inference** — out of scope permanently (the `InferenceEngine` cloud seam is theoretical/unplanned;
  CLAUDE.md §1).
