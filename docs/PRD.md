# GrabBit — Product Requirements Document (PRD)

Status: Draft v0.2 · Owner: Founder/Architect · Last updated: 2026-05-20

> Product-level "what & why." For system design see `ARCHITECTURE.md`; for
> implementation detail see `SPEC.md`; for delivery sequencing see `ROADMAP.md`.

---

## 1. Problem & Opportunity

People constantly want to keep media they find on social platforms — a tutorial
video, a reel, a thread of images — but the experience is fragmented: ad-ridden,
sketchy websites, single-site tools, paywalls, and downloads that dump straight
into the camera roll mixed with personal photos.

**Opportunity:** a clean, trustworthy, **free, on-device** downloader that doubles
as a **private media manager** — downloads stay organized and private inside the
app until *you* decide to export them. Monetize later, honestly, via genuinely
valuable cloud AI features rather than ads.

## 2. Vision

> GrabBit is the private, no-nonsense home for everything you save from the web —
> free to download and manage on your device forever, with optional AI superpowers
> when you want them.

**North star:** the cleanest, most private, most capable media downloader/manager
a normal person can sideload and trust.

## 3. Version Strategy (three bands)

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Core on-device downloader + private media manager (Android). | Offline | Free |
| **v2** | World-class, feature-rich, production-ready, **local-only**: Windows parity + **edge/local AI** with graceful capability-gating. | Offline | Free |
| **v3** | Introduce **Supabase** backend + **Gemini** cloud AI; **credit-based** monetization (Stripe/PayPal) for cloud-only features. | Online (opt-in) | Credits |

The app stays fully free and offline through v2. Money enters only in v3, and only
for features that spend our money on cloud APIs. **No ads, ever.**

## 4. Target Users & Personas

- **The Saver** — saves videos/reels/images for later; wants them organized and
  private, not cluttering the gallery. Lives in Simple mode.
- **The Archivist / Power User** — bulk-downloads playlists/channels/threads; cares
  about formats, codecs, metadata, subtitles, storage control. Lives in Advanced mode.
- **The Privacy-conscious user** — wants downloads off the gallery and behind a
  lock; no telemetry, no account.
- **The Creator/Researcher (v2+)** — transcribes/summarizes/translates/searches
  saved media; benefits from on-device AI, opts into cloud AI later.

No account is required for v1/v2. Accounts appear only in v3 (for credits).

## 5. Value Proposition

- **Free forever** for all on-device functionality. No ads. No spyware.
- **Private by default** — in-app library; export is a deliberate choice.
- **Powerful** — yt-dlp under the hood = broad site support, format control, bulk.
- **Honest monetization** — pay only for cloud AI that actually costs us money.

## 6. Top User Journeys

1. **Quick grab (Simple mode):** paste/share URL → app auto-picks best quality →
   one-tap download → appears in private library → play in-app.
2. **Precise grab (Advanced mode):** paste URL → probe formats → choose
   container/resolution/codec/audio-only/subtitles → download.
3. **Bulk grab:** paste a playlist/channel/multiple URLs → queue → monitor progress
   → batch completes with pause/resume/retry.
4. **Manage:** browse library, edit metadata/tags, rename, group, search, delete.
5. **Export:** select item(s) → "Save to device" into a chosen folder; OR enable
   "automatically store media to device" with a default destination.
6. **Lock:** enable PIN/biometric so the private library requires auth to open.
7. **(v2) Local AI:** transcribe/summarize/translate/OCR/auto-tag a saved item,
   fully on-device; greyed-out (and explained) on incapable devices.
8. **(v3) Cloud AI & credits:** sign in, buy credits, run heavier multimodal Gemini
   tools when on-device isn't enough.

## 7. Feature Set — v1 (all FREE, on-device)

### 7.1 Modes
- **Simple mode (default):** paste → best-quality download, minimal choices.
- **Advanced mode:** full format/quality/codec/subtitle/metadata control.
- Mode toggle in settings; per-download override. Share-sheet integration.

### 7.2 Downloading
- Single URL, multi-URL paste, playlist/channel expansion, bulk queue.
- Format probing (resolutions, codecs, audio-only, container).
- Progress (speed, ETA, %), pause/resume/cancel/retry; resilient across restarts.
- ffmpeg post-processing: merge video+audio, convert container, extract audio
  (MP3/M4A), embed thumbnail/metadata, trim — all local, all free.
- Subtitle/caption + thumbnail + metadata extraction.

### 7.3 Private media manager
- In-app library: grid/list, thumbnails, in-app video/audio player + image viewer.
- Metadata management: title, source URL, uploader, duration, date, resolution,
  tags, notes; edit/rename.
- Organization: collections/folders, search, filter, sort; bulk operations.
- Storage policy:
  - **Default:** app-private working directory (not in gallery).
  - **Manual export:** "Save to device" for selected items → chosen folder.
  - **Auto-store:** optional setting + default destination folder + collision policy.
- App lock: optional PIN (hashed) + biometric to open the app/library.

### 7.4 Configurability
- Default mode, default quality/format/container, download-location policy, filename
  templates, concurrency limit, network/metered-data policy, notification behavior,
  theme (light/dark/system + dynamic color), language (i18n-ready).

## 8. Feature Set — v2 (Local/Edge AI, FREE; + Windows; + polish)

### 8.1 Adaptive AI tiering (the differentiator)
At first run (and on demand), GrabBit runs a **device-capability diagnostic** (RAM,
SoC/NPU/GPU, OS version, free storage) to compute a **device tier**. A **capability
matrix** maps each AI feature to the local model(s) the device can run. Features the
device can't support are **gracefully disabled** with a clear, friendly explanation —
never a crash, never a silent no-op. On-device models are **downloaded on demand**
(not bundled) to keep the install lean.

### 8.2 Local AI features (on-device, free)
- **Transcription** (whisper.cpp): audio/video → text/subtitles.
- **Summarization** (local small LLM via LiteRT/MediaPipe): TL;DR, chapters.
- **Translation & OCR** (ML Kit): translate transcripts; text from images.
- **Smart tagging / semantic search**: on-device labeling + embeddings.

### 8.3 Windows + production polish
- Windows app at parity behind the shared engine (Process-based yt-dlp/ffmpeg).
- Accessibility, i18n, performance hardening, advanced configuration, deep polish
  toward a public v2 (still local-only, still free).

## 9. Feature Set — v3 (Cloud AI + credits)

- Accounts (Supabase Auth) — needed only for cloud AI / credits.
- Heavier multimodal **Gemini** tools (richer summarization, vision Q&A, high-quality
  transcription/translation, generative thumbnails/clips) for tasks/devices beyond
  on-device limits.
- Optional **cloud fallback** for incapable devices, behind the same
  `InferenceEngine`.
- Credit ledger; each cloud call meters real cost. Top-ups via **Stripe/PayPal**;
  webhook → credit grant. Local AI never requires an account or credits.

## 10. Monetization Model

**Principle: on-device = free, cloud = credits.** No ads, ever.

| Capability | v1 | v2 | v3 | Cost |
|---|---|---|---|---|
| Downloads (all platforms), queue, bulk | ✅ | ✅ | ✅ | Free |
| Private library, player, metadata, organization | ✅ | ✅ | ✅ | Free |
| Local ffmpeg/yt-dlp tools (convert, extract audio, trim, thumbnails) | ✅ | ✅ | ✅ | Free |
| Storage policy, export, auto-store | ✅ | ✅ | ✅ | Free |
| App lock (PIN/biometric) | ✅ | ✅ | ✅ | Free |
| Windows app | — | ✅ | ✅ | Free |
| Local/edge AI (transcribe, summarize, OCR, translate, tag) | — | ✅ | ✅ | Free |
| Cloud AI (Gemini multimodal) | — | — | ✅ | **Credits** |
| Accounts / credit purchase (Stripe/PayPal) | — | — | ✅ | — |

Off-store distribution means Google Play Billing is unavailable; v3 credits are sold
via Stripe/PayPal and tracked in a Supabase credit ledger.

## 11. Non-Goals

- Not on the Google Play Store (YouTube support precludes it).
- No iOS in foreseeable scope (sideloading constraints).
- No server-side downloading/hosting of media (privacy + legal + cost).
- No cloud sync of the user's library (media stays on-device).
- No social/sharing network; GrabBit is a personal tool.
- No ads or tracking.

## 12. Success Metrics

- **v1:** stable downloads across top sites; crash-free sessions; download success
  rate; time-to-first-download; retention of the private-library habit.
- **v2:** Windows parity; % devices eligible for local AI; correct capability-gating
  (zero AI crashes on low-end devices); local-AI feature adoption.
- **v3:** credit conversion rate; cloud-AI task success; gross margin per credit
  (price must comfortably exceed Gemini cost).

(Metrics measured locally/voluntarily; no covert analytics.)

## 13. Legal & Risk

- **User responsibility:** in-app + landing-site disclaimer that users must respect
  site ToS and copyright. GrabBit ships/hosts no copyrighted content.
- **Distribution:** off-Play-Store (sideload APK/AAB + landing site) due to YouTube;
  document install steps + "unknown sources" guidance. Windows via direct download/MSIX.
- **Ad networks avoided** deliberately — most ban downloader apps and compromise
  privacy; the AI-credit model (v3) replaces ad revenue.
- **Site fragility:** extractors break when sites change; mitigate with a
  user-updatable yt-dlp and clear errors. Engine stays swappable.
- **Backend cost control (v3):** cloud AI must be credit-gated and rate-limited so
  cost never exceeds revenue; keys only server-side (Supabase secrets).
- **Payments/compliance (v3):** Stripe/PayPal handle PCI; store no card data.
- **Repo stays private** (YouTube downloader); CI budget managed accordingly.

## 14. Open Questions (track, not blocking)

- Exact v2 local-AI feature shortlist and per-tier model choices (Gemma sizes,
  whisper variants, ML Kit coverage).
- v3 credit pricing and cloud cost ceilings.
- Whether any paid non-AI tier ever appears (currently none — core stays free).
