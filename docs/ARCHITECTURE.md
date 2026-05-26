# GrabBit — Architecture Blueprint

Status: Draft v0.2 · Last updated: 2026-05-24

This document is the system-design source of truth. It explains *how* GrabBit is
structured so any agent can implement a feature without re-deriving the design.

---

## 1. High-Level Architecture

```
┌──────────────────────────────────────────────────────────────┐
│ Presentation (Flutter / Material 3)                            │
│  features/{downloader,library,queue,settings,ai}               │
│  Riverpod providers ── go_router navigation                    │
├──────────────────────────────────────────────────────────────┤
│ Domain (pure Dart)                                             │
│  entities · repository interfaces · use cases                  │
│  DownloadEngine · GraphStore (P10) · InferenceEngine (P12)     │
├──────────────────────────────────────────────────────────────┤
│ Data                                                           │
│  Drift (SQLite) repos [canonical] · file storage · settings    │
│  engine impls · GraphSyncService (Drift→Cozo derived index)    │
├──────────────────────────────────────────────────────────────┤
│ Platform / Native                                              │
│  Android: Kotlin host → Pigeon → youtubedl-android (Py+yt-dlp+ffmpeg)
│           + CozoDB (cozo_android AAR) · foreground svc · MediaStore
│           flutter_gemma (MediaPipe/LiteRT-LM) · whisper.cpp · ML Kit (P12)
│  Windows: Dart Process → yt-dlp.exe/ffmpeg.exe · Cozo via dart:ffi (P15)
└──────────────────────────────────────────────────────────────┘
(Former "Cloud (v3)" layer — Supabase/Gemini/Stripe — is DROPPED; see §9.)
```

**Layering rules:** Presentation → Domain → Data → Platform. Domain has zero
Flutter/plugin imports. Dependencies point inward; outer layers implement inner
interfaces. Everything platform-specific hides behind a domain interface.

---

## 2. Download Engine Abstraction

Single Dart interface, multiple platform implementations, chosen at runtime.

```dart
abstract interface class DownloadEngine {
  Future<MediaInfo> probe(String url);                 // formats, metadata, thumbnails
  Stream<DownloadProgress> download(DownloadRequest r); // emits progress, terminal event
  Future<void> cancel(String taskId);
  Future<EngineVersion> version();                      // yt-dlp/ffmpeg versions
  Future<void> update();                                // user-triggered yt-dlp self-update
}
```

- **AndroidYtDlpEngine** → Pigeon `@HostApi` → Kotlin → `youtubedl-android`
  (yausername), which bundles Python + yt-dlp + ffmpeg as Android-native
  libraries. Progress streamed back via Pigeon `@FlutterApi` callbacks or an
  EventChannel.
- **WindowsProcessEngine** → `Process.start('yt-dlp.exe', args)`, parse
  `--newline --progress-template` stdout into `DownloadProgress`; call
  `ffmpeg.exe` for merge/convert. Binaries shipped in the app's install dir.

A Riverpod `downloadEngineProvider` returns the correct impl per `Platform`. The
queue, downloader UI, and library never reference a concrete engine.

**Why not server-side / pure-Dart:** server-side breaks privacy + adds cost/legal
exposure; pure-Dart (youtube_explode) is YouTube-only and fragile. On-device
native is private, free to run, and broad. (See PRD §9.)

---

## 3. State & Navigation

- **Riverpod** providers per feature: `downloaderControllerProvider`,
  `libraryProvider`, `queueProvider`, `settingsProvider`. Async state via
  `AsyncNotifier`; long operations stream from the engine.
- **go_router** routes: `/` (library) · `/add` (paste/probe) · `/queue` ·
  `/item/:id` (detail+player) · `/settings` · (P10+) `/ai`, `/graph`.
- App-lock gate is a router redirect: unauthenticated → `/lock`.

---

## 4. Local Data Model (Drift / SQLite)

Tables (full schema in `docs/SPEC.md`):
- **media_items** — id, title, source_url, site, file_path, type
  (video/audio/image), duration, size, width/height, thumb_path, created_at,
  storage_state (private | exported), notes.
- **metadata** — item_id FK, key/value or typed columns (uploader, upload_date,
  description, original_url), tags (join table).
- **tags** + **media_tags** — many-to-many.
- **collections** + **media_collections** — user grouping.
- **download_tasks** — id, url, request_json, status (queued|running|paused|
  done|error|canceled), progress, error_code, retries, created_at.
- **settings** — single-row or key/value (mode, quality defaults, storage policy,
  destination folder, naming template, theme, locale, lock config).
- **notifications** (P11) — id, created_at, category (download|transcript|ai|graph|
  system|reminder), severity (info|success|warning|error), title, body, optional
  deep-link (target_route/item_id/task_id), read_at, dedupe_key, expires_at. Backs the
  Activity Inbox.

Migrations: Drift schema versioning; never destructive without migration.

**Drift is canonical; the graph/vector index is derived.** From P10, a bundled **CozoDB** engine
holds a **derived, rebuildable** graph (nodes/edges) + HNSW embedding index keyed by
`media_items.id`. No user-visible mutation lands in Cozo only — repositories write Drift first, then
`GraphSyncService` projects into Cozo (incrementally + on-demand rebuild). A corrupt/stale index is
never data loss — delete and rebuild. Full design: `docs/GRAPH-SPEC.md`.

**Activity Inbox (P11).** A single, on-device notification store: features post through one
`NotificationCenter.post(...)` write seam into the **canonical** `notifications` Drift table; the
`/inbox` UI + app-bar unread badge watch it via Riverpod. The existing **OS/foreground notifications**
are a complementary *presentation* channel (while backgrounded), not a second source of truth. Old
entries are swept **lazily** on app/inbox open per a configurable retention setting (no background
scheduler). Entirely on-device; no telemetry/push/cloud.

---

## 5. Storage & File Lifecycle

- **Private working dir (default):** app-specific storage
  (`getApplicationSupportDirectory` / app-specific external files on Android) — not
  indexed by the gallery. This is the "private media manager" space.
- **Export to device:** copy/move into shared **MediaStore**
  (Downloads/Movies/Pictures) via scoped storage on Android; into a user-chosen
  directory on Windows. `storage_state` tracks private vs exported.
- **Auto-store:** if enabled, completed downloads are also written to the chosen
  destination folder automatically.
- Naming via user template; collision-safe. Thumbnails cached alongside.

---

## 6. Background Downloads

- Android **foreground service** with an ongoing notification (progress, pause/
  cancel actions) for OS compliance on long downloads.
- **Persistent queue** in `download_tasks`; survives process death and resumes.
- Concurrency limit (configurable); retry with backoff on transient errors.
- Engine emits progress → queue updates DB → UI observes via Riverpod stream.
- Wi-Fi-only option gates task start.

---

## 7. Security & Privacy

- **App lock:** `local_auth` (biometric) + PIN; PIN stored only as a salted hash in
  `flutter_secure_storage`. Router redirect enforces lock on resume.
- **Permissions:** least-privilege; request notification + foreground-service;
  storage access only when exporting (scoped storage, no broad MANAGE_EXTERNAL).
- **No telemetry, ever.** No secrets in client — there is **no backend/cloud** (v3 dropped); the
  only network calls are downloads and a one-time, integrity-checked model download (P12).

---

## 8. On-Device AI + Graph Architecture (v1, P10, P12–P13)

Two pure-Dart seams mirror the `DownloadEngine` pattern; deep design in `docs/AI-SPEC.md` and
`docs/GRAPH-SPEC.md`.

- **`GraphStore`** (`core/graph/`, P10) — the on-device relationship graph + vector index, backed by
  **CozoDB** (Android `cozo_android` AAR via a `CozoHostApi` Pigeon bridge; Windows via `dart:ffi` in
  P15). Platform-branched provider, like `downloadEngineProvider`.
- **`InferenceEngine`** (`core/ai/`, P12) — local AI runtime via **`flutter_gemma`** (embeddings +
  generation + RAG; MediaPipe/LiteRT-LM), **whisper.cpp**, **ML Kit**.
- **`GraphQueryService`** (`core/graph/`, P10c) — read-side orchestration over `GraphStore.runScript`
  (vector nearest-neighbour, deterministic neighbour traversals, tag co-occurrence), mirroring how
  `GraphSyncService` owns write/sync — so the store stays a thin `runScript` bridge. Pure CozoScript
  builders live in `cozo_query.dart`; ranking in `related_ranking.dart` / `cooccurrence_ranking.dart`.
  UI reads it via providers, never CozoScript.
- `embed()` *produces* vectors; `GraphStore` *stores/searches* them; only `GraphSyncService` bridges
  both. This lets the deterministic + similarity graph (P10) ship independent of the LLM stack (P12).

The `InferenceEngine` contract:

```dart
abstract interface class InferenceEngine {
  Future<bool> canRun(ModelSpec m, DeviceProfile d);
  Stream<InferenceChunk> run(InferenceRequest r);
}
```

- **DeviceCapabilityService** computes a `DeviceProfile` (RAM, SoC/NPU/GPU, OS
  version, free storage) → maps to a **device tier**.
- **ModelCapabilityMatrix** maps `feature → eligibleLocalModels[byTier]`. Drives capability-gating
  and the **model selector** UI; unsupported features are clearly disabled with a friendly reason.
- **`flutter_gemma`** (MediaPipe LLM Inference / **LiteRT-LM**) is the primary local runtime for
  embeddings + generation + on-device RAG; **whisper.cpp** backs transcription, **ML Kit** OCR/
  translate. Models are **downloaded on demand**, cached, and integrity-checked.
- All inference is **on-device and free**, no account, no network (beyond the one-time model
  download). Prefer Apache-2.0/MIT models; vet Gemma's use policy (`docs/AI-SPEC.md` §4).

---

## 9. Cloud Backend — DROPPED (historical)

The former v3 cloud band (Supabase Auth + Postgres credit ledger + Edge Functions → Genkit/Gemini,
with Stripe/PayPal webhooks) is **removed**. GrabBit is **free forever and fully offline**,
donation-supported. The `InferenceEngine` interface still leaves a *theoretical* seam where a cloud
implementation could one day slot behind the same contract (optionally letting incapable devices
fall back), but it is **not a planned phase** and nothing in the app depends on it.

---

## 10. Cross-Platform Strategy

- Shared: all Dart (domain, data, presentation, Drift, Riverpod).
- Divergent: only the engine impl (Pigeon/native vs Process) and storage adapter
  (MediaStore vs filesystem) and packaging.
- Windows arrives in Roadmap **P15** by adding `WindowsProcessEngine` + a desktop storage adapter +
  the Cozo `dart:ffi` `GraphStore` impl + MSIX packaging — no domain/UI rewrite.

---

## 11. Testing Strategy

- **Unit:** domain use cases, queue logic, progress parsing, naming templates.
- **Widget:** key flows (paste→probe→download, library, settings, lock).
- **Engine:** mock `DownloadEngine` for deterministic tests; thin native glue
  tested via on-device APK smoke checks (manual, batched).
- CI runs format/analyze/test on every PR (see CLAUDE.md §6).
