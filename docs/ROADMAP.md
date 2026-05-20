# GrabBit — Multi-Phase Roadmap

Status: Draft v0.1 · Last updated: 2026-05-20

Phased delivery plan for end-to-end agentic DevOps. Each phase has **Goals**,
**Deliverables**, **Exit criteria**, and **CI/build notes**. Phases are
sequential by default; later phases assume earlier exit criteria are met.

Legend: **v1 = free, on-device, Android** (P0–P4) · **Windows** (P5) ·
**v2 = backend + AI** (P6–P7) · **Launch** (P8).

---

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
- **Save to device** (scoped MediaStore export) + **auto-store** setting + folder
  picker; `storage_state` tracking.
- **App lock** (PIN + biometric) with router gate.
- Settings screen (all defaults per SPEC §4).
**Exit criteria:** queue a few downloads, export selected items to gallery, lock
the app, reopen with PIN/biometric.

## P3 — Multi-Site + Bulk
**Goals:** breadth + scale.
**Deliverables:**
- Instagram, TikTok, X (and more yt-dlp supports) verified; clear errors for
  unsupported/broken extractors.
- **Bulk**: playlist/channel expansion, multi-URL paste, batch import.
- Subtitles/captions, thumbnail, full metadata extraction + embedding.
- User-triggered **yt-dlp self-update**.
**Exit criteria:** bulk-download a playlist and multiple cross-site URLs reliably.

## P4 — Polish + Internal Beta
**Goals:** stability + UX quality for daily use.
**Deliverables:** robust error UX + retries, performance tuning (lists, thumbnails),
naming templates, Wi-Fi-only, theming polish, empty/loading states, i18n
scaffolding. Internal beta APK distribution.
**Exit criteria:** founder uses GrabBit as a daily driver; no critical bugs;
crash-free across top sites.

## P5 — Windows Port
**Goals:** second platform with zero domain/UI rewrite.
**Deliverables:** `WindowsProcessEngine` (bundled `yt-dlp.exe`/`ffmpeg.exe`),
desktop storage adapter (filesystem export), desktop-adapted UI, **MSIX**
packaging, binary update path.
**Exit criteria:** Windows build downloads + manages media; feature parity with v1
core. **CI note:** windows runners = 2x minutes — build Windows manually/on tags.

## P6 — v2 Backend + Accounts
**Goals:** the paid rails (cloud only).
**Deliverables:** Supabase Auth; Postgres credit ledger + RLS (SPEC §9.1); Edge
Functions skeleton; **Stripe/PayPal** checkout + webhooks → credit grants; account
+ credits UI. Local-only experience stays account-free.
**Exit criteria:** buy credits via Stripe/PayPal in a test env; balance updates via
webhook; RLS verified.

## P7 — v2 AI Features (Cloud + Free Local)
**Goals:** the differentiator — adaptive AI tiering.
**Deliverables:**
- **DeviceCapabilityService** + tiers; **ModelCapabilityMatrix**; **model selector**
  (Free—Local vs Cloud).
- `InferenceEngine` with **LiteRT** primary (MediaPipe LLM for Gemma-class;
  whisper.cpp/ONNX where better); **on-demand model download** + caching.
- Cloud AI via Genkit→Gemini Edge Functions with credit metering + rate limits.
- First feature set: transcription, summarization, smart tagging/semantic search,
  translation; generative tools as cloud-only.
**Exit criteria:** a feature runs **free locally** on a capable device and via
**cloud (credits)** for higher quality; cost-per-call < credit price.

## P8 — Launch
**Goals:** public availability + growth.
**Deliverables:** landing/download site (Android APK/AAB + Windows MSIX), install
guides + legal disclaimer, versioned releases/changelog, basic marketing,
release/update channel. Add repo `README`.
**Exit criteria:** public download links live; update flow works end-to-end.

---

## Cross-Cutting Conventions
- Every phase: keep CI green; update affected docs in the same PR; conventional
  commits on `claude/init-grabbit-setup-RaBUs` (until told otherwise).
- Conserve Actions minutes: auto CI = lint/analyze/test on ubuntu; APK/Windows
  builds are **manual/tagged** and batched (CLAUDE.md §6).
- Privacy/legal posture (PRD §11) holds throughout: on-device-free, cloud-credits,
  no ads, no telemetry, user-responsibility disclaimer.
