# GrabBit

A free, privacy-first, multi-platform social-media downloader and **private media
manager**. Paste a link (YouTube, Instagram, TikTok, X, …) and GrabBit downloads
the media **on-device** using yt-dlp + ffmpeg. Downloads stay in a private in-app
library by default; exporting to the device gallery is always an explicit choice.

**Platforms:** Android first (sideload APK/AAB, off the Play Store). Windows in v2.

## Core principle

> **On-device = FREE. Cloud = CREDITS.**
> Everything that runs on your own device — downloads, media manager, playback,
> metadata, app lock, and (v2) on-device AI — is free forever. Only features that
> spend our money on cloud APIs (v3) are credit-metered. No ads, ever.

## Version bands

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Core on-device downloader + private media manager (Android) | Offline | Free |
| **v2** | Windows parity + edge/local AI, production polish | Offline | Free |
| **v3** | Supabase backend + Gemini cloud AI, credit monetization | Online (opt-in) | Credits |

## Tech stack

Flutter · Riverpod · go_router · Drift (SQLite) · Pigeon · youtubedl-android
(Android engine) · Material 3. See [`docs/`](docs) for the full design.

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
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — phased delivery plan

## Legal

GrabBit is a general-purpose downloader; the user is responsible for complying with
the terms of service and copyright law of the sites they use. GrabBit hosts no
copyrighted content and ships no pre-loaded media.

All rights reserved. This project is proprietary and is intentionally published
without an open-source license; no rights to use, copy, modify, or distribute are
granted.
