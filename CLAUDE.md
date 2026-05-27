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
**Windows in v2**. **AI is core to the vision** — v1 is an *AI-powered* downloader/manager and
ships only **after** the on-device AI + graph work (P10, P12–P13).

### Monetization principle (memorize — it governs every feature decision)

> **Everything is on-device, and on-device = FREE, forever.**
> Downloads, media manager, playback, metadata, organization, app lock, all local
> yt-dlp/ffmpeg/Dart tools, **and all on-device/edge AI + the on-device graph DB** —
> everything runs on the user's own device, costs us nothing, and is **free forever**.
> GrabBit is sustained by an **optional donations link** (P14). **No ads, no telemetry,
> no accounts, no cloud.** (The former cloud/credits "v3" band is **dropped**; the
> `InferenceEngine` interface leaves a *theoretical* cloud seam, but it is unplanned.)
> Always bias a feature toward an on-device implementation.

### Version strategy (two bands — v3/cloud dropped)

| Band | Theme | Network | Money |
|---|---|---|---|
| **v1** | Android, free, on-device, **AI-powered**: core downloader + private media manager (P0–P9), then the **on-device AI + graph pillar** (P10, P12–P13) with the **Activity Inbox** (P11) in between, then beta & launch (P14). | Offline | Free |
| **v2** | Local-only expansion: Windows parity (P15) + production polish & authenticated/cookie import (P16). | Offline | Free |

The app is **free forever and fully offline**, sustained by an optional donations link. **No ads,
no telemetry, no cloud, ever.** AI is core to the vision, so **v1 ships *after* the AI work**. See
`docs/ROADMAP.md`, `docs/GRAPH-SPEC.md`, `docs/AI-SPEC.md`.

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
| Graph + vector DB (v1, P10) | **CozoDB** — relational+graph+vector + HNSW (Android via `io.github.cozodb:cozo_android` Maven AAR + Pigeon; `dart:ffi`/`ffigen` on Windows). MPL-2.0. | One embeddable engine serves both the relationship graph and the AI vector index; derived index beside the canonical Drift DB. See `docs/GRAPH-SPEC.md`. |
| On-device AI runtime (v1, P12–P13) | **`flutter_gemma`** (MediaPipe LLM Inference / **LiteRT-LM**) for embeddings + generation + RAG; **whisper.cpp** (`whisper_ggml_plus`/`whisper_kit`); **ML Kit** (OCR/translate) — all behind an `InferenceEngine` abstraction | Free, on-device, swappable; capability-gated. Prefer Apache-2.0/MIT models (vet Gemma). See `docs/AI-SPEC.md`. |
| Graph visualization (v1, P10) | **`graphview`** (force-directed, expand/collapse) | Interactive library relationship explorer. |
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
  docs/                 PRD, ARCHITECTURE, SPEC, ROADMAP, GRAPH-SPEC, AI-SPEC
  .github/workflows/    ci.yml, build-apk.yml
  lib/
    core/               theming, routing, db (Drift), logging, di, utils
    core/engine/        DownloadEngine interface + platform impls
    core/graph/         (P10) GraphStore interface + Cozo impl + GraphSyncService
    core/ai/            (P10, P12–P13) InferenceEngine + DeviceCapability diagnostics
    features/
      downloader/       paste-url, format select, progress
      library/          private media list + in-app player
      queue/            bulk/queue management
      settings/         config, storage policy, app lock
      ai/               (P10, P12–P13) graph view, related, model selector, AI tools
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
  Android/Windows stay swappable. Same rule for `InferenceEngine` (P12) and `GraphStore`
  (P10) — never reference a concrete engine/store from UI.

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

### `GraphStore` (P10, pure-Dart interface in `core/graph/`)
The on-device relationship graph + vector index. Backed by **CozoDB** (Android via the
`cozo_android` Maven AAR + a `CozoHostApi` Pigeon bridge; Windows via `dart:ffi` in P15). **Drift
stays canonical; Cozo is a derived, rebuildable index** keyed by `MediaItems.id`. `GraphStore` must
not import the AI layer — only `GraphSyncService` bridges Drift → Cozo (and consumes embeddings).
Full design in **`docs/GRAPH-SPEC.md`**.

### `InferenceEngine` (P10, P12–P13, pure-Dart interface in `core/ai/`)
Mirrors `DownloadEngine`. On-device implementations back local AI: **`flutter_gemma`**
(embeddings + LLM generation + RAG via MediaPipe/LiteRT-LM), **whisper.cpp**, **ML Kit**. A
`DeviceCapability` probe (RAM/CPU/accelerator) feature-flags each AI feature and **gracefully
disables** ones the device can't run (with a clear, user-friendly reason). `embed()` *produces*
vectors; `GraphStore` *stores/searches* them. The interface leaves a *theoretical* cloud seam, but
cloud inference is **unplanned** (v3 dropped). Full design in **`docs/AI-SPEC.md`**.

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

The repo is **public** on **GitHub Free**, so Actions minutes are **unlimited**. The
real constraints now are **wall-clock feedback time** and that the maintainer **tests
primarily from a phone** (no local IDE) — CI is the only automated feedback loop. Stay
lean for speed, not for a minutes budget:

- **`ci.yml` — AUTO** on PR + push to feature branches: `dart format` check →
  `flutter analyze` → `flutter test`. **Ubuntu only**, with pub cache. Keep it ~2-4 min.
  This is the bug/error catcher.
- **`build-apk.yml` — MANUAL** (`workflow_dispatch`): builds a **debug APK**
  (boolean input to switch to release/AAB), Gradle + pub caching, uploads the APK
  as a **downloadable artifact** for on-device testing.
- **Hard rules**: never auto-build APKs on push (they're slow and rarely needed per
  commit); always ubuntu for Android (faster + cheap); cache aggressively; batch
  changes before triggering an APK build.
- **Be green locally before pushing.** Run the three gates locally first —
  `dart format --set-exit-if-changed .` · `flutter analyze` · `flutter test` — and only
  push when they pass. Run `dart run build_runner build` **only when codegen inputs
  changed** (Drift tables, Riverpod/Freezed/JSON-annotated classes). CI is the safety
  net, not the first place a failure should surface.

---

## 7. Git Workflow

- **Development loop (plan → approve → execute).** For any non-trivial change, work in
  **plan mode first**: explore (Explore agents / targeted reads), design thoroughly, ask
  clarifying questions (`AskUserQuestion`) only at genuine forks, write the plan to the
  plan file, then **`ExitPlanMode` for the maintainer's approval — do not start coding
  until approved.** Once a (sub)phase is approved, the agent **leads execution
  autonomously, end-to-end** — branch, code, test, format/analyze, commit, push, open the
  PR — **without pausing for per-command/tool approval** (the harness allow-rules in
  `.claude/settings.json` back this). Still **pause to confirm** for genuinely ambiguous
  product forks and for **risky/irreversible actions** (force-push, history rewrite,
  deleting shared branches/state, dependency downgrades). Split a large phase into
  reviewable subphases (the maintainer reviews **on a phone** — smaller green PRs win) and
  confirm the split first.
- **`main`** is the default, integration branch — **never commit directly to it.**
- **Branches are single-use per PR.** Each PR gets its own **fresh** branch, **cut from the latest
  `main`**, named for the work it contains: **`claude/p<N><sub>-<short-topic>`** for a (sub)phase
  (e.g. `claude/p10a-cozo-foundation`) or **`claude/<short-topic>`** for off-phase work (e.g.
  `claude/docs-consistency-sweep`). The maintainer **deletes the branch on merge**, so a branch name
  maps 1:1 to a single PR and is **never reused**.
  - **Do not lock onto a branch name handed to a session at startup.** A session may be seeded with a
    designated dev-branch name (e.g. from a prior task); treat that as valid only for the *current*
    unmerged work. For any **new** PR, **always create a new branch from fresh `main`** — never
    reuse a previously-merged (and now-deleted) branch name, and never stack new work on a stale
    local branch. When in doubt, `git fetch origin main` and branch from it.
- **Conventional Commits** (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`…).
- Small, reviewable commits. Push with `git push -u origin <branch>`; retry network
  failures with exponential backoff. Never force-push shared branches.
- **Subphase = PR**: at the end of each completed (sub)phase — all CI gates green
  (format · analyze · test) **and** the (sub)phase's exit criteria met — the agent
  **opens a PR into `main`** as the final step of its execution, without waiting for
  a maintainer trigger. The maintainer reviews, merges, and deletes the branch, then
  tells the agent; the agent syncs local `main` and starts the next (sub)phase's
  branch. (A "phase" with no subphases opens one PR; a phase split into subphases
  opens one PR per subphase.)
- **Same-PR doc upkeep.** Every (sub)phase PR also: (a) **updates `docs/VERIFICATION.md`**
  whenever it adds user-facing behavior — the on-device checks CI can't cover (real
  downloads, native, notifications, biometrics, etc.); mandatory, it's the v1-release
  regression checklist; (b) **flips the relevant plan-doc status marker** (e.g.
  `docs/design/P11-PLAN.md` `[~]`→`[x]`); and (c) **logs any deliberate deferral in
  `docs/BACKLOG.md`, tagged `(From P<N><sub>.)`**.
- Mid-(sub)phase — i.e. work that doesn't yet meet a boundary — do **not** open a PR
  unless explicitly asked.

---

## 8. Coding Standards

- Follow `flutter analyze` with a strict `analysis_options.yaml` (lints enabled).
- Names: `PascalCase` types, `camelCase` members, `snake_case` files.
- Comments only for non-obvious WHY (constraints, workarounds). No narration.
- No premature abstraction; no dead code; no backwards-compat shims.
- Validate only at boundaries (user input, parsed yt-dlp output, backend).
- Errors: use the typed error taxonomy in `docs/SPEC.md`; surface user-friendly
  messages, log technical detail.
- **Riverpod + Drift:** any provider whose signature returns a Drift generated row
  type (e.g. `MediaItem`, `DownloadTask`) must be a **hand-written** provider —
  `riverpod_generator` throws `InvalidTypeException` on those types. Use codegen for
  all other providers.

---

## 9. Security, Privacy & Secrets

- **Privacy-first**: no telemetry/analytics, ever. Downloads, AI inference, embeddings, transcripts,
  and the graph index all stay **on-device**.
- Default storage = app-private dir; export to gallery is an explicit user action. The Cozo index
  lives in app-private support storage (never in the documents/media dirs).
- App lock: PIN hashed (never stored plain) in `flutter_secure_storage`; biometric
  via `local_auth`.
- **Never commit secrets.** No API keys in the client — there is **no backend and no cloud**. The
  only network calls are downloads and a one-time, integrity-checked model download (P12).
- Scoped storage / least-privilege permissions only (see SPEC permissions matrix).

---

## 10. Legal Posture

GrabBit is a general-purpose downloader; **the user is responsible** for complying
with the terms of service and copyright law of the sites they use. GrabBit hosts
**no** copyrighted content and ships **no** pre-loaded media. Distribution is
off-Play-Store (sideload + landing site) precisely because of platform policies.
Include a clear user-responsibility disclaimer in-app and on the landing site.

The repo is **open-source under Apache-2.0** (see `LICENSE`) — the same posture as
yt-dlp / Seal / NewPipe. To keep that posture defensible and reduce takedown risk,
follow these rules in code and docs:
- **Frame it as a general-purpose downloader**, never as a tool to circumvent DRM or
  paywalls. Avoid "rip", "bypass", "unlock", "crack"-style language in identifiers,
  comments, commits, and UI copy.
- **Never commit copyrighted test media or real download URLs.** Tests use synthetic
  fixtures and example.com-style placeholders only.
- Keep the **user-responsibility disclaimer** prominent (onboarding + About + landing).
- The maintainer keeps an **off-GitHub source mirror** so a takedown can't erase history.

---

## 11. Document Map

- `docs/PRD.md` — what we're building & why (product).
- `docs/ARCHITECTURE.md` — system design blueprint.
- `docs/SPEC.md` — implementation-level technical spec.
- `docs/GRAPH-SPEC.md` — (P10) on-device graph + vector DB spec: CozoDB engine, integration,
  schema, sync, algorithm→feature map. Source of truth for the graph pillar.
- `docs/AI-SPEC.md` — (P10, P12–P13) on-device edge-AI spec: `InferenceEngine`, device tiers,
  runtime/models + licensing, local GraphRAG. Source of truth for AI.
- `docs/ROADMAP.md` — multi-phase delivery plan (P0–P16, two bands v1/v2; v3 dropped).
- `docs/VERIFICATION.md` — per-phase on-device manual test checklist (what CI can't
  cover); used for spot-checks and full v1-release regression.
- `docs/design/DESIGN_SPEC.md` — (P7) the living design system: brand, color/type/
  motion tokens, components, and per-screen design intent. Source of truth for the
  frontend revamp.
- `docs/design/P7-REVAMP-PLAN.md` — (P7) the frontend-revamp sub-roadmap: foundation
  + per-screen subphases (P7a, P7b, …).
- `docs/design/P8-PLAN.md` — (P8) download-engine power & intake sub-roadmap (P8a–P8d:
  share intake, engine options, subtitles/SponsorBlock/chapters, format picker).
- `docs/design/P9-PLAN.md` — (P9) library/playback/privacy depth sub-roadmap (P9a–P9e:
  DB v3, library power, player, queue, lock hardening).
- `docs/design/P-AI-PLAN.md` — (P10, P12–P13) edge-AI + graph delivery sub-roadmap (lean; references
  `GRAPH-SPEC.md` + `AI-SPEC.md` for the deep design).
- `docs/design/P11-PLAN.md` — (P11) Activity Inbox sub-roadmap (P11a–P11e: data foundation, inbox
  UX + settings, producers, OS notifications, actionable entries + per-item read).

When in doubt, these + this file win over memory.
