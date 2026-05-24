# P10–P12 — Edge AI + On-Device Graph: delivery sub-roadmap

Status: Draft v0.1 · Last updated: 2026-05-24

> The **lean** delivery plan (subphases, deliverables, exit criteria) for GrabBit's on-device AI and
> graph pillar. **Deep design lives elsewhere** — this doc references, it does not restate:
> - `docs/GRAPH-SPEC.md` — CozoDB engine, integration, schema, sync, algorithm→feature map.
> - `docs/AI-SPEC.md` — `InferenceEngine`, device tiers, runtime/models + licensing, GraphRAG.
>
> Banding context (see `docs/ROADMAP.md`): AI is **core to v1**. v1 ships *after* this work (P13).
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
- **P10b-2 — Embedder + vectors:** minimal `InferenceEngine.embed()` slice via `flutter_gemma`
  (Gecko, embedder-only) + on-demand embedder-model fetch; the HNSW `embedding` relation; `similarTo`
  edges; embedding **backfill that caches vectors** (only embeds new/changed items). *(AI-SPEC §3;
  GRAPH-SPEC §5)*
- **P10c — Universal graph features:** semantic search; **Related / "More like this"** (hybrid
  vector + graph re-rank); **entity hubs** (uploader/playlist/tag/site); **near-duplicate clusters**;
  **tag suggestions**; **interactive graph viz** (candidate `graphview`). *(GRAPH-SPEC §7)*
- **P10d — Extractive summaries:** zero-dependency pure-Dart **TextRank** floor over
  descriptions/subtitles/transcripts.

**Exit:** on any device, the Cozo index builds & rebuilds; semantic search + "related" return
sensible results offline; entity hubs and the graph view render; near-dup clusters and tag
suggestions work — all with the small embedder, no LLM.

---

## P11 — Device-tiered edge LLM engine  *(minimal feature surface)*

**Goal:** enable on-device generation + transcription with graceful capability-gating.

- `DeviceCapabilityService` + device tiers + `ModelCapabilityMatrix`.
- On-demand **model catalog + download + integrity check + caching** (install stays lean).
- `InferenceEngine` impls: **`flutter_gemma`** (generation; wraps MediaPipe LLM Inference / LiteRT-LM)
  + **whisper.cpp** (`whisper_ggml_plus` / `whisper_kit`); ML Kit (OCR/translate) where it fits.
- **Capability-gating**: unsupported features clearly disabled with a friendly reason.
- **Model/licensing**: confirm current best models at phase start; **prefer Apache-2.0/MIT**
  (SmolLM-135M, Qwen3-0.6B, Phi-4-Mini); Gemma usable but **vet its use policy**. *(AI-SPEC §4)*

**Exit:** on a capable device, download a model and generate/transcribe offline; on a low-end device
those are cleanly gated with explanation.

---

## P12 — LLM feature surface & polish (incl. local GraphRAG)

**Goal:** the differentiating payoff, layered on P10 (graph+vector) + P11 (LLM).

- **Transcription, abstractive summarization** (on the P10 TextRank floor), **translation, OCR** —
  all gated.
- **Natural-language "Ask your library" chat as local GraphRAG** — Cozo hybrid retrieval feeds the
  local LLM; fully on-device. *(AI-SPEC §6)*
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
  VERIFICATION updated. Windows Cozo (C-API/FFI) is deferred to **P14** (GRAPH-SPEC §2.2).
