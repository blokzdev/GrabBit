# GrabBit — Architecture Blueprint

Status: Draft v0.1 · Last updated: 2026-05-20

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
│  DownloadEngine (iface) · InferenceEngine (iface, v2)          │
├──────────────────────────────────────────────────────────────┤
│ Data                                                           │
│  Drift (SQLite) repos · file storage svc · settings store      │
│  engine impls · (v3) Supabase client                           │
├──────────────────────────────────────────────────────────────┤
│ Platform / Native                                              │
│  Android: Kotlin host → Pigeon → youtubedl-android (Py+yt-dlp+ffmpeg)
│           foreground service · MediaStore · LiteRT (v2)        │
│  Windows: Dart Process → yt-dlp.exe / ffmpeg.exe (bundled)     │
├──────────────────────────────────────────────────────────────┤
│ Cloud (v3 only)                                                │
│  Supabase: Auth · Postgres (credit ledger) · Edge Functions    │
│           → Genkit flows → Gemini · Stripe/PayPal webhooks     │
└──────────────────────────────────────────────────────────────┘
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
  `/item/:id` (detail+player) · `/settings` · (v2) `/ai`.
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

Migrations: Drift schema versioning; never destructive without migration.

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
- **No telemetry** in v1/v2. No secrets in client. (v3) all paid-API keys live in
  Supabase secrets, never shipped.

---

## 8. On-Device AI Architecture (v2)

Mirrors the engine pattern with an `InferenceEngine` abstraction.

```dart
abstract interface class InferenceEngine {
  Future<bool> canRun(ModelSpec m, DeviceProfile d);
  Stream<InferenceChunk> run(InferenceRequest r);
}
```

- **DeviceCapabilityService** computes a `DeviceProfile` (RAM, SoC/NPU/GPU, OS
  version, free storage) → maps to a **device tier**.
- **ModelCapabilityMatrix** maps `feature → {localModels eligible by tier,
  cloudModels}`. Drives the **model selector** UI: shows "Free — Local" when
  eligible, "Cloud (credits)" otherwise/optionally.
- **LiteRT** is the primary local runtime (incl. MediaPipe LLM Inference for
  Gemma-class models); whisper.cpp / ONNX may back specific tasks behind the same
  interface. Models are **downloaded on demand**, cached, and verified.
- Local inference = free (no account). Cloud inference (v3) routes through Supabase.

---

## 9. Cloud Backend (v3)

```
App → Supabase Edge Function (auth-checked, rate-limited)
        → check credit balance (Postgres ledger)
        → Genkit flow → Gemini API
        → debit credits, return result
Stripe/PayPal → webhook → Edge Function → credit grant (ledger insert)
```

- **Auth:** Supabase Auth; account required only for cloud AI.
- **Credit ledger:** append-only transactions table; balance = sum; debits are
  transactional with the AI call.
- **Secrets:** Gemini + payment keys in Supabase secrets. Client never sees them.
- **RLS:** row-level security so users only see their own ledger/usage.

---

## 10. Cross-Platform Strategy

- Shared: all Dart (domain, data, presentation, Drift, Riverpod).
- Divergent: only the engine impl (Pigeon/native vs Process) and storage adapter
  (MediaStore vs filesystem) and packaging.
- Windows arrives in Roadmap P6 by adding `WindowsProcessEngine` + a desktop
  storage adapter + MSIX packaging — no domain/UI rewrite.

---

## 11. Testing Strategy

- **Unit:** domain use cases, queue logic, progress parsing, naming templates.
- **Widget:** key flows (paste→probe→download, library, settings, lock).
- **Engine:** mock `DownloadEngine` for deterministic tests; thin native glue
  tested via on-device APK smoke checks (manual, batched).
- CI runs format/analyze/test on every PR (see CLAUDE.md §6).
