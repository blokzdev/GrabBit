# GrabBit — Technical Specification

Status: Draft v0.2 · Last updated: 2026-05-24

Implementation-level detail. Versions are targets to confirm at scaffold time
(P0); pin exact versions in `pubspec.yaml` and record here.

---

## 1. Dependencies (targets)

| Package | Purpose |
|---|---|
| `flutter_riverpod`, `riverpod_annotation`, `riverpod_generator` | State mgmt + codegen |
| `go_router` | Routing |
| `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `drift_dev` | Local DB + codegen |
| `pigeon` (dev) | Type-safe platform channels |
| `path_provider` | App-private directories |
| `flutter_secure_storage` | PIN hash / secrets |
| `local_auth` | Biometric auth |
| `permission_handler` | Runtime permissions |
| `flutter_local_notifications` | Notification channel + terminal (complete/failed) notifications. The **foreground-service notification itself is built natively** in `DownloadService.kt` (FGS lifecycle requires it) |
| `video_player`, `chewie` | In-app media playback (P1) |
| `crypto` | Salted PIN hashing for app lock (P2) |
| `flutter_svg` | Render the brand SVG mark in-app at any size (P7) |
| `flutter_launcher_icons` (dev) | Generate the adaptive launcher icon — foreground + brand background + **monochrome** (Android-13 themed) — from PNG masters (P7) |
| `flutter_native_splash` (dev) | Generate the branded (Android-12+) splash, light/dark (P7) |
| **Bundled fonts** `Outfit` (display) + `Inter` (body) in `assets/fonts/` | Brand type, **bundled not fetched** — offline + privacy-first (no `google_fonts` runtime call) (P7) |
| Export to device: **hand-rolled Pigeon channel** (SAF + MediaStore) — no `media_store_plus`/`shared_storage` dep (see §5) | Export to gallery / user-picked folder |
| `dio` | HTTP (P12 on-device model downloads) |
| `freezed`, `json_serializable` | Immutable models / JSON |
| `intl` + `flutter_localizations` | i18n (ARB) |
| `logger` | Structured logging |
| **Android native:** `io.github.junkfood02.youtubedl-android:{library,ffmpeg}:0.17.3` (Maven Central; yt-dlp + ffmpeg + Python; Kotlin pkg `com.yausername.youtubedl_android`) | Download engine |
| **Graph+vector (P10):** `io.github.cozodb:cozo_android:0.7.2` (Maven Central AAR) via a `CozoHostApi` Pigeon bridge; `ffi`+`ffigen` (dev) for the Windows `dart:ffi` impl (P15). MPL-2.0. | On-device graph + HNSW vector DB. See `docs/GRAPH-SPEC.md`. |
| **On-device AI (P10b-2+):** `flutter_gemma` (MediaPipe/LiteRT-LM — embeddings + LLM + RAG; added P10b-2 embedder-only), a whisper.cpp pkg (`whisper_ggml_plus`/`whisper_kit`), ML Kit (OCR/translate) | On-device/edge AI. See `docs/AI-SPEC.md`. |
| **Graph viz (P10):** `graphview` | Interactive relationship explorer. |
| **Charts (P10d-2):** `fl_chart` | On-device Dashboard storage donuts + library-activity bars. Pure-Dart (CustomPainter), no native deps, no telemetry. |
| ~~**v3:** `supabase_flutter`, Stripe/PayPal SDKs~~ | **Dropped** (no cloud/credits). |

Add `flutter_lints`/`very_good_analysis` and a strict `analysis_options.yaml`.

---

## 2. Pigeon Engine API (`pigeons/engine.dart`)

```dart
class FormatDto { String id; String ext; int? height; int? tbr; String? vcodec;
  String? acodec; bool audioOnly; int? filesize; String label; }
class MediaInfoDto { String title; String? uploader; int? durationSec;
  String? thumbnailUrl; String? site; String? description; String? uploadDate;
  List<FormatDto> formats; }
class DownloadRequestDto { String taskId; String url; String? formatId;
  bool audioOnly; String? container; List<String>? subtitleLangs; bool autoSubs;
  String? subtitleFormat; bool embedThumbnail; bool embedMetadata;
  String outputDir; String filenameTemplate; String? rateLimit;
  int? concurrentFragments; String? audioQuality; String? downloadArchivePath;
  List<String>? extraArgs; String? sponsorBlock;
  List<String>? sponsorBlockCategories; bool embedChapters; bool splitChapters;
  bool skipDownload; /* P10f-2: subtitles-only fetch (`--skip-download`) */ }
class ProgressDto { String taskId; double percent; double speedBps; int? etaSec;
  String stage; /* probing|downloading|merging|done|error|canceled */ String? error; }

@HostApi()
abstract class YtDlpHostApi {
  @async MediaInfoDto probe(String url);
  @async String expandRaw(String url);   // raw `--flat-playlist -J` stdout; parsed in Dart (P3)
  void startDownload(DownloadRequestDto request);   // progress via FlutterApi
  void cancel(String taskId);
  @async String engineVersions();                   // yt-dlp + ffmpeg versions
  @async void updateEngine();
}
```

**Download options (P3):** `startDownload` passes `--write-thumbnail
--convert-thumbnails jpg` (library thumb) and, per request flags,
`--embed-thumbnail`, `--embed-metadata`, and subtitles
(`--write-subs --write-auto-subs --embed-subs`). **P10f-2:** when
`skipDownload` is set, `startDownload` writes only the caption file
(`--skip-download` + the sub flags, no media/thumbnail/embed) — the on-demand
"Get transcript" fetch. Playlist/channel/carousel
expansion is `expandRaw` → `yt-dlp --flat-playlist -J` → parsed by
`lib/core/engine/playlist_parser.dart` into `PlaylistInfo{entries:[MediaEntry]}`
(single items collapse to one entry). `media_metadata` is populated with
uploader/description/uploadDate/originalUrl on completion.
```dart

@FlutterApi()
abstract class YtDlpFlutterApi { void onProgress(ProgressDto progress); }
```

Windows impl maps the same DTOs to `yt-dlp.exe` args / stdout parsing.

---

## 3. Drift Schema (`core/db/`)

```dart
// media_items
TextColumn id; TextColumn title; TextColumn sourceUrl; TextColumn site;
TextColumn filePath; TextColumn type;            // video|audio|image
IntColumn? durationSec; IntColumn? sizeBytes; IntColumn? width; IntColumn? height;
TextColumn? thumbPath; DateTimeColumn createdAt; TextColumn storageState; // private|exported
TextColumn? notes; IntColumn? folderId;                  // v2: virtual Explorer folder
BoolColumn isFavorite; TextColumn? contentHash; DateTimeColumn? lastAccessedAt; // v3 (P9)
// metadata (v2 adds uploaderId, channelId, sourceId, playlistId, playlistTitle, tags)
TextColumn itemId; TextColumn? uploader; DateTimeColumn? uploadDate;
TextColumn? description; TextColumn? originalUrl;
TextColumn? transcript;                                  // v5 (P10f-1): caption-derived text
// tags(id,name) + media_tags(itemId,tagId)
// collections(id,name,createdAt) + media_collections(itemId,collectionId)
// download_tasks
TextColumn id; TextColumn url; TextColumn requestJson; TextColumn status;
RealColumn progress; TextColumn? errorCode; IntColumn retries; DateTimeColumn createdAt;
IntColumn orderIndex;                                    // v3 (P9d): queue reorder
// settings (key/value JSON, single row)
// notifications (v6, P11): id, createdAt, category, severity, title, body,
//   targetRoute?, itemId?, taskId?, readAt?, dedupeKey?, expiresAt?  — Activity Inbox
```

Migration strategy: Drift `schemaVersion` (currently **5**); write `MigrationStrategy`
steps; never drop user data without migration. Add a schema test on bump (upgrade tests
live in `test/core/db/database_test.dart`). **v3 (P9a)** adds
`media_items.{isFavorite,contentHash,lastAccessedAt}` + `download_tasks.orderIndex` and
indices on `is_favorite`/`content_hash`/`created_at`. **v4 (P9b-4)** adds a
`media_metadata.source_id` index for preventive (pre-download) source-id dedupe. **v5 (P10f-1)**
adds `media_metadata.transcript` (caption-sidecar text feeding the summary). `contentHash`
is populated lazily by the P9b-3 duplicate scan (`DedupeService`, off-isolate); `lastAccessedAt`
is set on playback (P9c). The probe (`MediaInfo`/`MediaInfoDto`) now carries the source `id`.
**Planned: v6 (P11)** adds the `notifications` table backing the Activity Inbox; **P10f-4** adds a
timestamped-cue representation beside the flat transcript (tap-to-seek); **P10h** adds a SQLite **FTS5**
index over `transcript`+`description`+`title` (search by spoken content).

---

## 4. Settings Schema & Defaults

```jsonc
{
  "mode": "simple",                 // simple|advanced
  "defaultQuality": "best",         // best|1080p|720p|audio_only|...
  "defaultContainer": "mp4",
  "storagePolicy": "private",       // private|auto_export
  "exportFolder": null,             // user-picked dir for export/auto-store
  "filenameTemplate": "%(title)s.%(ext)s",
  "maxConcurrentDownloads": 2,
  "concurrentFragments": 1,         // P8b; >1 = parallel fragments ("Faster downloads")
  "rateLimit": "",                  // P8b; yt-dlp --limit-rate (e.g. 1M); "" = unlimited
  "audioFormat": "m4a",             // P8b; audio-only codec (yt-dlp --audio-format)
  "audioQuality": "best",           // P8b; --audio-quality (e.g. 192K); best = omit
  "useDownloadArchive": false,      // P8b; --download-archive to skip already-fetched
  "extraDownloadArgs": "",          // P8b; raw extra yt-dlp args (Advanced escape hatch)
  "subtitleLangs": "",              // P8c; CSV langs (e.g. en,es); "" = off
  "subtitleAuto": false,            // P8c; --write-auto-subs
  "subtitleFormat": "srt",          // P8c; --convert-subs (srt|vtt|ass|best)
  "autoTranscribe": false,          // P10f-1; build transcript from captions after download
  "transcriptBackfill": false,      // P10f-1; build transcript on first open of older items
  "autoDownloadCaptions": false,    // P10f-3; fetch captions (in-app lang) on download when no explicit langs
  "sponsorBlockMode": "off",        // P8c; off|mark|remove
  "sponsorBlockCategories": "sponsor", // P8c; CSV SponsorBlock categories
  "embedChapters": false,           // P8c; --embed-chapters
  "splitChapters": false,           // P8c; --split-chapters (N library items)
  "wifiOnly": false,
  "notificationRetentionDays": 30,  // P11; Activity Inbox auto-clear after N days (0 = keep forever)
  "theme": "system",                // system|light|dark
  "dynamicColor": true,
  "locale": null,                   // null = system
  "appLock": { "enabled": false, "biometric": false }
}
```

**P8b power options** are global, **Advanced-mode** settings (except the friendly
"Faster downloads (beta)" toggle, which sets `concurrentFragments` to 4/1 and is shown in
both modes). They default to current behavior, flow into every `DownloadRequest` via
`buildDownloadRequest` (single + batch), and map to yt-dlp flags in `YtDlpHost.kt`.
`extraDownloadArgs` is tokenized on whitespace and passed straight to yt-dlp (no shell).

**App-lock (P2-C) deviation:** settings JSON holds only `appLock.enabled` and
`appLock.biometric`. The PIN is **never** stored here — `PinRepository` keeps a
random salt + `sha256(salt:pin)` (via the `crypto` package) in
`flutter_secure_storage`. A go_router `redirect` gates the app: when app-lock is
enabled and `LockController` is `locked`, all routes redirect to `/lock`; the app
re-locks on `AppLifecycleState.paused/hidden`. `local_auth` provides the optional
biometric unlock (requires `MainActivity` to extend `FlutterFragmentActivity`).

---

## 5. Permissions Matrix (Android)

| Permission | When | Notes |
|---|---|---|
| `INTERNET` | always | downloads |
| `POST_NOTIFICATIONS` (13+) | on first download | foreground-service progress |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_DATA_SYNC` | downloads | long-running queue; service shows the progress notification |
| SAF tree URI (persisted) | when user picks an export folder | `ACTION_OPEN_DOCUMENT_TREE` + `takePersistableUriPermission`; no storage permission |
| Scoped MediaStore write | export with no folder picked (gallery default, API 29+) | `RELATIVE_PATH` under Movies/Music/Pictures + `/GrabBit`; no `MANAGE_EXTERNAL_STORAGE` |
| `USE_BIOMETRIC` | if app lock + biometric | local_auth |

Never request broad storage. Private library lives in app-specific storage (no
permission needed).

**Export model (P2-B):** downloads stay private (app-specific dir) until the user
explicitly exports. Export is a hand-rolled Pigeon `StorageHostApi`: a user-picked
**SAF tree** (`exportToTree`, persisted URI in settings) is preferred; with no
folder chosen it falls back to the gallery-visible **MediaStore** default
(`exportToMediaStore`, API 29+). The private master file is kept after export and
`media_items.storage_state` flips `private → exported`. The download foreground
service keeps the process alive while the in-process queue runs; full process-death
survival is handled by DB reconciliation on next launch (orphaned `running` →
`queued`). Wi-Fi-only gates task starts via a native `isUnmetered()` probe (no
`connectivity_plus` dependency).

---

## 6. Error Taxonomy & Retry

```dart
enum DownloadErrorCode {
  network, unsupportedSite, extractorFailed, formatUnavailable,
  ffmpegFailed, storageFull, permissionDenied, canceled, unknown
}
```
- Retry transient (`network`, some `extractorFailed`) up to N with exponential
  backoff; never retry `unsupportedSite`/`permissionDenied`.
- Map each code to a user-friendly message + actionable hint; log technical detail. From P11,
  user-relevant failures (and other notable background outcomes) also post to the **Activity Inbox**.
- `storageFull` stays a terminal, reactive classification of a yt-dlp "no space" failure; P9f
  adds a **proactive** pre-flight low-storage guard that holds new downloads *before* they start
  (the scheduler's `minFreeSpaceMb` gate), so the reactive code is the fallback, not the front line.

**AI/graph errors (P10, P12–P13):** `modelDownloadFailed`, `modelIntegrityFailed`,
`modelUnsupportedOnDevice` (a *gating* state — disable the feature with a friendly reason, not a
user-facing error), `inferenceFailed`, `transcriptionFailed`, `indexUnavailable`. Never crash; gate
rather than fail where the device can't run a model. See `docs/AI-SPEC.md` §8 / `docs/GRAPH-SPEC.md` §8.

---

## 7. Packaging

- **Android:** debug APK for CI artifact; release builds signed with a keystore
  (secrets in CI, never committed). Provide AAB for the future landing site.
  `minSdk` chosen to satisfy youtubedl-android (confirm at P0).
- **Android (P10):** the Cozo engine is a Maven AAR (`cozo_android`) — **no NDK/Rust build in CI**;
  set `abiFilters` and measure APK-size impact in the first P10 APK build.
- **Windows (P15):** bundle `yt-dlp.exe` + `ffmpeg.exe` + `cozo_c.dll` in install dir (the Cozo
  `dart:ffi` impl, prefer the native-assets `hook/build.dart`); package as **MSIX**; verify binary
  update path.

---

## 8. CI Workflows (created in P0)

**`.github/workflows/ci.yml`** (auto, ubuntu):
```
on: [pull_request, push: feature branches]
steps: setup-flutter (cached) → pub get → build_runner →
       dart format --set-exit-if-changed . → flutter analyze → flutter test
```

**`.github/workflows/build-apk.yml`** (manual):
```
on: workflow_dispatch { inputs: { release: boolean (default false) } }
steps: setup-flutter + cache(pub, gradle) → build_runner →
       flutter build apk (--debug | --release) →
       upload-artifact (app-*.apk)
```
Budget rules per CLAUDE.md §6: ubuntu only, cache, manual APKs, no push-builds.

---

## 9. AI Contracts (on-device, P10, P12–P13)

> **Banding:** all AI is **on-device (v1, P10, P12–P13)** and never requires an account, network
> (beyond a one-time model download), or credits. Deep design: `docs/AI-SPEC.md`
> (runtime/models/GraphRAG) and `docs/GRAPH-SPEC.md` (graph + vector store).

### 9.1–9.2 Cloud backend (Supabase / Gemini / Stripe-PayPal) — DROPPED
The former v3 cloud contracts (Postgres credit ledger, Edge Functions → Genkit/Gemini, payment
webhooks) are **removed** — no backend, no accounts, no credits. The `InferenceEngine` keeps a
theoretical-only cloud seam (`docs/AI-SPEC.md` §1), but it is unplanned.

### 9.3 On-device AI (v1, P10, P12–P13)
- `DeviceProfile { ramMB, soc, hasNpu, hasGpu, osVersion, freeStorageMB }`.
- Device tiers (e.g. low / mid / high) → `ModelCapabilityMatrix`:
  `feature → eligibleLocalModels[byTier]`.
- Runtime: **`flutter_gemma`** (MediaPipe/LiteRT-LM — embeddings + LLM + RAG); **whisper.cpp**
  (transcription); ML Kit (OCR/translate). Models downloaded on-demand, integrity-checked, cached.
- Model selector resolves to **Free — Local** when `canRun`; otherwise the feature is **gated**
  (disabled with a friendly reason). Prefer Apache-2.0/MIT models; vet Gemma. (`docs/AI-SPEC.md` §4.)
- **Graph + vector store** (`GraphStore`/CozoDB) is specified separately in `docs/GRAPH-SPEC.md`.

---

## 10. Open Items
- ~~Exact `minSdk` for youtubedl-android~~ → **minSdk 24** (Flutter 3.44 default;
  satisfies the JunkFood02 fork). NDK/ABI splits for APK size: decided in P1
  (`abiFilters` arm64-v8a/armeabi-v7a/x86_64; ABI splits in `build-apk.yml` if large).
- ~~Pigeon EventChannel vs FlutterApi for progress~~ → **FlutterApi callbacks**
  (`YtDlpFlutterApi.onProgress`), dispatched to per-task Dart streams.
- ~~media_store plugin vs hand-rolled platform channel for export~~ → **hand-rolled
  Pigeon channel** (SAF `ACTION_OPEN_DOCUMENT_TREE` + persistable URI for a
  user-picked folder; MediaStore `RELATIVE_PATH` default for gallery visibility). No
  new dependency. See §5.
- Strict-lints package choice → `flutter_lints` + strict analyzer toggles (P0).

### Implementation conventions (learned)
- **Manual Riverpod providers for Drift-row types.** `riverpod_generator` throws
  `InvalidTypeException` when a `@riverpod` function's signature references a Drift
  generated row class (e.g. `MediaItem`, `DownloadTask`). Any provider that returns
  such a type **must be a hand-written** `StreamProvider`/`FutureProvider`/`Notifier`,
  not codegen. Codegen is still used everywhere else (engine provider, router, etc.).
- **Navigation IA (P10d).** Five top-level destinations live in the `StatefulShellRoute`
  (`core/routing/app_router.dart`), ordered **Dashboard · Library · Queue · Collections ·
  Settings**. The **Dashboard is the default landing (`/`)**; the Library lives at
  `/library`. `startupRedirect`/`lockRedirect` (`core/routing/router_refresh.dart`) treat
  `/` as "home", so onboarding and unlock land on the Dashboard. The Dashboard
  (`features/dashboard/`) composes existing aggregation providers into a hand-written
  `dashboardSummaryProvider` (Drift-row inputs → pure `DashboardSummary`).
