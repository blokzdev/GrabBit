# GrabBit — Multi-Phase Roadmap

Status: Draft v0.2 · Last updated: 2026-05-20

Phased delivery plan for end-to-end agentic DevOps. Each phase has **Goals**,
**Deliverables**, **Exit criteria**, and **CI/build notes**. Phases are sequential
by default; later phases assume earlier exit criteria are met.

Legend (three version bands):
- **v1 — Android core, free, on-device:** P0–P4.
- **v2 — world-class, feature-rich, production-ready, LOCAL-ONLY (no cloud):**
  P5 (Windows parity) · P6 (edge/local AI) · P7 (production polish).
- **v3 — cloud AI + credit monetization:** P8 (backend + accounts) · P9 (cloud AI)
  · P10 (public launch).

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
(cookie/login import) is deferred to **v2** (see P7).
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

## P4 — Polish + v1 Beta
**Goals:** stability + UX quality for daily use.
**Deliverables:** robust error UX + retries, performance tuning (lists, thumbnails),
naming templates, Wi-Fi-only, theming polish, empty/loading states, i18n
scaffolding. Internal beta APK distribution.
**Exit criteria:** founder uses GrabBit as a daily driver; no critical bugs;
crash-free across top sites. **→ v1 complete.**

---

# v2 — World-class, local-only (Windows + edge AI + polish)

## P5 — Windows Port
**Goals:** second platform with zero domain/UI rewrite.
**Deliverables:** `WindowsProcessEngine` (bundled `yt-dlp.exe`/`ffmpeg.exe`),
desktop storage adapter (filesystem export), desktop-adapted UI, **MSIX** packaging,
binary update path.
**Exit criteria:** Windows build downloads + manages media; feature parity with v1
core. **CI note:** windows runners = 2x minutes — build Windows manually/on tags.

## P6 — Edge/Local AI (free, on-device)
**Goals:** the differentiator — on-device AI with graceful capability-gating. **No
cloud, no account, no credits.**
**Deliverables:**
- **DeviceCapabilityService** + device tiers; **ModelCapabilityMatrix**.
- `InferenceEngine` with on-device impls: **LiteRT / MediaPipe LLM** (Gemma-class),
  **whisper.cpp** (transcription), **ML Kit** (OCR/translation/labeling).
- **On-demand model download** + integrity check + caching (keeps install lean).
- First local feature set: transcription, summarization, translation, OCR, smart
  tagging / semantic search.
- **Graceful disabling**: features the device can't run are clearly disabled with a
  friendly reason — never a crash, never a silent no-op.
**Exit criteria:** on a capable device, transcribe + summarize a saved item fully
offline; on a low-end device those features are cleanly disabled with explanation.

## P7 — Production Polish (public v2)
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

## P8 — Backend + Accounts
**Goals:** the paid rails (cloud only).
**Deliverables:** Supabase Auth; Postgres credit ledger + RLS (SPEC §9.1); Edge
Functions skeleton; **Stripe/PayPal** checkout + webhooks → credit grants; account +
credits UI. The local-only experience stays fully account-free.
**Exit criteria:** buy credits via Stripe/PayPal in a test env; balance updates via
webhook; RLS verified.

## P9 — Cloud AI
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

## P10 — Launch
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
