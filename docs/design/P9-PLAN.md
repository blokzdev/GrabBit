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
  native part (P9e FLAG_SECURE) needs an APK build; pure-Dart subphases
  (P9a/P9b/P9c-1/P9d) ship as standalone green-CI PRs. (P9c-2/PiP was deferred to BACKLOG.)
- **PR cadence:** open the PR into `main` at phase end (per CLAUDE.md §7). No PR is opened
  automatically.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P9a — Single v2→v3 DB migration *(do all schema changes once)*
- In `lib/core/db/database.dart`, bump `schemaVersion` to **3** with one `from < 3`
  `onUpgrade` branch (precedent: the existing v1→v2 block). Add:
  - `isFavorite` (bool) on `MediaItems`
  - `contentHash` (text, nullable) on `MediaItems` — for dedupe (existing `crypto` dep)
  - `orderIndex` (int) on `DownloadTasks` — for P9d reorder
  - sort/`lastAccessed` columns as needed, plus indices (favorite, hash, createdAt/title/size)
- Add a migration test (the repo already has v1→v2 migration-test precedent).
- **Exit / review:** a P8-era library upgrades to v3 cleanly with no data loss.
- **Status:** implemented — `schemaVersion` 3 with a `from < 3` branch adding the four columns +
  indices (favorite/content_hash/created_at); v2→v3 upgrade test added. Columns are unused until
  P9b–P9d. CI-green. **Pending on-device upgrade spot-check.**

### `[~]` P9b — Library power *(pure Dart; split into 3 PRs)*
Search / sort / faceted filtering already existed (P2/P5c), so P9b is additive depth, shipped as
three PRs:
- **`[~]` P9b-1 — Favorites, sort polish & item delete:** `favoritesOnly` filter + star toggle
  (tile overlay + item-detail), extra sorts (`titleDesc`/`smallest`/`recentlyPlayed`), and
  `LibraryRepository.deleteItem` (file + thumb + DB cascade) with a confirmation-gated delete in
  item detail. Tests for the filter/sorts/toggle/delete. **Implemented; pending on-device check.**
- **`[~]` P9b-2 — Smart/auto albums:** a Collections | **Albums** segmented tab listing
  query-defined albums — Platforms (`watchItemCountsBySite`), Channels (`watchItemCountsByUploader`),
  and Recently played (`watchRecentlyPlayed`) — each opening a `SmartAlbumScreen` grid via
  `/album/:kind`. Pure SQL faceting (no AI/embeddings). **Implemented; pending on-device check.**
- **`[~]` P9b-3 — Duplicates & storage:** off-isolate (`compute`) `hashFilesSync` signature
  (size + head/tail 1 MiB) populating `contentHash` via `DedupeService.scan`; `watchDuplicates` +
  a `/duplicates` view with per-item delete; storage aggregation (`watchSizeByType`/`BySite`/
  `watchLargestItems`) + a `/storage` view (breakdown + largest + "Find duplicates"); entry from
  Settings → Storage. Reuses P9b-1's `deleteItem`. **Implemented; pending on-device check.**
- **`[~]` P9b-4 — Preventive (source-identity) dedupe:** surface the source `id` at probe (engine
  field add); `findItemBySourceId`/`findItemByUrl`/`existingSourceIds` + a `source_id` index
  (schema v3→v4). Add-Download shows a non-blocking "Already in your library" banner; the playlist
  picker badges already-saved entries with a "Hide already-saved" toggle. Complements P9b-3's
  content/file dedupe. **Implemented; pending on-device check.**
- **Exit / review:** search by keyword, sort, star favorites, see a storage breakdown, and detect
  duplicates (content + by source id) — all offline.

### `[x]` P9c — Player enhancements *(P9c-1 shipped; P9c-2/PiP → BACKLOG)*
- **`[x]` P9c-1 — Player polish (pure Dart):** Chewie config — playback **speed** menu, **Loop**
  toggle (`setLooping`), **keep-screen-awake**, and **subtitle-track selection** from the `.srt`/
  `.vtt` sidecars (parsed via `video_player`'s `SubRip`/`WebVTT` parsers; controller recreated on
  track change, reusing the video controller). **markPlayed** stamps `lastAccessedAt` on first play
  → fills P9b-2's Recently-played album. Shared `subtitle_files` util (reused by Media Studio).
  Also backfilled the P8/P9 VERIFICATION checklist. **Shipped.**
- **`[→]` P9c-2 — Picture-in-Picture (native): deferred to `docs/BACKLOG.md`** (revisit v2/P13).
  It's native, on-device-only verification, and pure polish — not worth a native APK round now.
- **Background audio is deferred** (`docs/BACKLOG.md`).
- **Exit / review:** change speed/loop and pick a subtitle track in-player (P9c-1). *(PiP backlog.)*

### `[~]` P9d — Queue depth *(pure Dart)*
- `ReorderableListView` over the queue, persisting `orderIndex` (column from P9a): `watch`/
  `nextQueued` order by `orderIndex`, `enqueueAll` assigns increasing indices, `setOrder` rewrites
  them. An aggregate **dashboard** (overall progress + counts + **live aggregate speed** / longest
  ETA / total size) over the `lib/features/queue/` providers. Live speed/size are recovered by
  parsing the default yt-dlp progress line in Dart (`core/engine/progress_line.dart`, unit-tested) —
  the line is passed through youtubedl-android's callback (`--progress-template` is unsafe). Pulls
  in the BACKLOG queue reorder + dashboard items.
- **Scheduling is deferred** (`docs/BACKLOG.md`) — needs WorkManager + wifi-window logic.
- **Exit / review:** drag-reorder persists across restart; the dashboard shows live aggregate
  speed / ETA / total. **Implemented; pending on-device check.**

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
