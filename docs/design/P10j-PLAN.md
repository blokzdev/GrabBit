# P10j — Settings IA, UX Refinement & Consistency: subphase plan

Status: Draft v0.1 · Last updated: 2026-05-26

> The sub-roadmap for **P10j** (see `docs/design/P-AI-PLAN.md` P10 and `docs/ROADMAP.md`).
> P10j is the **final P10 subphase** — a polish pass that tidies up the Settings screen
> after the P8–P10 feature work piled controls onto it. It is **pure Dart / UI**: no schema
> migration, no native change, and (by decision) **no change to download behavior**.
> Everything stays **on-device = FREE** (CLAUDE.md §1).

## How subphases work
- Each subphase is its **own branch + PR** into `main` (CLAUDE.md §7): `claude/p10j-a-…`,
  `claude/p10j-b-…`, `claude/p10j-c-…`, each cut fresh from latest `main`.
- Every PR keeps CI green (`dart format` · `flutter analyze` · `flutter test`), runs
  `build_runner` only if codegen changed (none expected — no model/provider signature
  changes), and updates `docs/VERIFICATION.md` with the on-device checks CI can't cover.
- **No schema migration.** P10j touches presentation only. `SettingsModel` field names are
  **kept as-is** (only user-facing strings change); the JSON blob is untouched.
- PRs open at each subphase boundary, not mid-subphase.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

## Vision

GrabBit is **phone-first, privacy-first, free**. Settings today is one ~1100-line
`ListView` with **9 icon-led sections (~70 controls)** — comprehensive but dense, and a
few rough edges have accumulated. The refinement is guided by five principles:

1. **Progressive disclosure already exists — lean on it.** Simple/Advanced mode and the
   conditional sub-rows (battery threshold, sponsor categories, app-lock children) are the
   right pattern. P10j extends it, it doesn't replace it.
2. **Help must be discoverable on touch.** The current `(i)` help is Flutter's `Tooltip`,
   which only appears on **long-press/hover** — undiscoverable on a phone, and used in just
   3 transcript rows. Replace it with a **tappable** `InfoHint` and roll it across the
   non-obvious controls with plain-language copy.
3. **One clear mental model for captions → transcripts.** The single biggest source of
   confusion: subtitle controls live in *Downloads*, transcript controls in *Transcripts*,
   the vocabulary drifts ("subtitles" vs "captions"), and there's a **hidden interaction**
   (explicit subtitle languages silently suppress the auto-caption fetch — see below). Unify
   the wording and the layout so the pipeline reads as a story.
4. **Scale for the AI settings coming in P12/P13.** ~70 controls is already a long phone
   scroll, and P12/P13 add a large cluster (model catalog/download, capability gating, model
   selector, transcription/translation/OCR, GraphRAG chat, auto-tagging) — mostly in the AI
   area. Adopt a **Hybrid IA**: a category landing with small/stable sections **inline** and
   heavy/growth sections (Downloads, Captions & transcripts, AI & graph) as **tap-in
   sub-screens**, plus a **settings search** so any control is reachable by name. This is the
   platform-standard (iOS/Android system Settings) pattern; search neutralizes the extra-tap
   cost.
5. **Behavior-preserving.** This is a *refinement* pass. No download-engine semantics change
   (the deeper `subtitleLangs`/`autoDownloadCaptions`/`autoSubs` precedence rework is
   explicitly **out of scope** — see "Deferred").

---

## Current state (baseline)

Single screen, `lib/features/settings/presentation/settings_screen.dart`, sections in order:

| # | Section | Weight | Notes |
|---|---|---|---|
| 1 | **Downloads** | heavy (~14) | mode, quality, concurrency, faster-downloads, Wi-Fi-only, low-storage, low-battery (+threshold), filename template, **subtitles (+langs/auto/format)**, embed thumbnail/metadata |
| 2 | **Transcripts** | 3 | auto-download captions, auto-build transcripts, backfill — the only rows using the `(i)` Tooltip |
| 3 | **Advanced download options** | heavy (~10), Advanced-only | fragments, rate limit, audio format/quality, skip-downloaded, SponsorBlock (+categories), embed/split chapters, extra args |
| 4 | **Downloader engine** | 2 | yt-dlp version + update, auto-check |
| 5 | **Storage** | 3 | auto-save, export folder, "Storage & cleanup" → `/storage` |
| 6 | **Appearance** | 3 | theme, dynamic color, AMOLED |
| 7 | **Security** | 1 (+children) | app lock, change PIN, biometric, auto-lock |
| 8 | **Privacy** | 2 | block screenshots, secure delete |
| 9 | **Graph database** | 3 | rebuild index, semantic search (+update model), test embedder |

Maintenance actions (**Reset to defaults**, **Clear cache**, **About**) live **only** in the
app-bar overflow `⋮` — easy to miss.

**Reusable widgets today:** a local `_Section` (`SectionHeader` + rounded `Card`) and the
shared `SectionHeader`, `ContentBounds`, `ConfirmDialog`, `ErrorView`, `ListSkeleton`. The
recurring control patterns (`SwitchListTile`, `ListTile` + `DropdownButton`, `ListTile` →
route, `FilterChip` multi-select) are hand-rolled inline each time.

**Routing:** `/settings` is a `StatefulShellBranch`; `/storage` and `/about` are **top-level
`GoRoute`s** reached via `context.push`. That `push` pattern is the template for the new P10j
sub-screens (`/settings/downloads`, `/settings/captions`, `/settings/ai`).

### The captions ⟷ transcripts confusion (the headline problem)

`download_request_builder.dart` precedence (unchanged by P10j):
- `subtitleLangs` (the *Downloads* "Download subtitles" toggle, default `en`) — **explicit
  langs win**.
- `autoDownloadCaptions` (the *Transcripts* section) — fires **only when `subtitleLangs` is
  empty**, fetching `captionLanguage` with `autoSubs: true`, so transcripts can auto-build.
- `subtitleAuto`, `subtitleFormat` — shared knobs.

So toggling **Download subtitles** (one section) silently changes what **Auto-download
captions** (another section) does — a hidden cross-section dependency, with "subtitles" and
"captions" used for the same yt-dlp mechanism. Users can't see the pipeline:
**download caption tracks → extract a searchable transcript → power summaries/FTS/semantic
search.** P10j-b makes that pipeline legible **without changing the precedence**.

---

## Target information architecture (Hybrid + search)

A category **landing** that keeps small/stable sections inline, promotes the heavy/growth
sections to their own screens, and adds a search field that spans everything.

```
/settings  (landing)
  ┌─ [ search / quick-jump ]
  ├─ →  Downloads               (nav → /settings/downloads; folds in Advanced opts when Advanced mode)
  ├─ →  Captions & transcripts  (nav → /settings/captions)
  ├─ →  AI & graph              (nav → /settings/ai; was "Graph database" — the big growth area)
  ├─ ▸  Appearance              (inline)
  ├─ ▸  Storage                 (inline; "Storage & cleanup" still → /storage)
  ├─ ▸  Security                (inline)
  ├─ ▸  Privacy                 (inline)
  ├─ ▸  Downloader engine       (inline)
  └─ ▸  General                 (inline: About, Reset to defaults, Clear cache — out of the ⋮ overflow)
```

Rationale: small/stable sections stay inline so a 2-toggle section (Privacy) doesn't waste a
whole screen; the heavy and growth-prone groups (Downloads ~14, Advanced ~10, the future AI
cluster) get room to scale without lengthening the landing. **Search** removes the extra-tap
cost — any control is reachable by name. Sub-screens are top-level `GoRoute`s pushed like
`/storage`. The caption/transcript consolidation (P10j-b) also lightens the Downloads group.

---

## Subphases

### `[ ]` P10j-a — Foundation: reusable settings widgets + touch-friendly `InfoHint`
**Branch:** `claude/p10j-a-settings-foundation` · **Behavior-preserving refactor.**

Extract the repeated patterns into a small, consistent widget kit under
`lib/features/settings/presentation/widgets/`, and replace the long-press `Tooltip` with a
tappable hint. **No IA change, no new settings surfaced, no copy rewrites** beyond moving the
3 existing transcript tooltips onto the new affordance.

- **`SettingsSection`** — promote the private `_Section` (header + rounded `Card`) to a shared
  widget; swap all 9 call sites. Identical output.
- **`SettingsSwitchTile`** — wraps `SwitchListTile`, with an optional `InfoHint` (rendered as
  `secondary`) and consistent dense styling.
- **`SettingsChoiceTile<T>`** — the `ListTile` + `DropdownButton<T>` pattern (label, optional
  subtitle, items, value, onChanged, optional `InfoHint`). Collapses ~12 inline dropdowns.
- **`SettingsNavTile`** — `ListTile` + trailing chevron + `onTap` (sub-screens, `/storage`,
  `/about`).
- **`InfoHint`** — the key UX upgrade. A tappable `Icons.info_outline` (an `IconButton`, real
  hit target) that opens a **`showModalBottomSheet`** with the setting's title + a
  plain-language explanation. Touch-first; keeps a `Tooltip` semantics label for
  accessibility/desktop hover (v2). Takes `(title, body)`.
- Migrate the **3 existing Transcript tooltips** to `InfoHint` (same copy) to prove the
  affordance. Everything else is a like-for-like widget swap.

**Exit:** screen renders/behaves identically; the 3 transcript hints now open on **tap**;
`flutter analyze` clean; widget test covers `InfoHint` (tap → sheet shows body) and
`SettingsChoiceTile` (selecting an item calls `onChanged`). `VERIFICATION.md`: "tap the (i)
on a transcript row → explanation sheet appears" (touch check CI can't do).

### `[ ]` P10j-b — Captions & transcripts: one coherent model
**Branch:** `claude/p10j-b-captions-transcripts` · **UI-only; no `download_request_builder` change.**

Merge the subtitle controls (from *Downloads*) and the transcript controls (the *Transcripts*
section) into a single **"Captions & transcripts"** section that narrates the pipeline, and
unify the vocabulary. Built as a **self-contained `SettingsSection`** placed inline for now;
P10j-c moves it onto the `/settings/captions` sub-screen.

- **Vocabulary (pick one, apply everywhere):**
  - **Captions** = the text tracks yt-dlp downloads/embeds (sidecar `.srt/.vtt` or embedded).
  - **Transcript** = the searchable text GrabBit *extracts* from captions (feeds summaries,
    FTS search, semantic search).
- **Layout = the pipeline, top to bottom:**
  1. **Download captions** (master; backed by `subtitleLangs` non-empty) → **Languages**,
     **Include auto-generated** (`subtitleAuto`), **Format** (`subtitleFormat`) nested beneath.
  2. **Build a searchable transcript** (`autoTranscribe`) → **Backfill on open**
     (`transcriptBackfill`) nested beneath.
  3. **Auto-fetch captions for transcripts** (`autoDownloadCaptions`) — surfaced with copy
     that makes the hidden rule explicit: *"When you haven't picked caption languages above,
     GrabBit grabs captions in the app's language so a transcript can be built."* An `InfoHint`
     spells out the relationship rather than hiding it.
- **`InfoHint` copy** on each anchor explaining captions vs transcript and why the pipeline
  matters (summaries / search work on spoken content).
- **Mapping is 1:1 to existing fields** — `subtitleLangs`, `subtitleAuto`, `subtitleFormat`,
  `autoDownloadCaptions`, `autoTranscribe`, `transcriptBackfill` keep their names and setters;
  only labels/grouping/help change. The builder precedence is **unchanged** (documented above),
  so downloads behave exactly as before.

**Exit:** captions + transcript controls read as one pipeline; toggling each still writes the
same field; a real download with each combination behaves as it did pre-P10j (verify on device:
explicit langs vs auto-captions vs transcript build). `VERIFICATION.md` updated with the
caption/transcript combinations to spot-check.

### `[ ]` P10j-c — Hybrid IA + search + `InfoHint` rollout + surfaced maintenance
**Branch:** `claude/p10j-c-ia-search` · **The restructure.**

- **Sub-screens.** Add top-level routes `/settings/downloads`, `/settings/captions`,
  `/settings/ai` (`app_router.dart`, mirroring `/storage`, pushed from the landing via
  `SettingsNavTile`). Move the *Downloads* controls (and, gated by Advanced mode, *Advanced
  download options*) to `/settings/downloads`; move P10j-b's section to `/settings/captions`;
  move the AI/graph section to `/settings/ai`. Landing keeps Appearance, Storage, Security,
  Privacy, Downloader engine, General inline.
- **Search / quick-jump.** A search field atop the landing backed by a **static settings
  index** — `{ id, label, keywords, location }` for every control (location = inline section
  anchor or a sub-screen route). Typing filters to a flat results list; tapping a result
  navigates to its screen/section. The index is a single hand-maintained list (one entry per
  control); a unit test asserts every entry resolves to a real destination, so it can't
  silently rot.
- **`InfoHint` rollout.** Add plain-language hints to the non-obvious controls: faster
  downloads, concurrent fragments, rate limit, skip-already-downloaded, SponsorBlock, min free
  space, low-battery threshold, secure delete, dynamic color, AMOLED, semantic search, rebuild
  graph index. (Obvious toggles like "Wi-Fi only" stay hint-free — no noise.)
- **Surface maintenance.** Add a **General** section on the landing with **About**, **Reset to
  defaults**, **Clear cache** as rows (reusing the overflow's existing handlers). Keep the `⋮`
  overflow as a shortcut.

**Exit:** landing is short and scannable; Downloads/Captions/AI open as sub-screens; search
jumps to any control by name; non-obvious controls have tappable help; maintenance actions are
visible without the overflow. `flutter analyze` clean; tests cover the search index resolver
and result filtering. `VERIFICATION.md`: navigate to each sub-screen, run a search and follow a
result, confirm reset/clear-cache from the General section.

---

## Reusable widget contracts (P10j-a)

```dart
// lib/features/settings/presentation/widgets/
SettingsSection({required IconData icon, required String title, required List<Widget> children});
SettingsSwitchTile({required String title, String? subtitle, required bool value,
                    required ValueChanged<bool> onChanged, InfoHint? hint});
SettingsChoiceTile<T>({required String title, String? subtitle, required T value,
                       required List<DropdownMenuItem<T>> items,
                       required ValueChanged<T> onChanged, InfoHint? hint});
SettingsNavTile({required String title, String? subtitle, IconData? leading, required VoidCallback onTap});
InfoHint({required String title, required String body}); // tap → modal bottom sheet
```

`InfoHint` is data, not a widget at the call site: tiles render it as their `secondary`/
trailing icon so help is attached to the control it explains.

---

## Testing & verification

- **CI (every PR):** widget tests for `InfoHint` (tap shows body), `SettingsChoiceTile`
  (selection fires `onChanged`), and the P10j-c search index resolver (every entry resolves;
  query filters correctly). `dart format` + `flutter analyze` + `flutter test` green.
- **On-device (`VERIFICATION.md`, manual APK):** info hints open on tap (not long-press);
  caption/transcript download combinations behave unchanged; sub-screen navigation + back;
  search → result → destination; maintenance actions from the General section. APK build is
  manual/user-triggered (CLAUDE.md §6) — batch the on-device checks into one build at phase end.

---

## Out of scope / deferred

- **Caption-fetch logic rework.** Reworking the `subtitleLangs` / `autoDownloadCaptions` /
  `autoSubs` precedence into a single model would change real download behavior; P10j is
  behavior-preserving by decision. Logged for a future engine subphase if wanted.
- **Renaming `SettingsModel` fields.** User-facing strings unify; persisted field names stay
  (avoids a migration and churn).
- **Cross-screen control-type unification** (e.g. library's `SegmentedButton` vs settings'
  `DropdownButton`). Within Settings the dropdown convention is consistent; harmonizing across
  features is a separate concern.
- **Windows settings parity** — v2 / P15.
