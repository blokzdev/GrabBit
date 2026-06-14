# GrabBit

A free, privacy-first, multi-platform social-media downloader, **private media
manager**, and **on-device AI library**. Paste a link (YouTube, Instagram, TikTok,
X, …) and GrabBit downloads the media **on-device** using yt-dlp + ffmpeg. Downloads
stay in a private in-app library by default; exporting to the device gallery is
always an explicit choice. On-device AI + a relationship graph make the library
searchable and self-organizing — no cloud, no accounts.

> **The vision (P14 — the [Things Engine](docs/things-engine.md)):** GrabBit grows from a media library
> into a typed, interlinked graph of on-device **schema.org artifacts** (recipes, events, places, …),
> captured and reasoned over fully on-device. It's a scheduled v1 phase, building on the AI/graph pillar.

**Platforms:** Android first (sideload APK/AAB, off the Play Store), then **Windows** (P15).

## Core principle

> **Everything is on-device, and on-device = FREE, forever.**
> Downloads, media manager, playback, metadata, app lock, and all on-device AI + the
> relationship graph run on your own device, cost nothing, and are free forever.
> Sustained by an optional donations link. **No ads, no telemetry, no cloud, no accounts.**

## Roadmap — one band, the full vision (P0–P17)

GrabBit ships as a single **v1** band — the complete envisioned product — and **launches last**, so the
first public release is the full scope:

- **Core downloader + private media manager** (P0–P9)
- **On-device AI + relationship-graph pillar** (P10, P12–P13) + the **Activity Inbox** (P11)
- **Things Engine** (P14) — the typed schema.org artifact graph
- **Windows parity** (P15)
- **Production polish + authenticated/cookie import** (P16)
- **Beta, production readiness & launch** (P17) — last

*(AI is core to the vision, so the launch phase is last. The previously planned v3 cloud/credits band is
**dropped** — GrabBit is free forever and fully offline.)* See [`docs/ROADMAP.md`](docs/ROADMAP.md).

## Tech stack

Flutter · Riverpod · go_router · Drift (SQLite) · Pigeon · youtubedl-android
(Android engine) · **CozoDB** (on-device graph + vector index) · **flutter_gemma**
(on-device AI: embeddings + LLM + RAG) · Material 3. See [`docs/`](docs) for the
full design.

## Develop

```bash
flutter pub get
dart run build_runner build          # Riverpod/Drift codegen
dart format --set-exit-if-changed .  # CI gate
flutter analyze                      # CI gate
flutter test                         # CI gate
flutter build apk --debug            # debug APK
```

CI runs format → analyze → test on every push/PR. APK builds are manual
(`build-apk.yml`, `workflow_dispatch`).

## Documentation

- [`CLAUDE.md`](CLAUDE.md) — agent/contributor operating guide (start here)
- [`docs/PRD.md`](docs/PRD.md) — product requirements
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — system design
- [`docs/SPEC.md`](docs/SPEC.md) — technical spec
- [`docs/GRAPH-SPEC.md`](docs/GRAPH-SPEC.md) — on-device graph + vector DB (CozoDB)
- [`docs/AI-SPEC.md`](docs/AI-SPEC.md) — on-device edge-AI design
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — phased delivery plan
- [`docs/things-engine.md`](docs/things-engine.md) — the **Things Engine** (P14 vision: a typed,
  on-device artifact library)
- [`docs/decisions/`](docs/decisions) — Architecture Decision Records (ADR-0001–0004)

## Legal

GrabBit is a **general-purpose downloader**; the user is solely responsible for
complying with the terms of service and copyright law of the sites they use, and
for only downloading content they have the right to. GrabBit hosts **no** copyrighted
content, ships **no** pre-loaded media, and is **not** designed to circumvent any
technical protection or DRM. It orchestrates the open-source `yt-dlp` + `ffmpeg`
tools entirely on-device.

## License

Licensed under the **[GNU General Public License v3.0](LICENSE)** — © 2026 blokzdev (GrabBit). You may
use, study, share, and modify GrabBit under the GPL-3.0 terms; derivative works must stay free and open
under the same license.

Bundled and linked third-party components (ffmpeg, yt-dlp, Python, CozoDB, …) keep their own licenses —
see [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
