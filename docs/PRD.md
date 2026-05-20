# GrabBit — Product Requirements Document (PRD)

Status: Draft v0.1 · Owner: Founder/Architect · Last updated: 2026-05-20

---

## 1. Problem & Opportunity

People constantly want to keep media they find on social platforms — a tutorial
video, a reel, a thread of images — but the experience is fragmented, ad-ridden,
sketchy (shady websites), or locked behind paywalls. Existing downloaders are
either single-site, full of ads/malware, or dump files straight into the gallery
with no organization.

**Opportunity:** a clean, trustworthy, **free** downloader that doubles as a
**private media manager** — your downloads stay organized and private inside the
app until *you* decide to export them. Monetize later, honestly, via genuinely
valuable cloud AI features rather than ads.

## 2. Vision

> GrabBit is the private, no-nonsense home for everything you save from the web —
> free to download and manage on your device forever, with optional AI superpowers
> when you want them.

## 3. Target Users

- **The Saver** — saves videos/reels/images for later; wants them organized and
  private, not cluttering the phone gallery.
- **The Power User** — bulk downloads playlists/channels, cares about format,
  quality, codecs, metadata, subtitles.
- **The Creator/Researcher** — collects reference media; later wants AI tools
  (transcripts, summaries, search) over their library.

## 4. Value Proposition

- **Free forever** for all on-device functionality. No ads. No spyware.
- **Private by default** — in-app library; export is a deliberate choice.
- **Powerful** — yt-dlp under the hood = broad site support, format control, bulk.
- **Honest monetization** — pay only for cloud AI that actually costs us money.

## 5. Personas → Top User Journeys

1. **Quick grab (Simple mode):** paste URL → app auto-picks best quality →
   one-tap download → appears in private library → play in-app.
2. **Precise grab (Advanced mode):** paste URL → probe formats → choose
   container/resolution/codec/audio-only/subtitles → download.
3. **Bulk grab:** paste a playlist/channel/multiple URLs → queue → monitor
   progress → batch completes.
4. **Manage:** browse library, edit metadata/tags, rename, group, search, delete.
5. **Export:** select item(s) → "Save to device" into a chosen gallery folder; OR
   enable "Automatically store media to device" with a default folder.
6. **Lock:** enable PIN/biometric so the private library requires auth to open.

## 6. Feature Set (v1 — all FREE, on-device)

### 6.1 Modes
- **Simple mode (default):** paste → best-quality download, minimal choices.
- **Advanced mode:** full format/quality/codec/subtitle/metadata control.
- Mode toggle in settings; per-download override.

### 6.2 Downloading
- Single URL, multi-URL paste, playlist/channel expansion, bulk queue.
- Format probing (resolutions, codecs, audio-only, container).
- Progress (speed, ETA, %), pause/resume/cancel/retry.
- ffmpeg post-processing: merge video+audio, convert container, extract audio
  (e.g. MP3/M4A), embed thumbnail/metadata, trim (local tool).
- Subtitle/caption + thumbnail + metadata extraction.

### 6.3 Private Media Manager
- In-app library with grid/list, thumbnails, in-app video/image player.
- Metadata management: title, source, tags, notes, date; edit/rename.
- Organization: collections/folders, search, filter, sort.
- Storage policy:
  - **Default:** files stored in app-private working directory (not in gallery).
  - **Manual export:** "Save to device" for selected items → chosen folder.
  - **Auto-store:** optional setting + default destination folder.
- App lock: optional PIN + biometric to open the app/library.

### 6.4 Configurability
- Default mode, default quality/format, download location policy, naming
  templates, concurrent download limit, theme (light/dark/system + dynamic color),
  language (i18n-ready), Wi-Fi-only downloads.

## 7. v2 — Credit-Based AI (Cloud) + Free Local AI

### 7.1 Adaptive AI Tiering (the differentiator)
At first run (and on demand), GrabBit runs a **device capability diagnostic**
(RAM, SoC/NPU/GPU, OS version, free storage) to compute a **device tier**. A
**model capability matrix** maps each AI feature to the local models (if any) the
device can run vs cloud-only models. The **model selector** then offers, per
feature:
- **Free — Local** (on-device via LiteRT) when the device qualifies — costs nothing.
- **Cloud (credits)** for higher quality / heavier multimodal — costs credits.
Features with no viable local model are **cloud-only** by necessity.
On-device models are **downloaded on demand** (not bundled) to keep the APK lean.

### 7.2 Candidate AI features
- Transcription (local: whisper-class; cloud: Gemini for quality/long media).
- Summarization & key-moments / chapters.
- Smart tagging + semantic search over the library.
- Translation / subtitle translation.
- Generative tools (thumbnails, clips, reframing) — likely cloud-only.

### 7.3 Accounts, credits, payments
- Supabase Auth (account needed only for cloud AI / credits).
- Credit ledger; each cloud call meters real cost.
- Top-ups via Stripe/PayPal; webhook → credit grant.
- Local AI never requires an account or credits.

## 8. Monetization Model

**Principle: on-device = free, cloud = credits.**

| Capability | Tier |
|---|---|
| All downloading (any site yt-dlp supports) | Free |
| Bulk / playlist / queue | Free |
| Private library, player, metadata, organization, search (non-AI) | Free |
| Local ffmpeg/yt-dlp tools (convert, extract audio, trim, thumbnails) | Free |
| App lock (PIN/biometric) | Free |
| **On-device AI** (LiteRT local models) where device supports | **Free** |
| **Cloud AI** (Gemini multimodal via backend) | **Credits** |

No ads, ever. No Play Billing (off-store) — payments via Stripe/PayPal in v2.

## 9. Non-Goals

- Not on the Google Play Store (YouTube support).
- No iOS in foreseeable scope (sideloading constraints).
- No server-side downloading/hosting of media (privacy + legal + cost).
- No social/sharing network; GrabBit is a personal tool.
- No ads or tracking.

## 10. Success Metrics

- v1: stable downloads across top sites; crash-free sessions; download success
  rate; time-to-first-download; retention of the private-library habit.
- v2: % devices eligible for free local AI; credit conversion; AI feature usage;
  cloud cost per active AI user (must stay below credit revenue).

## 11. Legal & Risk

- **User responsibility:** in-app + landing-site disclaimer that users must
  respect site ToS and copyright. GrabBit ships/hosts no copyrighted content.
- **Distribution:** off-Play-Store (sideload APK/AAB + landing site) due to
  YouTube; document install steps + "unknown sources" guidance.
- **Ad networks avoided** deliberately — most ban downloader apps and would
  compromise privacy; AI-credit model replaces ad revenue.
- **Site fragility:** extractors break when sites change; mitigate by bundling a
  user-updatable yt-dlp and surfacing clear errors.
- **Backend cost control (v2):** cloud AI must be credit-gated and rate-limited so
  cost never exceeds revenue; keys only server-side.
- **Payments/compliance (v2):** Stripe/PayPal handle PCI; store no card data.

## 12. Open Questions (track, not blocking)

- Exact v2 AI feature shortlist & credit pricing.
- Which local models per device tier (Gemma sizes, whisper variants).
- License/entitlement model if any paid non-AI tier ever appears (currently none).
