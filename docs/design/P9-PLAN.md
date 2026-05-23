# P9 — Library, Playback & Privacy Depth: subphase plan

> The sub-roadmap for **P9** (see `docs/ROADMAP.md`). P9 makes managing, finding, and
> enjoying the private library genuinely great, and hardens privacy with non-theatrical
> lock features. Everything is **on-device = FREE** (CLAUDE.md §1). Mostly pure Dart
> (CI-green) plus **one** DB migration and a few native lock items.

## How subphases work
- Each subphase is a **commit** on `claude/p9-library-depth`. It must keep CI green
  (`dart format` · `flutter analyze` · `flutter test`), run `build_runner` if codegen
  (freezed/json/drift) changed, and update `docs/VERIFICATION.md`.
- **One schema migration:** all DB changes land once in **P9a** (v2→v3). Do not bump the
  schema again later in the phase.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). The
  native parts (P9c PiP, P9e FLAG_SECURE) batch into one APK build; pure-Dart subphases
  (P9a/P9b/P9d) ship as standalone green-CI PRs.
- **PR cadence:** open the PR into `main` at phase end (per CLAUDE.md §7). No PR is opened
  automatically.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[ ]` P9a — Single v2→v3 DB migration *(do all schema changes once)*
- In `lib/core/db/database.dart`, bump `schemaVersion` to **3** with one `from < 3`
  `onUpgrade` branch (precedent: the existing v1→v2 block). Add:
  - `isFavorite` (bool) on `MediaItems`
  - `contentHash` (text, nullable) on `MediaItems` — for dedupe (existing `crypto` dep)
  - `orderIndex` (int) on `DownloadTasks` — for P9d reorder
  - sort/`lastAccessed` columns as needed, plus indices (favorite, hash, createdAt/title/size)
- Add a migration test (the repo already has v1→v2 migration-test precedent).
- **Exit / review:** a P8-era library upgrades to v3 cleanly with no data loss.

### `[ ]` P9b — Library power *(pure Dart)*
- Over `lib/features/library/data/library_repository.dart` + `library_view.dart` /
  `library_filter_sheet.dart`:
  - **Search:** indexed `LIKE` over title/uploader/description/tags (FTS5 only if perf
    demands — deferred otherwise).
  - **Sort:** date / size / name.
  - **Favorites / star**; **smart/auto albums** (by site / uploader / recent).
  - **Duplicate detection:** streamed `crypto` hash (partial content + size), computed off
    the UI isolate (never load whole videos into memory), surfaced in a "duplicates" view.
  - **Storage-usage / cleanup** breakdown view.
- All unit/widget-testable.
- **Exit / review:** search by keyword, sort, star favorites, see a storage breakdown, and
  detect duplicates — all offline.

### `[ ]` P9c — Player enhancements *(mixed)*
- **Cheap wins (chewie/video_player)** in `item_detail_screen.dart`: playback **speed**,
  **loop/repeat**, **gesture seek**, **subtitle-track selection**. Pure Dart.
- **Native:** **Picture-in-Picture** (`enterPictureInPictureMode`; manifest
  `android:supportsPictureInPicture` — `configChanges` already covers screenSize).
- **Background audio is deferred** (`docs/BACKLOG.md`) — it adds a second foreground-service
  type to coordinate with the download service.
- **Exit / review:** change speed/loop/seek and pick a subtitle track in-player; PiP works on
  home-press.

### `[ ]` P9d — Queue depth *(pure Dart)*
- `ReorderableListView` over the queue, persisting `orderIndex` (column from P9a); an
  aggregate **dashboard** (speed / ETA / total size) over the existing `lib/features/queue/`
  providers. Pulls in the BACKLOG queue reorder + dashboard items.
- **Scheduling is deferred** (`docs/BACKLOG.md`) — needs WorkManager + wifi-window logic.
- **Exit / review:** drag-reorder persists across restart; the dashboard shows live aggregate
  speed / ETA / total.

### `[ ]` P9e — Privacy & app-lock hardening *(ship only the non-theatrical items)*
- **FLAG_SECURE** toggle (block screenshots / hide content in recents) — a `MainActivity`
  window flag wired to a new setting (default off; it also blocks legitimate recording, so it
  must be user-controlled).
- **Auto-lock timeout** (`autoLockSeconds` setting) — a pure-Dart timer over the existing
  router lock gate (`lib/features/lock/lock_controller.dart`). CI-testable.
- **Secure delete** — overwrite-then-delete for removed private items; **document honestly**
  that flash wear-leveling makes this best-effort, not a guarantee.
- **Exit / review:** FLAG_SECURE blocks recents/screenshots; the app re-locks after the
  timeout; secure-delete removes a private item.

---

## Deferred (cut from P9 → `docs/BACKLOG.md`), with rationale
- **Decoy/duress PIN + decoy vault** — security theater; high complexity, dubious real protection.
- **Intruder selfie** — needs CAMERA permission, violating the least-privilege / no-telemetry
  privacy posture (CLAUDE.md §9). Cut on principle.
- **App-icon disguise/alias** — unreliable launcher re-pin post-Android-10; common "app
  disappeared" reports.
- **Background audio** (P9c), **download scheduling** (P9d), **per-folder lock**, **FTS5** search.
