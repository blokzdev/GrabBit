# GrabBit — Technical Specification

Status: Draft v0.1 · Last updated: 2026-05-20

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
| `flutter_local_notifications` | Foreground-service progress UI |
| `media_store_plus` (or platform channel) | Export to gallery (scoped storage) |
| `dio` | HTTP (v2 model downloads; v3 backend) |
| `freezed`, `json_serializable` | Immutable models / JSON |
| `intl` + `flutter_localizations` | i18n (ARB) |
| `logger` | Structured logging |
| **Android native:** `io.github.junkfood02.youtubedl-android:{library,ffmpeg}:0.17.3` (Maven Central; yt-dlp + ffmpeg + Python; Kotlin pkg `com.yausername.youtubedl_android`) | Download engine |
| **v2:** LiteRT / MediaPipe LLM bindings, whisper.cpp, ML Kit | On-device/edge AI |
| **v3:** `supabase_flutter`, Stripe/PayPal SDKs | Cloud backend + payments |

Add `flutter_lints`/`very_good_analysis` and a strict `analysis_options.yaml`.

---

## 2. Pigeon Engine API (`pigeons/engine.dart`)

```dart
class FormatDto { String id; String ext; int? height; int? tbr; String? vcodec;
  String? acodec; bool audioOnly; int? filesize; String label; }
class MediaInfoDto { String title; String? uploader; int? durationSec;
  String? thumbnailUrl; String? site; List<FormatDto> formats; }
class DownloadRequestDto { String taskId; String url; String? formatId;
  bool audioOnly; String? container; bool subtitles; bool embedThumbnail;
  bool embedMetadata; String outputDir; String filenameTemplate; }
class ProgressDto { String taskId; double percent; double speedBps; int? etaSec;
  String stage; /* probing|downloading|merging|done|error|canceled */ String? error; }

@HostApi()
abstract class YtDlpHostApi {
  @async MediaInfoDto probe(String url);
  void startDownload(DownloadRequestDto request);   // progress via FlutterApi
  void cancel(String taskId);
  @async String engineVersions();                   // yt-dlp + ffmpeg versions
  @async void updateEngine();
}

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
TextColumn? notes;
// metadata
TextColumn itemId; TextColumn? uploader; DateTimeColumn? uploadDate;
TextColumn? description; TextColumn? originalUrl;
// tags(id,name) + media_tags(itemId,tagId)
// collections(id,name,createdAt) + media_collections(itemId,collectionId)
// download_tasks
TextColumn id; TextColumn url; TextColumn requestJson; TextColumn status;
RealColumn progress; TextColumn? errorCode; IntColumn retries; DateTimeColumn createdAt;
// settings (key/value JSON, single row)
```

Migration strategy: Drift `schemaVersion`; write `MigrationStrategy` steps; never
drop user data without migration. Add a schema test on bump.

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
  "wifiOnly": false,
  "theme": "system",                // system|light|dark
  "dynamicColor": true,
  "locale": null,                   // null = system
  "appLock": { "enabled": false, "biometric": false, "pinHash": null }
}
```

---

## 5. Permissions Matrix (Android)

| Permission | When | Notes |
|---|---|---|
| `INTERNET` | always | downloads |
| `POST_NOTIFICATIONS` (13+) | on first download | foreground-service progress |
| `FOREGROUND_SERVICE` + `*_DATA_SYNC` | downloads | long-running queue |
| Scoped MediaStore write | only on export/auto-store | no `MANAGE_EXTERNAL_STORAGE` |
| `USE_BIOMETRIC` | if app lock + biometric | local_auth |

Never request broad storage. Private library lives in app-specific storage (no
permission needed).

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
- Map each code to a user-friendly message + actionable hint; log technical detail.

---

## 7. Packaging

- **Android:** debug APK for CI artifact; release builds signed with a keystore
  (secrets in CI, never committed). Provide AAB for the future landing site.
  `minSdk` chosen to satisfy youtubedl-android (confirm at P0).
- **Windows (P5):** bundle `yt-dlp.exe` + `ffmpeg.exe` in install dir; package as
  **MSIX**; verify binary update path.

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

## 9. AI & Backend Contracts (v2 local AI · v3 cloud)

> **Banding:** On-device AI (§9.3) is the **v2** priority and never requires an
> account, network, or credits. The Supabase/cloud contracts (§9.1–9.2) are **v3**
> and ship only when cloud AI is introduced.

### 9.1 Supabase tables (v3 — Postgres, RLS on)
- `profiles(user_id pk, created_at)`
- `credit_ledger(id, user_id, delta int, reason, ref, created_at)` — balance = sum(delta)
- `ai_usage(id, user_id, feature, model, tokens/seconds, cost_credits, created_at)`
- `payments(id, user_id, provider, provider_ref, amount, credits_granted, status, created_at)`

### 9.2 Edge Functions (v3)
- `POST /ai/{feature}` — auth → check balance → Genkit flow → Gemini → debit
  (transactional) → return result. Rate-limited.
- `POST /webhooks/stripe`, `POST /webhooks/paypal` — verify signature → grant
  credits (ledger insert) → mark payment.
- Keys (Gemini, Stripe, PayPal) in Supabase secrets only.

### 9.3 On-device AI (v2)
- `DeviceProfile { ramMB, soc, hasNpu, hasGpu, osVersion, freeStorageMB }`.
- Device tiers (e.g. low / mid / high) → `ModelCapabilityMatrix`:
  `feature → { eligibleLocalModels[byTier], cloudModels[] }`.
- Local models (LiteRT/MediaPipe; whisper.cpp/ONNX where better) downloaded
  on-demand to app storage, integrity-checked, cached.
- Model selector resolves: show **Free — Local** if `canRun`, plus **Cloud
  (credits)**; cloud-only when no eligible local model.

---

## 10. Open Items
- ~~Exact `minSdk` for youtubedl-android~~ → **minSdk 24** (Flutter 3.44 default;
  satisfies the JunkFood02 fork). NDK/ABI splits for APK size: decided in P1
  (`abiFilters` arm64-v8a/armeabi-v7a/x86_64; ABI splits in `build-apk.yml` if large).
- ~~Pigeon EventChannel vs FlutterApi for progress~~ → **FlutterApi callbacks**
  (`YtDlpFlutterApi.onProgress`), dispatched to per-task Dart streams.
- media_store plugin vs hand-rolled platform channel for export → **P2**.
- Strict-lints package choice → `flutter_lints` + strict analyzer toggles (P0).
