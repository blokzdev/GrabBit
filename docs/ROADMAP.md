# GrabBit — Multi-Phase Roadmap

Status: Draft v0.3 · Last updated: 2026-05-23

Phased delivery plan for end-to-end agentic DevOps. Each phase has **Goals**,
**Deliverables**, **Exit criteria**, and **CI/build notes**. Phases are sequential
by default; later phases assume earlier exit criteria are met.

Legend (three version bands):
- **v1 — Android core, free, on-device:** P0–P10 (P4 completion & refinement, P5 file
  explorer, P6 media studio, P7 branding & frontend revamp, P8 download engine power &
  intake, P9 library/playback/privacy depth, P10 beta & production readiness / release).
- **v2 — world-class, feature-rich, production-ready, LOCAL-ONLY (no cloud):**
  P11 (Windows parity) · P12 (edge/local AI) · P13 (production polish).
- **v3 — cloud AI + credit monetization:** P14 (backend + accounts) · P15 (cloud AI)
  · P16 (public launch).

The app stays fully free and offline through v2. Money enters only in v3.

---

# v1 — Android core (free, on-device)

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
(cookie/login import) is deferred to **v2** (see P13).
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
  (`ffmpeg.exe`, P11) slots behind the same contract.
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
  free/total** on the Storage screen. (PiP from P9c deferred to v2/P13; scheduling deferred.)
- **P9g/P9h/P9i/P9j — Actions, menus & polish**: a shared per-item **context menu** + **outbound
  Share** across the grids (P9g); **library multi-select + bulk actions** (P9h); **screen-level
  action menus** — collection/album app-bar actions, whole-queue actions, item-detail richness
  (P9i); and **Settings overflow + About screen + Studio post-op actions** (P9j, closing P9).
**Exit criteria:** search/sort/favorite/dedupe the library and see storage usage; change
playback speed and pick subtitles; reorder the queue (order persists) and see the dashboard;
enable FLAG_SECURE and auto-lock; downloads pause on low storage/battery; long-press a tile for
actions and share a file out — all offline.

## P10 — v1 Beta & Production Readiness
**Goals:** harden and ship v1.
**Deliverables:** **release signing** (keystore + CI secret; the ship blocker);
performance hardening (large library grid/thumbnails, DB indices, big-playlist
picker); **i18n scaffolding** (ARB/l10n); distribution (GitHub Release with the signed
APK + README/landing install steps; version bump); final full `docs/VERIFICATION.md`
regression on the signed release APK. (Subtitle-language selection moved up to P8c.)
**Exit criteria:** signed release APK installs and passes the full on-device
regression; published for sideload. **→ v1 complete.**

---

# v2 — World-class, local-only (Windows + edge AI + polish)

## P11 — Windows Port
**Goals:** second platform with zero domain/UI rewrite.
**Deliverables:** `WindowsProcessEngine` (bundled `yt-dlp.exe`/`ffmpeg.exe`),
desktop storage adapter (filesystem export), desktop-adapted UI, **MSIX** packaging,
binary update path.
**Exit criteria:** Windows build downloads + manages media; feature parity with v1
core. **CI note:** windows runners = 2x minutes — build Windows manually/on tags.

## P12 — Edge/Local AI (free, on-device)
**Goals:** the differentiator — on-device AI with graceful capability-gating. **No
cloud, no account, no credits.**
**Deliverables:**
- **DeviceCapabilityService** + device tiers; **ModelCapabilityMatrix**.
- `InferenceEngine` with on-device impls: **LiteRT / MediaPipe LLM** (Gemma-class),
  **whisper.cpp** (transcription), **ML Kit** (OCR/translation/labeling).
- **On-demand model download** + integrity check + caching (keeps install lean).
- First local feature set: transcription, summarization, translation, OCR, smart
  tagging / semantic search.
- **Summarization tiers** (capability-gated): a **zero-dependency, pure-Dart extractive
  baseline (TextRank)** over captured descriptions/subtitles/transcripts that runs on *any*
  device — the always-available floor — with the **LiteRT/MediaPipe LLM** abstractive
  summary layered on top for capable devices. Keeps a useful TL;DR available even on
  low-end hardware. (Considered for v1/P9 and deliberately deferred here.)
- **AI-powered library organization** (the on-device, free counterpart to P9b's
  deterministic SQL albums/search — layered *beside*, not replacing, them; every
  feature `DeviceCapability`-gated):
  - **Semantic search** over titles/descriptions/notes + **whisper.cpp transcripts**
    via local text embeddings (ML Kit / MediaPipe / a small sentence-transformer),
    backed by an **on-device vector index** (e.g. `sqlite-vec`, ObjectBox, or an
    in-memory ANN) — complements the existing `LIKE` search, never phones home.
  - **Topic / content-similarity albums** ("more like this", auto-clustered albums)
    built on those embeddings — the AI sibling of P9b-2's SQL smart albums.
  - **Smart auto-tagging & categorization** (on-device labels/topics) that feed the
    existing tags + faceted filters/albums.
  - **Optional relationship/graph view** of the library (items linked by
    channel/topic/co-occurrence) — a visualization over existing metadata + the
    similarity index, not a new datastore requirement.
  - Embeddings/transcripts stay **on-device/free**; a cloud embedding/index path is
    only ever a **v3 credit** option, never required.
- **Graceful disabling**: features the device can't run are clearly disabled with a
  friendly reason — never a crash, never a silent no-op.
**Exit criteria:** on a capable device, transcribe + summarize a saved item fully
offline; on a low-end device those features are cleanly disabled with explanation.

## P13 — Production Polish (public v2)
**Goals:** make the local-only app genuinely world-class and production-ready.
**Deliverables:** accessibility, complete i18n, performance hardening, advanced
configuration, refined UX across all flows, robust update/onboarding, public v2
release candidate (Android + Windows, still local-only, still free).
- **Authenticated/private content** (deferred from v1): per-site **cookie/login
  import** so users can download their own private/age-gated/followers-only media,
  with cookies stored via `flutter_secure_storage`. Stays on-device — no account,
  no cloud, still free.
**Exit criteria:** v2 is stable, polished, and self-recommending; ready for wider
(still off-store) distribution. **→ v2 complete.**

---

# v3 — Cloud AI + monetization

## P14 — Backend + Accounts
**Goals:** the paid rails (cloud only).
**Deliverables:** Supabase Auth; Postgres credit ledger + RLS (SPEC §9.1); Edge
Functions skeleton; **Stripe/PayPal** checkout + webhooks → credit grants; account +
credits UI. The local-only experience stays fully account-free.
**Exit criteria:** buy credits via Stripe/PayPal in a test env; balance updates via
webhook; RLS verified.

## P15 — Cloud AI
**Goals:** heavier multimodal AI for tasks/devices beyond on-device limits.
**Deliverables:**
- Cloud `InferenceEngine` impl behind the same interface; **Genkit → Gemini** Edge
  Functions with credit metering + rate limits.
- Model selector surfaces **Free — Local** vs **Cloud (credits)**; optional cloud
  fallback for incapable devices.
- Cloud feature set: richer summarization, vision Q&A, high-quality
  transcription/translation, generative thumbnails/clips.
**Exit criteria:** a feature runs **free locally** on a capable device and via
**cloud (credits)** for higher quality; cost-per-call < credit price.

## P16 — Launch
**Goals:** public availability + growth.
**Deliverables:** landing/download site (Android APK/AAB + Windows MSIX), install
guides + legal disclaimer, versioned releases/changelog, basic marketing,
release/update channel. Add repo `README`.
**Exit criteria:** public download links live; update flow works end-to-end.

---

## Cross-Cutting Conventions
- Every phase: keep CI green; update affected docs in the same commit; conventional
  commits on `claude/init-grabbit-setup-RaBUs` (until told otherwise).
- Conserve Actions minutes: auto CI = lint/analyze/test on ubuntu; APK/Windows
  builds are **manual/tagged** and batched (CLAUDE.md §6).
- Privacy/legal posture (PRD §13) holds throughout: on-device-free, cloud-credits,
  no ads, no telemetry, user-responsibility disclaimer.
