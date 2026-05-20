# CLAUDE.md — GrabBit Agent Operating Guide

> Single source of truth for any AI agent or human contributor working on GrabBit.
> Read it fully before making changes. Keep it current: when a decision here
> changes, update this file in the same PR/commit.

---

## 1. Mission & Vision

**GrabBit** is a free, privacy-first, multi-platform social-media downloader and
**private media manager**. Users paste a link (YouTube, Instagram, TikTok, X, …)
and GrabBit downloads the image/video **on-device** using **yt-dlp + ffmpeg**.
Downloads live in a private in-app library by default; the user explicitly chooses
what to export to the device gallery. The app supports Simple and Advanced modes,
bulk downloads, metadata management, deep configurability, and an optional
PIN/biometric app lock.

Platforms: **Android first** (APK/AAB sideload, off Play Store because of YouTube),
**Windows in v2**.

### Monetization principle (memorize — it governs every feature decision)

> **On-device = FREE. Cloud = CREDITS.**
> Anything that runs on the user's own device — downloads, media manager, playback,
> metadata, organization, app lock, all local yt-dlp/ffmpeg/Dart tools, **and all
> on-device/edge AI (v2)** — is **free forever**; it costs us nothing. Only
> features that spend *our* money via the backend / paid cloud APIs (e.g. Gemini,
> v3) are credit-metered. Always bias a feature toward an on-device implementation
> when quality allows, so it stays free.

### Version strategy (three bands)

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Core on-device downloader + private media manager (Android). | Offline | Free |
| **v2** | World-class, feature-rich, production-ready, **local-only**: Windows parity + **edge/local AI** with graceful capability-gating. | Offline | Free |
| **v3** | Introduce **Supabase** backend + **Gemini** cloud AI; **credit-based** monetization (Stripe/PayPal) for cloud-only features. | Online (opt-in) | Credits |

The app stays fully free and offline through v2. Money enters only in v3, and only
for features that spend our money on cloud APIs. No ads, ever.

---

## 2. Tech Stack & Rationale

| Concern | Choice | Why |
|---|---|---|
| App framework | **Flutter** (Dart) | One codebase → Android + Windows. |
| State mgmt | **Riverpod** (+ riverpod_generator) | Compile-safe, testable, no BuildContext coupling. |
| Routing | **go_router** | Declarative, deep-link ready. |
| Local DB | **Drift** (SQLite) | Relational metadata/queue, typed queries, migrations. |
| Platform bridge | **Pigeon** | Type-safe Dart↔Kotlin codegen for the engine. |
| Download engine (Android) | **youtubedl-android** (JunkFood02 fork, `io.github.junkfood02.youtubedl-android`) | Bundles Python+yt-dlp+ffmpeg; maintained fork used by Seal; on Maven Central. |
| Download engine (Windows, v2) | bundled `yt-dlp.exe` + `ffmpeg.exe` via Dart `Process` | Native, simple, no Python embed needed. |
| Background work | Android **foreground service** + persistent queue | Reliable long downloads, OS-compliant. |
| Secure storage | **flutter_secure_storage** | PIN hash, future tokens. |
| App lock | **local_auth** + PIN | Biometric + fallback. |
| Edge/Local AI (v2) | **LiteRT / MediaPipe LLM**, **whisper.cpp**, **ML Kit**, behind an `InferenceEngine` abstraction | Free local tier; swappable. |
| Backend (v3) | **Supabase** (Auth, Postgres, Edge Functions) | Auth + credit ledger + Gemini/Genkit proxy. |
| Cloud AI (v3) | **Gemini** via **Genkit** flows | Multimodal; for tasks/devices beyond on-device limits. |
| Payments (v3) | **Stripe / PayPal** | Play Billing unavailable off-store. |
| UI | **Material 3**, dynamic color, light/dark | Modern, themeable; Simple/Advanced modes. |

> When adding a dependency, justify it in the commit and add it to `docs/SPEC.md`.
> Prefer well-maintained, widely-used packages. Avoid abandoned plugins.

---

## 3. Repo Layout & Architecture Conventions

**Feature-first clean architecture.** Each feature owns its `data/`, `domain/`,
`presentation/` layers. Cross-cutting code lives in `core/`.

```
/                       repo root
  CLAUDE.md             this file
  docs/                 PRD, ARCHITECTURE, SPEC, ROADMAP
  .github/workflows/    ci.yml, build-apk.yml
  lib/
    core/               theming, routing, db (Drift), logging, di, utils
    core/engine/        DownloadEngine interface + platform impls
    core/ai/            (v2) InferenceEngine + DeviceCapability diagnostics
    features/
      downloader/       paste-url, format select, progress
      library/          private media list + in-app player
      queue/            bulk/queue management
      settings/         config, storage policy, app lock
      ai/               (v2) model selector, AI tools
    main.dart
  android/              Kotlin host + youtubedl-android + Pigeon glue
  windows/              (v2) desktop runner + bundled binaries
  test/                 unit/widget tests
  pigeons/              Pigeon API definitions
```

**Rules**
- Domain layer is pure Dart (no Flutter, no plugins). Data layer implements domain
  interfaces. Presentation depends on domain via Riverpod providers.
- Never call a platform plugin directly from UI — go through a provider/repository.
- The engine is **always** accessed through the `DownloadEngine` interface so
  Android/Windows stay swappable. Same rule for `InferenceEngine` in v2.

---

## 4. Engine Abstraction Contracts

### `DownloadEngine` (pure-Dart interface in `core/engine/`)
Exposes at minimum: `probeFormats(url)`, `download(request) → Stream<Progress>`,
`cancel(id)`, `extractMetadata(url)`. Implementations:
- **Android**: `AndroidYtDlpEngine` → Pigeon → Kotlin → `youtubedl-android`.
- **Windows (v2)**: `WindowsProcessEngine` → `Process.start(yt-dlp.exe …)`, parse
  progress from stdout, invoke `ffmpeg.exe` for merge/convert.

Engine selection happens once via a Riverpod provider keyed on `Platform`. UI and
queue code must be engine-agnostic.

### `InferenceEngine` (v2, pure-Dart interface in `core/ai/`)
Mirrors `DownloadEngine`. On-device implementations back local AI (LiteRT/MediaPipe
LLM, whisper.cpp, ML Kit). A `DeviceCapability` probe (RAM/CPU/accelerator) feature-
flags each AI feature and **gracefully disables** ones the device can't run (with a
clear, user-friendly reason). In **v3**, a cloud `InferenceEngine` implementation
slots behind the same interface, optionally letting incapable devices fall back to
credit-metered cloud inference.

---

## 5. Build / Run / Test Commands

```bash
flutter pub get
dart run build_runner build                                # Riverpod/Drift codegen
dart format --set-exit-if-changed .                         # format check (CI gate)
flutter analyze                                             # static analysis (CI gate)
flutter test                                                # unit/widget tests (CI gate)
flutter build apk --debug                                   # debug APK (CI artifact)
flutter build apk --release / flutter build appbundle       # release (manual)
```

---

## 6. CI Discipline — READ BEFORE TOUCHING `.github/`

The maintainer is on **GitHub Free** with limited Actions minutes on a **private**
repo (~2,000 min/mo) and **tests primarily from a phone** (no local IDE). CI is the
only feedback loop. Be frugal:

- **`ci.yml` — AUTO** on PR + push to feature branches: `dart format` check →
  `flutter analyze` → `flutter test`. **Ubuntu only** (1x multiplier), with pub
  cache. Keep it ~2-4 min. This is the bug/error catcher.
- **`build-apk.yml` — MANUAL** (`workflow_dispatch`): builds a **debug APK**
  (boolean input to switch to release/AAB), Gradle + pub caching, uploads the APK
  as a **downloadable artifact** for on-device testing.
- **Hard rules**: never auto-build APKs on push; always ubuntu for Android
  (macOS=10x, windows=2x minutes); cache aggressively; batch changes before
  triggering an APK build. Cannot make the repo public (YouTube downloader).

---

## 7. Git Workflow

- Active branch: **`claude/init-grabbit-setup-RaBUs`**. Develop, commit, push here.
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`…).
- Small, reviewable commits. Push with `git push -u origin <branch>`; retry network
  failures with exponential backoff. Never force-push shared branches.
- **Do NOT open PRs unless explicitly asked.**

---

## 8. Coding Standards

- Follow `flutter analyze` with a strict `analysis_options.yaml` (lints enabled).
- Names: `PascalCase` types, `camelCase` members, `snake_case` files.
- Comments only for non-obvious WHY (constraints, workarounds). No narration.
- No premature abstraction; no dead code; no backwards-compat shims.
- Validate only at boundaries (user input, parsed yt-dlp output, backend).
- Errors: use the typed error taxonomy in `docs/SPEC.md`; surface user-friendly
  messages, log technical detail.

---

## 9. Security, Privacy & Secrets

- **Privacy-first**: no telemetry/analytics in v1/v2. Downloads stay on-device.
- Default storage = app-private dir; export to gallery is an explicit user action.
- App lock: PIN hashed (never stored plain) in `flutter_secure_storage`; biometric
  via `local_auth`.
- **Never commit secrets.** No API keys in the client. All Gemini/paid-API calls
  (v3) go through Supabase Edge Functions; keys live in Supabase secrets.
- Scoped storage / least-privilege permissions only (see SPEC permissions matrix).

---

## 10. Legal Posture

GrabBit is a general-purpose downloader; **the user is responsible** for complying
with the terms of service and copyright law of the sites they use. GrabBit hosts
**no** copyrighted content and ships **no** pre-loaded media. Distribution is
off-Play-Store (sideload + landing site) precisely because of platform policies.
Include a clear user-responsibility disclaimer in-app and on the landing site.

---

## 11. Document Map

- `docs/PRD.md` — what we're building & why (product).
- `docs/ARCHITECTURE.md` — system design blueprint.
- `docs/SPEC.md` — implementation-level technical spec.
- `docs/ROADMAP.md` — multi-phase delivery plan (P0–P10, banded v1/v2/v3).

When in doubt, these four + this file win over memory.
