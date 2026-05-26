# GrabBit — Product Requirements Document (PRD)

Status: Draft v0.3 · Owner: Founder/Architect · Last updated: 2026-05-24

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
app until *you* decide to export them — with **on-device AI + a relationship graph**
that make the private library genuinely smart. **Free forever**, sustained by
optional donations rather than ads or cloud fees.

## 2. Vision

> GrabBit is the private, no-nonsense home for everything you save from the web —
> free to download, manage, and *understand* on your device forever, with on-device
> AI and a relationship graph that surface connections across your library. No cloud,
> no accounts, no ads.

**North star:** the cleanest, most private, most capable media downloader/manager
a normal person can sideload and trust.

## 3. Version Strategy (two bands — v3/cloud dropped)

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Android, free, on-device, **AI-powered**: downloader + private media manager (P0–P9), then the **on-device AI + relationship-graph pillar** (P10, P12–P13), then beta & launch (P14). | Offline | Free |
| **v2** | Local-only expansion: Windows parity (P15) + production polish & authenticated/cookie import (P16). | Offline | Free |

The app is **free forever and fully offline**, sustained by an **optional donations link**. **No
ads, no telemetry, no cloud, no accounts — ever.** AI is core to the vision, so **v1 ships *after*
the AI work**. (The former **v3** cloud-AI/credit band is **dropped**.)

## 4. Target Users & Personas

- **The Saver** — saves videos/reels/images for later; wants them organized and
  private, not cluttering the gallery. Lives in Simple mode.
- **The Archivist / Power User** — bulk-downloads playlists/channels/threads; cares
  about formats, codecs, metadata, subtitles, storage control. Lives in Advanced mode.
- **The Privacy-conscious user** — wants downloads off the gallery and behind a
  lock; no telemetry, no account.
- **The Creator/Researcher** — transcribes/summarizes/translates/searches saved media and explores
  how items relate (graph/"related"/hubs); all **on-device** AI, free.

**No account is ever required** — there is no cloud and no credits.

## 5. Value Proposition

- **Free forever** for all functionality — everything is on-device. No ads. No spyware.
- **Private by default** — in-app library; export is a deliberate choice.
- **Powerful** — yt-dlp under the hood = broad site support, format control, bulk.
- **Smart, privately** — on-device AI + a relationship graph (semantic search, "related", hubs,
  local "ask your library") that never leave the device.
- **Donation-supported** — optional donations, never ads or cloud fees.

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
7. **Local AI (P10, P12–P13):** transcribe/summarize/translate/OCR/auto-tag a saved item, fully
   on-device; greyed-out (and explained) on incapable devices.
8. **Graph & discovery (P10, P12–P13):** see **related items**, explore an uploader/tag **hub** or the
   interactive **graph view**, get **clustered auto-albums** and **"rediscover"** picks, and **ask
   your library** a natural-language question (local GraphRAG) — all on-device.

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
- Organization — two coexisting views:
  - **Library view:** collections (many-to-many) + tags, search, filter, sort; bulk
    operations.
  - **Explorer view (P5):** a Dropbox-like virtual file system — nested
    folders/subfolders, move/rename, breadcrumbs — over the on-device library
    (files stay private; folders are virtual, so nothing is re-arranged on disk).
- **Media editing (P6):** on-device, free ffmpeg-powered tools — trim, reverse,
  flip/mirror/rotate, convert (container/codec/audio-extract), and frame extraction
  (first/last/any frame → image) for video and images. Edits produce new library
  items; originals are preserved.
- Storage policy:
  - **Default:** app-private working directory (not in gallery).
  - **Manual export:** "Save to device" for selected items → chosen folder.
  - **Auto-store:** optional setting + default destination folder + collision policy.
- App lock: optional PIN (hashed) + biometric to open the app/library.

### 7.4 Configurability
- Default mode, default quality/format/container, download-location policy, filename
  templates, concurrency limit, network/metered-data policy, **notification behavior**
  (Activity Inbox retention + per-category toggles, §7.5), theme (light/dark/system +
  dynamic color), language (i18n-ready).

### 7.5 Activity Inbox & notifications (P11, device-universal)
A single, persisted, **on-device** feed for everything the app does in the background or wants to
tell the user — download outcomes, transcript/backfill results, AI/graph activity, errors,
capability-gated "disabled because…" notices, reminders, status updates, and actionable items.
- Surfaced via an app-bar **bell with an unread badge** + a dedicated **Inbox** screen (grouped,
  filterable by category, tap → deep-link to the relevant item/screen, swipe-to-dismiss,
  mark-all-read, clear) + a Dashboard recent-activity tile.
- **Configurable retention:** items auto-clear after N days (configurable; can be set to keep
  forever), plus optional per-category notify toggles.
- **Privacy-first:** entirely local — no telemetry, no push, no cloud, no accounts — and behind the
  app lock. Complements the existing OS/foreground notifications (the inbox is the durable in-app
  record; OS notifications remain the while-backgrounded channel).

## 8. Feature Set — On-device AI + Relationship Graph (v1, P10, P12–P13, FREE)

The differentiating pillar, all on-device and free. Deep design: `docs/AI-SPEC.md`,
`docs/GRAPH-SPEC.md`; delivery: `docs/design/P-AI-PLAN.md`.

### 8.1 On-device graph + vector foundation (P10, device-universal)
A bundled **CozoDB** engine (relational+graph+vector) holds a **derived, rebuildable index** of the
library (Drift stays canonical). A lightweight on-device **embedder** powers semantic features. Runs
on *any* device. Features: **semantic search**, **Related / "More like this"**, **entity hubs**
(uploader/playlist/tag/site), **near-duplicate clusters**, **tag suggestions**, an **interactive
graph view**, and a pure-Dart **extractive summary** floor (TextRank).

### 8.2 Adaptive AI tiering (P12)
At first run (and on demand), GrabBit runs a **device-capability diagnostic** (RAM, SoC/NPU/GPU, OS
version, free storage) to compute a **device tier**. A **capability matrix** maps each AI feature to
the local model(s) the device can run; unsupported features are **gracefully disabled** with a
clear, friendly explanation — never a crash, never a silent no-op (these capability-gating notices,
like model downloads and other background AI activity, surface in the **Activity Inbox**, §7.5).
Models are **downloaded on
demand** (not bundled) to keep the install lean. Runtime: **`flutter_gemma`** (MediaPipe/LiteRT-LM).

### 8.3 LLM features + local GraphRAG (P13)
- **Transcription** (whisper.cpp): audio/video → text/subtitles.
- **Summarization** (local small LLM, layered on the TextRank floor): TL;DR, chapters.
- **Translation & OCR** (ML Kit): translate transcripts; text from images.
- **Smart tagging**: on-device labeling feeding the existing tags/facets.
- **Graph-clustered auto-albums**, centrality-based **"Rediscover"**, **path/bridge** discovery.
- **"Ask your library"** — natural-language Q&A as **local GraphRAG** (Cozo retrieval + local LLM),
  fully on-device.

## 9. Feature Set — v2 (local-only expansion)

- **Windows** app at parity behind the shared engine (Process-based yt-dlp/ffmpeg; Cozo via the
  C-API/FFI `GraphStore` impl). Accessibility, complete i18n, performance hardening, advanced
  configuration, deep polish.
- **Authenticated/private content** (deferred from v1): per-site cookie/login import, stored via
  `flutter_secure_storage` — still on-device, no account, free.

*(The former **v3** cloud-AI + credit band — Supabase accounts, Gemini, Stripe/PayPal — is
**dropped**. The `InferenceEngine` interface keeps a theoretical cloud seam, but it is unplanned.)*

## 10. Monetization Model

**Principle: everything is on-device, and on-device = free, forever.** Sustained by an **optional
donations link**. **No ads, no telemetry, no cloud, no accounts — ever.**

| Capability | v1 | v2 | Cost |
|---|---|---|---|
| Downloads (all platforms), queue, bulk | ✅ | ✅ | Free |
| Private library, player, metadata, organization | ✅ | ✅ | Free |
| Local ffmpeg/yt-dlp tools (convert, extract audio, trim, thumbnails) | ✅ | ✅ | Free |
| Storage policy, export, auto-store | ✅ | ✅ | Free |
| App lock (PIN/biometric) | ✅ | ✅ | Free |
| On-device AI + relationship graph (semantic search, related, hubs, transcribe, summarize, OCR, translate, tag, local GraphRAG) | ✅ | ✅ | Free |
| Windows app | — | ✅ | Free |
| Authenticated/cookie import | — | ✅ | Free |
| Optional donations | ✅ | ✅ | — |

Off-store distribution means Google Play Billing is unavailable; there are no in-app purchases —
support is via an optional external donations link only.

## 11. Non-Goals

- Not on the Google Play Store (YouTube support precludes it).
- No iOS in foreseeable scope (sideloading constraints).
- No server-side downloading/hosting of media (privacy + legal + cost).
- No cloud sync of the user's library (media stays on-device).
- No social/sharing network; GrabBit is a personal tool.
- No ads or tracking.

## 12. Success Metrics

- **v1 (core):** stable downloads across top sites; crash-free sessions; download success rate;
  time-to-first-download; retention of the private-library habit.
- **v1 (AI + graph):** % devices eligible for each AI tier; correct capability-gating (zero AI
  crashes on low-end devices); adoption of related/search/graph/"ask your library".
- **v2:** Windows parity; authenticated-content adoption.

(Metrics measured locally/voluntarily; no covert analytics.)

## 13. Legal & Risk

- **User responsibility:** in-app + landing-site disclaimer that users must respect
  site ToS and copyright. GrabBit ships/hosts no copyrighted content.
- **Distribution:** off-Play-Store (sideload APK/AAB + landing site) due to YouTube;
  document install steps + "unknown sources" guidance. Windows via direct download/MSIX.
- **Ad networks avoided** deliberately — most ban downloader apps and compromise privacy. There is
  no ad or cloud revenue; the project is supported by **optional donations** only.
- **AI model licensing:** since GrabBit is distributed off-store, bundled/downloaded models must be
  cleanly redistributable — **prefer Apache-2.0/MIT** (e.g. Qwen3, SmolLM, Phi); **vet Gemma's use
  policy** before shipping. (See `docs/AI-SPEC.md` §4.) CozoDB is **MPL-2.0** (linked, not modified
  → no obligation on our code; see `docs/GRAPH-SPEC.md` §1).
- **Site fragility:** extractors break when sites change; mitigate with a
  user-updatable yt-dlp and clear errors. Engine stays swappable.
- **Repo stays private** (YouTube downloader); CI budget managed accordingly.

## 14. Open Questions (track, not blocking)

- Exact per-tier model choices (light/mid LLM, embedder dim, whisper variant) — confirmed at P12
  start per `docs/AI-SPEC.md` §4.
- APK-size budget impact of the Cozo native lib (measured in the first P10 APK build).
- Donations provider/link for the About screen (P14).
