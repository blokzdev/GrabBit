# GrabBit — Multi-Phase Roadmap

Status: Draft v0.4 · Last updated: 2026-05-24

Phased delivery plan for end-to-end agentic DevOps. Each phase has **Goals**,
**Deliverables**, **Exit criteria**, and **CI/build notes**. Phases are sequential
by default; later phases assume earlier exit criteria are met.

Legend (two version bands — the former **v3 cloud/credits band is dropped**):
- **v1 — Android, free, on-device, AI-powered:** P0–P14. Core downloader + private media manager
  (P0–P9), then the **on-device AI + graph pillar** — P10 (baseline edge AI + Cozo graph/vector
  foundation) · P12 (device-tiered edge LLM engine) · P13 (LLM features + local GraphRAG) — then
  **P14 (beta, production readiness & launch)**. AI is core to the vision, so **v1 ships *after* it**.
- **v2 — local-only expansion (still free/offline):** P15 (Windows parity) · P16 (production polish
  + authenticated/cookie import).

The app is **free forever and fully offline** — sustained by an **optional donations link**, with
**no ads and no telemetry**. (The previous **v3** Supabase/Gemini/credit phases are **deleted**; the
`InferenceEngine` interface leaves a *theoretical* cloud seam, but it is **unplanned**.) Deep design
for the AI/graph phases lives in `docs/GRAPH-SPEC.md`, `docs/AI-SPEC.md`, and
`docs/design/P-AI-PLAN.md`.

---

# v1 — Android, free, on-device, AI-powered

## P0 — Foundation
**Goals:** stand up a buildable Flutter project + the architecture skeleton + CI.
**Deliverables:**
- Flutter app scaffold; feature-first folder structure (per CLAUDE.md §3).
- Core wiring: Riverpod, go_router, Material 3 theming (light/dark/dynamic), strict
  `analysis_options.yaml`, logging.
- Drift DB with the schema in SPEC §3 (+ migration test).
- `DownloadEngine` interface + stub impls; `pigeons/engine.dart` defined.
- `.github/workflows/ci.yml` (auto: format/analyze/test) and
  `.github/workflows/build-apk.yml` (manual: APK artifact).
**Exit criteria:** green `ci.yml`; a downloadable **debug APK artifact** that
launches to an empty library screen.
**CI/build notes:** first APK build validates the pipeline; keep base APK lean.

## P1 — Core Engine (Android)
**Goals:** real downloads end-to-end on Android.
**Deliverables:**
- `AndroidYtDlpEngine` via Pigeon → Kotlin → youtubedl-android (Python+yt-dlp+ffmpeg).
- Paste URL → **probe** formats; single-URL **download** with live progress
  (speed/ETA/%); cancel.
- ffmpeg merge (video+audio); save to **private working dir**.
- In-app library list + basic video/image **player**; thumbnails.
- YouTube validated first; verify a couple more sites opportunistically.
**Exit criteria:** download a YouTube video on a real device via the manual APK,
see it in the private library, play it in-app.
**CI/build notes:** batch native changes before triggering APK builds.

## P2 — Manager UX
**Goals:** make it a real private media manager + configurable.
**Deliverables:**
- Download **queue** (foreground service, persistence, concurrency, retry,
  pause/resume).
- **Simple vs Advanced** modes; per-download format/quality/audio-only/subtitles.
- **Metadata management** (edit title/tags/notes), collections, search/sort/filter.
- **Save to device**: full **SAF folder picker** (`ACTION_OPEN_DOCUMENT_TREE` +
  persistable URI) with a gallery-visible **MediaStore default**; **auto-export**
  setting; `storage_state` (`private → exported`) tracking. Private master is kept
  on export.
- **App lock** (PIN + biometric) with router gate.
- Settings screen (all defaults per SPEC §4).

**Delivery tactic:** P2 is large, so it ships as **3 sequential sub-PRs** (each its
own `claude/p2{a,b,c}-*` branch + PR, merged in order): **P2-A** Config + Queue core
(pure Dart), **P2-B** Background foreground-service + Export (native/Pigeon — batched
so the maintainer device-tests the risky surfaces in one session), **P2-C** Manager
UX (metadata/collections/search) + App lock.
**Exit criteria:** queue a few downloads, export selected items to gallery, lock the
app, reopen with PIN/biometric.

## P3 — Multi-Site + Bulk
**Goals:** breadth + scale. **Public content only** — authenticated/private content
(cookie/login import) is deferred to **v2** (see P16).
**Deliverables:**
- Instagram, TikTok, X (and more yt-dlp supports) verified for **public** posts,
  playlists, and carousels; clear errors for unsupported/broken extractors.
- **Multi-item selection UI**: when a URL expands to several items (playlist,
  channel, or a mixed image/video carousel), show a thumbnail picker so the user
  views and chooses exactly which items to download.
- **Download now vs. add to queue**: each item/URL can download immediately or be
  added to a queue; users accumulate media across multiple sites, then start the
  whole batch as one background run.
- **Bulk**: playlist/channel expansion, multi-URL paste, batch import.
- Subtitles/captions, thumbnail, full metadata extraction + embedding.
- User-triggered **yt-dlp self-update**.
**Exit criteria:** expand a playlist/carousel, pick a subset, queue items from
several sites, and run the batch download reliably.

## P4 — v1 Completion & Refinement
**Goals:** close the gaps and rough edges found in review so the app is genuinely
daily-drivable; no new feature areas. Ships as three sub-PRs.
**Deliverables:**
- **Correctness & code-health** (P4a): unify taskId generation; tighten queue
  pause/cancel state + foreground-service error handling; settings schema version;
  per-task notification progress; remove dead code; +tests.
- **UX refinements** (P4b): queue shows media titles (not URLs); confirmation
  dialogs + snackbar feedback on mutations; surface captured metadata
  (description/uploadDate/uploader) on item detail; "clear completed"; fix
  select/deselect-all; badge counts; pull-to-refresh.
- **Feature completion** (P4c): in-app **legal/user-responsibility disclaimer** +
  first-run onboarding; user-editable **filename template**; **Wi-Fi-only resume**
  (auto-start when back on an unmetered network).
**Exit criteria:** founder daily-drives a debug build with no critical bugs; gaps
closed; review backlog cleared.

## P5 — Media Manager: File Explorer + rich metadata & faceted browsing
**Goals:** a Dropbox-like in-app file system on top of the private library (no files
moved on disk) plus rich metadata capture so the library can be browsed/filtered by
platform, channel, username, playlist, and keywords. Two coexisting views: the
**Library** (collections/tags/facets) and a new **Explorer** (folder tree), reached by
a segmented toggle on Home. Ships as **3 sub-PRs**.
**Deliverables:**
- **P5a — Schema v2 + rich metadata capture**: first Drift migration (v1→v2) adding a
  `Folders` table (`id`, `name`, `parentId` self-FK `setNull`, `createdAt`), a nullable
  `folderId` on `MediaItems`, and metadata columns (`uploaderId`, `channelId`,
  `sourceId`, `playlistId`, `playlistTitle`, `tags`) + facet indices. Capture full
  metadata uniformly via yt-dlp `--write-info-json` (parsed at completion, retained on
  disk) for **both single and batch** downloads; playlist identity threaded from the
  expansion step.
- **P5b — File Explorer**: folder repository (create/rename/delete reparent-or-orphan,
  move items, watch subfolders/items, breadcrumbs); Explorer view via the Library |
  Explorer Home toggle; multi-select "move to folder". Coexists with collections/tags.
- **P5c — Faceted filtering/browsing**: filter the Library by platform/site, channel,
  username, playlist, and description keywords; surface the new metadata on item detail.
- Physical files stay at `media/<taskId>/…`; folders are purely **virtual**. Existing
  items start at the root — no data rearrangement.
**Exit criteria:** a v1 DB upgrades cleanly; batch downloads carry full metadata;
create/move/rename folders and browse via Explorer; filter by platform/channel/
playlist/keyword — all while Library search/sort/collections still work.

## P6 — Media Studio: Editing Tools
**Goals:** on-device (therefore free) media editing for saved items, leveraging the
already-bundled ffmpeg.
**Deliverables:**
- **ffmpeg exposure** (spike-gated): confirm youtubedl-android's bundled
  `FFmpeg.getInstance()` runs arbitrary args with progress → expose via a new Pigeon
  `MediaToolsHostApi.runFfmpeg(...)` (mirroring the `YtDlpHostApi` wiring). Fallback:
  a maintained `ffmpeg_kit` fork (note APK-size cost; original retired in 2025).
- **`MediaToolsEngine`** pure-Dart interface (like `DownloadEngine`) so Windows
  (`ffmpeg.exe`, P12) slots behind the same contract.
- **Editor UI** from the item viewer: video — trim, reverse, flip/mirror/rotate,
  convert (container/codec/audio-extract), extract frame(s) (first/last/scrubber →
  image); images — flip/mirror/rotate/crop/convert.
- Outputs are **new library items** (originals preserved), landing in the current
  folder (P5) with metadata; progress shown (reuse the foreground-service/queue
  pattern). Unsupported ops are cleanly gated.
**Exit criteria:** trim a video, extract a frame, and flip an image — each produces a
new playable/viewable library item fully offline.

## P7 — Branding & Frontend Revamp
**Goals:** elevate the MVP-feeling frontend into a cohesive, world-class,
production-ready Android experience with a real visual identity. No backend, no new
feature areas — pure design/identity/UX. **Material 3 Expressive** is the target
language; a **rabbit motif** ("Grab" + rabbit) anchors the brand.
**Scope (high level):** brand identity (rabbit-ears logo + adaptive icon + splash);
a Material 3 Expressive design foundation (color/type/shape/motion + design tokens);
a restyled shared component library; a per-screen revamp of all 12 routes; and a
responsive/foldable + accessibility pass.
**Delivery:** designed **directly in Flutter** (no external wireframing tool) and
shipped as many small **subphases** (foundation first, then one per screen), each
reviewed on-device. The subphase breakdown lives in
**`docs/design/P7-REVAMP-PLAN.md`**; the design system (brand, tokens, components,
per-screen intent) lives in **`docs/design/DESIGN_SPEC.md`**.
**Exit criteria:** every screen revamped to the new system and verified on a real
device (light/dark + dynamic color); new icon/splash render; no regression in the
P0–P6 on-device checks.

## P8 — Download Engine Power & Intake
**Goals:** deepen the downloader into a power-user tool and make getting links in
effortless. All on-device (therefore free); no cloud, no auth/cookie work. Native-heavy
(Pigeon/Kotlin/manifest), so it's verified on-device. Ships as **4 sub-PRs** (P8a–P8d);
the subphase breakdown lives in **`docs/design/P8-PLAN.md`**.
**Deliverables:**
- **P8a — Android share-sheet intake**: `ACTION_SEND`/`ACTION_SEND_MULTIPLE`
  (`text/plain`) intent-filter so a link shared from YouTube/Instagram/etc. opens
  GrabBit pre-filled. Hand-rolled via the existing Pigeon bridge (avoid abandoned
  share plugins); URL extraction/normalization is pure-Dart + tested. Links-only.
- **P8b — Engine request expansion + power-download options** (foundational native
  batch): extend `DownloadRequest`/`DownloadRequestDto`/`YtDlpHost.kt` with rate-limit
  (`--limit-rate`), concurrent fragments (`--concurrent-fragments`), an Advanced-mode
  custom-args escape hatch (validated at the boundary), a download archive
  (`--download-archive`) to skip already-downloaded items on playlist/channel re-runs,
  and audio-extraction presets (`--audio-format`/`--audio-quality`). Mirror in
  `SettingsModel` (no DB migration).
- **P8c — Subtitles, SponsorBlock, chapters** (extends P8b; same APK batch): structured
  subtitle-language selection (`--sub-langs`/`--write-auto-subs`/`--convert-subs`) with
  an optional ffmpeg burn-in; **SponsorBlock** mark/remove
  (`--sponsorblock-mark`/`--sponsorblock-remove`); embed/`--split-chapters` (split maps
  N output files → N library items).
- **P8d — Advanced format/codec + audio-preset picker** (pure Dart): in Advanced mode,
  list probed `MediaInfo.formats` (resolution/codec/filesize) to pick a concrete format,
  plus an audio codec/bitrate picker (pulls in the BACKLOG advanced-format item).
**Exit criteria:** share a link from another app and it opens pre-filled; download with
selected subtitle languages, SponsorBlock segments removed, and a concrete chosen
format/audio preset; a re-run playlist skips already-downloaded items — all offline.

## P9 — Library, Playback & Privacy Depth
**Goals:** make managing, finding, and enjoying the private library genuinely great, and
harden privacy with non-theatrical lock features. Mostly pure Dart (CI-green) plus **one**
DB migration and a few native lock items. Ships as a series of sub-PRs (P9a–P9j); the subphase
breakdown lives in **`docs/design/P9-PLAN.md`**.
**Deliverables:**
- **P9a — Single v2→v3 DB migration** (do all schema changes once): `isFavorite` +
  `contentHash` (dedupe) on `MediaItems`, `orderIndex` on `DownloadTasks` (for P9d), sort
  columns + indices; bump `schemaVersion` to 3 with a migration test.
- **P9b — Library power**: full-text search (indexed `LIKE`) over title/uploader/
  description/tags; sort (date/size/name); favorites/star; smart/auto albums (by
  site/uploader/recent); **duplicate detection** (streamed `crypto` hash, off the UI
  isolate) + a duplicates view; storage-usage/cleanup breakdown.
- **P9c — Player enhancements**: playback speed, loop/repeat, gesture seek, subtitle-track
  selection (chewie); **Picture-in-Picture** (native). Background audio is deferred.
- **P9d — Queue depth**: drag-to-reorder (persisted via `orderIndex`) + an aggregate
  dashboard (speed/ETA/total size). Scheduling is deferred.
- **P9e — Privacy & app-lock hardening** (ship only the non-theatrical items): a
  **FLAG_SECURE** toggle (block screenshots / hide in recents); an **auto-lock timeout**;
  best-effort **secure delete**; PIN UX + failed-attempt lockout. Decoy PIN, intruder selfie,
  and app-icon disguise are deliberately cut (see `docs/BACKLOG.md`).
- **P9f — Storage & download safety**: a proactive **low-storage guard** (pre-flight free-space
  gate) and **battery-aware pause** on the scheduler; **orphaned-file cleanup**; and **device
  free/total** on the Storage screen. (PiP from P9c deferred to v2/P16; scheduling deferred.)
- **P9g/P9h/P9i/P9j — Actions, menus & polish**: a shared per-item **context menu** + **outbound
  Share** across the grids (P9g); **library multi-select + bulk actions** (P9h); **screen-level
  action menus** — collection/album app-bar actions, whole-queue actions, item-detail richness
  (P9i); and **Settings overflow + About screen + Studio post-op actions** (P9j).
- **P9k/P9l/P9m — Theming/motion/state polish pass** (pre-P10 refinement): AMOLED dark theme +
  cross-platform route transitions + motion-token adoption (P9k); skeleton→content cross-fade,
  multi-select bar animation, favorite micro-interaction (P9l); Storage/duplicates async-state fixes
  + empty-state CTAs (P9m).
**Exit criteria:** search/sort/favorite/dedupe the library and see storage usage; change
playback speed and pick subtitles; reorder the queue (order persists) and see the dashboard;
enable FLAG_SECURE and auto-lock; downloads pause on low storage/battery; long-press a tile for
actions and share a file out — all offline.

## P10 — Baseline edge AI + Cozo graph/vector foundation  *(device-universal)*
**Goals:** stand up the bundled **on-device graph + vector engine** and the always-available,
no-LLM-required feature floor. Everything here runs on *any* device. Ships as sub-PRs (P10a–f).
**Deliverables:**
- **Cozo foundation**: a `CozoHostApi` Pigeon→Kotlin bridge to the official Maven AAR
  `io.github.cozodb:cozo_android:0.7.2` (mirrors the youtubedl-android wiring); a pure-Dart
  `GraphStore` interface (`lib/core/graph/`) + Android Cozo impl; SQLite backend persisted at
  `<support>/graph/cozo.db`; the Cozo schema + a `GraphStore` conformance-test suite.
- **Lightweight universal embedder + index + sync**: a minimal `InferenceEngine.embed()` slice via
  `flutter_gemma` (Gecko, embedder-only — stays device-universal); an HNSW vector relation; a
  `GraphSyncService` (bulk build + incremental hooks + a "Rebuild index" action) with a
  schema-fingerprint self-heal. Drift stays canonical; **Cozo is a derived, rebuildable index**.
- **Universal graph features**: semantic search; **Related / "More like this"** (hybrid vector +
  graph re-rank); **entity hubs** (uploader/playlist/tag/site); **tag suggestions**; **proactive
  grouping** (a Duplicates auto-album + Suggested similarity albums in Collections→Albums); **interactive
  graph visualization** (candidate `graphview`). *(Richer community-detection auto-albums = P13.)*
- **P10d — GrabBit Dashboard** (the capstone that unifies P10c; split into sub-PRs): a **Dashboard**
  home that becomes the **new default landing (`/`)** and a **5th** nav destination (Library moves to
  `/library`). Visualizes the on-device footprint — storage % by media/file type & platform, library
  stats, recent activity, suggestions, and a graph tile — mostly composing existing providers with
  **`fl_chart`** viz. All on-device, no telemetry. See `docs/design/P-AI-PLAN.md`.
- **P10e — Extractive summaries**: a zero-dependency, pure-Dart **TextRank** floor over an item's
  **description**, surfaced as an auto-hiding "Summary" TL;DR on item-detail.
- **P10f — Transcript-text capture** (split into two PRs because the second touches native code):
  - **P10f-1** *(pure-Dart, done)*: parse/dedupe the `.vtt/.srt` sidecars already on disk into a stored
    `MediaMetadata.transcript` (schema v5), shown as an auto-hiding "Transcript" section and used as the
    preferred TextRank source. Built via a manual "Build transcript" action, with opt-in Settings
    toggles for automatic transcription (at download) and lazy backfill (on open).
  - **P10f-2** *(native)*: an on-demand "Get transcript" fetch (`--skip-download` via Pigeon/Kotlin)
    with a language selector for items that lack captions, plus a "fetch auto-captions on download"
    setting. Verified with a debug-APK build.
- **P10g — Settings IA & consistency pass**: regroup/nest the settings screen into clear sections, roll
  the `(i)`-info-tooltip pattern (seeded in P10f-1) across non-obvious settings, and reconcile gaps/
  inconsistencies introduced during P8–P10. Pure-Dart/UI.
**Exit criteria:** on any device, the Cozo index builds & rebuilds; semantic search + "related"
return sensible results offline; entity hubs and the graph view render; near-dup clusters and tag
suggestions work; the Dashboard summarizes the on-device footprint; an extractive TL;DR appears on
items with enough text — all with the small embedder, no LLM.
**Refs:** `docs/GRAPH-SPEC.md`, `docs/AI-SPEC.md`, `docs/design/P-AI-PLAN.md`.

## P11 — Activity Inbox (unified on-device notification center)
**Goals:** give the app a single, persisted, **on-device** place to surface and manage everything it
does in the background or wants to tell the user — download outcomes, transcript/backfill results,
AI/graph activity, errors, capability-gated "disabled because…" notices, reminders, status updates,
and actionable items. Built **before** the AI phases so their background work wires into it as it's
built, rather than being retrofitted. Privacy-first and on-vision: **entirely local — no telemetry,
no push, no cloud, no accounts**; lives behind the app lock.
**Deliverables:**
- A Drift **`notifications`** table (canonical, on-device) keyed by id, with `createdAt`, `category`
  (download | transcript | ai | graph | system | reminder), `severity` (info | success | warning |
  error), `title`, `body`, optional deep-link target (`targetRoute`/`itemId`/`taskId`), optional
  actionable affordance, `readAt?`, `dedupeKey?`, `expiresAt?`.
- A single **`NotificationCenter.post(...)`** write seam + `NotificationsRepository` + Riverpod
  providers (`watchUnreadCount`, `watchFeed(filter)`, `markRead`/`markAllRead`, `dismiss`, `clear`);
  every feature posts through this one seam.
- **Producers wired in:** the queue (download complete/failed, pause reasons), P10f
  backfill/auto-transcribe, `GraphSyncService` (rebuild done/failed); later phases (P12 model
  download + capability-gating disables, P13 AI task results) emit into the same seam.
- **UX:** an app-bar **bell with an unread badge** + a dedicated **`/inbox`** screen (grouped list,
  severity styling, tap → deep-link, swipe-to-dismiss, category filters, mark-all-read, clear) + a
  Dashboard recent-activity tile. (Not a 6th nav destination.)
- **Retention:** a configurable `notificationRetentionDays` setting (default ~30; `0` = keep forever)
  that auto-clears old items **lazily** on app/inbox open (no background scheduler); optional
  per-category notify toggles, each with an `(i)` tooltip (the P10g pattern).
- Complementary to the existing **OS/foreground notifications** (which stay the while-backgrounded
  channel) — the inbox is the durable in-app record; an item may optionally also raise an OS
  notification.
Device-universal, **pure-Dart/UI + a Drift schema bump** (no native needed for the core). **Split
into sub-PRs — granularity decided at P11 implementation-planning time.**
**Exit criteria:** background work (downloads, transcripts/backfills, graph sync) posts durable,
de-duplicated entries to the inbox; the bell badge reflects unread count; tapping an item deep-links
to the relevant screen; items auto-clear per the retention setting; everything stays on-device.
**Refs:** `docs/PRD.md` §7.5, `docs/ARCHITECTURE.md` §4, `docs/SPEC.md` §3–§4.

## P12 — Device-tiered edge LLM engine  *(minimal feature surface)*
**Goals:** enable on-device generation + transcription with **graceful capability-gating**. No
cloud, no account, no credits.
**Deliverables:** `DeviceCapabilityService` + device tiers + `ModelCapabilityMatrix`; on-demand
**model catalog + download + integrity check + caching** (install stays lean); `InferenceEngine`
impls via **`flutter_gemma`** (generation; wraps MediaPipe LLM Inference / LiteRT-LM) and
**whisper.cpp** (`whisper_ggml_plus` / `whisper_kit`) for transcription; ML Kit (OCR/translate)
where it fits; capability-gating so unsupported features are clearly disabled with a friendly
reason. **Model/licensing:** confirm current best models at phase start; **prefer Apache-2.0/MIT**
(SmolLM-135M, Qwen3-0.6B, Phi-4-Mini); Gemma usable but **vet its use policy before bundling**.
**Exit criteria:** on a capable device, download a model and generate/transcribe offline; on a
low-end device those features are cleanly disabled with explanation.
**Refs:** `docs/AI-SPEC.md` §3–4, `docs/design/P-AI-PLAN.md`.

## P13 — LLM feature surface & polish (incl. local GraphRAG)
**Goals:** the differentiating payoff, layered on P10 (graph+vector) + P12 (LLM).
**Deliverables:**
- **Transcription, abstractive summarization** (on the P10 TextRank floor), **translation, OCR** —
  all capability-gated.
- **Natural-language "Ask your library" chat as local GraphRAG** — Cozo hybrid retrieval (vector +
  graph re-rank) feeds a small local LLM; fully on-device.
- **Advanced graph analytics & viz**: graph-clustered auto-albums (community detection),
  centrality-based **"Rediscover"**, path/bridge discovery, graph-view polish.
- **Smart auto-tagging** feeding existing tags/facets; **model selector UX**.
**Exit criteria:** ask a natural-language question and get a grounded answer citing library items
offline; auto-albums cluster sensibly; rediscover surfaces central-but-stale items; all gated
gracefully on low-end devices.
**Refs:** `docs/AI-SPEC.md` §5–6, `docs/GRAPH-SPEC.md` §7.

## P14 — v1 Beta, Production Readiness & Launch
**Goals:** harden and **ship v1** (now an AI-powered downloader + private media manager).
**Deliverables:** **release signing** (keystore + CI secret; the ship blocker); performance
hardening (large library grid/thumbnails, DB indices, big-playlist picker, AI/graph index build);
**i18n scaffolding** (ARB/l10n); **distribution** (GitHub Release with the signed APK + a landing
site, install guides, README; version bump); an **optional donations link in the About screen**
(no ads, no telemetry); final full `docs/VERIFICATION.md` regression on the signed release APK.
**Exit criteria:** signed release APK installs and passes the full on-device regression; published
for sideload. **→ v1 complete (Android, free, offline, AI-powered).**

---

# v2 — Local-only expansion (Windows + polish; still free/offline)

## P15 — Windows Port
**Goals:** second platform with zero domain/UI rewrite.
**Deliverables:** `WindowsProcessEngine` (bundled `yt-dlp.exe`/`ffmpeg.exe`); desktop storage
adapter (filesystem export); desktop-adapted UI; **MSIX** packaging; binary update path. **Cozo on
Windows:** the C-API path — `cozo_c.dll` via `dart:ffi`/`ffigen` on a dedicated isolate (the
`GraphStore` Windows impl), per `docs/GRAPH-SPEC.md` §2.2.
**Exit criteria:** Windows build downloads + manages media (incl. the graph/AI features); feature
parity with v1. **CI note:** windows runners = 2x minutes — build Windows manually/on tags.

## P16 — Production Polish + Authenticated Content
**Goals:** make the local-only app genuinely world-class and production-ready.
**Deliverables:** accessibility, complete i18n, performance hardening, advanced configuration,
refined UX across all flows, robust update/onboarding.
- **Authenticated/private content** (deferred from v1): per-site **cookie/login import** so users
  can download their own private/age-gated/followers-only media, with cookies stored via
  `flutter_secure_storage`. Stays on-device — no account, no cloud, still free.
**Exit criteria:** v2 is stable, polished, and self-recommending; ready for wider (still off-store)
distribution. **→ v2 complete.**

---

# (v3 — Cloud AI + monetization) — DROPPED

The former v3 band (Supabase backend + accounts, Genkit→Gemini cloud AI, Stripe/PayPal credit
monetization, public cloud launch) is **removed**. GrabBit is **free forever and fully offline**,
sustained by an **optional donations link** (P14) — no ads, no telemetry, no accounts, no cloud. The
`InferenceEngine` interface still leaves a *theoretical* seam for a future cloud implementation, but
it is **not a planned phase**. (The corresponding cloud contracts in `docs/SPEC.md` §9.1–9.2 and
`docs/ARCHITECTURE.md` §9 are retained only as a historical/optional reference, marked dropped.)

---

## Cross-Cutting Conventions
- Every phase: keep CI green; update affected docs in the same commit; conventional
  commits on `claude/init-grabbit-setup-RaBUs` (until told otherwise).
- Conserve Actions minutes: auto CI = lint/analyze/test on ubuntu; APK/Windows
  builds are **manual/tagged** and batched (CLAUDE.md §6).
- Privacy/legal posture (PRD §13) holds throughout: **on-device, free forever**, optional
  donations, **no ads, no telemetry, no cloud/accounts**, user-responsibility disclaimer.
