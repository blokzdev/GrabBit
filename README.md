# GrabBit

A free, privacy-first, multi-platform social-media downloader, **private media
manager**, and **on-device AI library**. Paste a link (YouTube, Instagram, TikTok,
X, …) and GrabBit downloads the media **on-device** using yt-dlp + ffmpeg. Downloads
stay in a private in-app library by default; exporting to the device gallery is
always an explicit choice. On-device AI + a relationship graph make the library
searchable and self-organizing — no cloud, no accounts.

**Platforms:** Android first (sideload APK/AAB, off the Play Store). Windows in v2.

## Core principle

> **Everything is on-device, and on-device = FREE, forever.**
> Downloads, media manager, playback, metadata, app lock, and all on-device AI + the
> relationship graph run on your own device, cost nothing, and are free forever.
> Sustained by an optional donations link. **No ads, no telemetry, no cloud, no accounts.**

## Version bands

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Android, free, on-device, **AI-powered**: downloader + private media manager, then the on-device AI + relationship-graph pillar (P10–P12), then beta & launch (P13) | Offline | Free |
| **v2** | Local-only expansion: Windows parity + production polish + authenticated/cookie import | Offline | Free |

*(AI is core to the vision, so v1 ships **after** the AI work. The previously planned
v3 cloud/credits band is **dropped**.)*

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

## Legal

GrabBit is a general-purpose downloader; the user is responsible for complying with
the terms of service and copyright law of the sites they use. GrabBit hosts no
copyrighted content and ships no pre-loaded media.

All rights reserved. This project is proprietary and is intentionally published
without an open-source license; no rights to use, copy, modify, or distribute are
granted.
