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

### `[~]` P9e — Privacy & app-lock hardening *(ship only the non-theatrical items)*
- **FLAG_SECURE** toggle (block screenshots / hide content in recents) — a `PrivacyHostApi` Pigeon
  method toggling the `MainActivity` window flag, wired to a new `blockScreenshots` setting
  (default off; it also blocks legitimate recording, so it's user-controlled). Applied at startup
  + on toggle via `privacyServiceProvider`.
- **Auto-lock timeout** (`appLock.autoLockSeconds`, default 1 min) — `AutoLock` controller arms a
  Timer when backgrounded and cancels it on a quick return (`auto_lock_controller.dart`, driven by
  the `app.dart` lifecycle observer). 0 = lock immediately. CI-tested with `fakeAsync`.
- **Secure delete** — opt-in `secureDelete` setting (default off): `secureDeleteFile` overwrites
  bytes (single pass) before unlinking; honestly **best-effort** on flash storage (wear-levelling).
- **PIN UX & lockout hardening** — confirm-PIN setup + reveal toggle + digits-only (`pin_dialog.dart`),
  a **Change PIN** action, **confirm-before-disable** (disabling wipes the PIN), and **failed-attempt
  throttling** with an escalating, restart-surviving cooldown (`lockout_policy.dart`) shown as a
  countdown on the lock screen (+ haptics on a wrong PIN, biometric-failure feedback).
- **Exit / review:** FLAG_SECURE blocks recents/screenshots; the app re-locks after the
  timeout (not on a quick return); secure-delete removes a private item; PIN lockout + Change-PIN
  work. **Implemented; pending on-device check (FLAG_SECURE needs a manual APK build).**

### `[~]` P9f — Storage & download safety *(closes P9; all on-device, FREE)*
- **Low-storage guard** — a new `minFreeSpaceMb` setting (default 500; 0 = off) gates the scheduler
  in `_doPump` (mirrors the Wi-Fi-only gate): below the threshold, new downloads hold and a queue
  banner shows the reason. Free space comes from a native `StatFs` probe via a new `diskSpace`
  Pigeon method behind `DiskSpaceService`.
- **Battery-aware pause** — `pauseOnLowBattery` + `lowBatteryThreshold` (default 15%): holds
  downloads under the threshold or in OS power-save, via `BatteryService` (`battery_plus`); the
  queue re-pumps on `onChanged`.
- **Orphaned-file cleanup** — `StorageMaintenance.cleanupOrphans` reconciles on-disk files against
  the library and prunes leftovers + empty dirs; a confirm-gated "Clean up leftover files" action on
  the Storage screen. `deleteItem` also prunes a now-empty per-task folder.
- **Device free/total** — the Storage screen now shows real device usage ("X used of Y, Z free"),
  not just app usage.
- **Exit / review:** downloads hold below the storage/battery thresholds with a banner and resume on
  recovery; cleanup reclaims space; Storage shows device free/total. **Implemented; pending
  on-device check (StatFs + battery need a manual APK build).**

### `[~]` P9g — Item context menu & sharing *(on-device, FREE)*
- **Shared media action menu** (`media_actions.dart`): long-press any tile (Library, Collections,
  Smart Albums, Storage "largest", Duplicates) → a bottom sheet with Open · Favorite · Save to
  device · Add to collection · Move to folder · Edit info · Edit in Studio · Share · Copy/Open
  source URL · Delete. Reusable list-based helpers (so P9h's bulk bar reuses them) wrap the existing
  repo actions + `confirm`/`pickFolder`.
- **Outbound share/launch** (`ExternalShareService`, `share_plus` + `url_launcher`): share a file via
  the OS sheet, open the source link, copy the URL (Clipboard). Manifest gains a `<queries>` https
  intent.
- **Queue task overflow** — Move to top/bottom (`QueueController.moveToTop/moveToBottom`), Copy/Open
  source URL.
- **Collection rename** — `MetadataRepository.renameCollection` + a Rename/Delete overflow on
  collection tiles.
- **Gesture model:** long-press = menu; a "Select" entry (P9h) will enter multi-select.
- **Exit / review:** every grid surface long-presses to a menu; Save/Move/Add-to-collection/Delete
  work without leaving the grid; Share opens the OS sheet; queue task moves to top/bottom; rename a
  collection. **Implemented; pending on-device check (share/url_launcher need a manual APK build).**

### `[~]` P9h — Library multi-select & bulk actions *(pure Dart)*
- **Selection in the grid** — `MediaGrid`/`MediaTile` gain optional `selectedIds`/`onToggle`/
  `onSelect` params (backward-compatible; Explorer/Collections unaffected). The P9g context menu
  gains an optional **"Select"** entry (`showMediaActions(..., onSelect:)`).
- **Library wiring** (`library_view.dart`) — local `Set<String> _selected`; long-press → menu →
  **Select** enters multi-select; tap toggles; selection clears when the filter/search changes.
- **Bulk bar** (`media_selection_bar.dart`, reusable) — count + Delete · Save · Move · Add to
  collection, with an overflow for Favorite · Share · Select all. Each calls the P9g list helpers on
  the selected items; Delete/Move clear the selection afterward.
- **Exit / review:** long-press → Select → multi-select; the bar's bulk actions apply to all selected;
  Select all + Clear work. **Implemented (CI-verifiable; no APK needed).** (Collection-detail /
  Smart-album multi-select is a cheap follow-up now that `MediaGrid` supports it.)

### `[~]` P9i — Screen-level action menus *(pure Dart)*
- **Collection & smart-album app bars** — both became `ConsumerStatefulWidget`s with a shared
  **Sort within** menu (`grid_sort.dart`: `sortMediaItems` + `GridSortButton`) and a **Share all**
  action; collection-detail adds a Rename/Delete/Share-all overflow (reuses `renameCollection`).
- **Whole-queue actions** — queue app-bar overflow: **Retry all failed** / **Cancel all** /
  **Clear finished**, backed by new `QueueRepository.retryAllFailed/clearFinished/cancelAllPending`
  + `QueueController.retryAllFailed/cancelAll/clearFinished`.
- **Item-detail richness** — the 5 app-bar icons collapse to **Favorite + a `⋮` overflow** (reuses
  the P9g helpers); the body now shows **Last played** (`lastAccessedAt`) and the **collections** the
  item is in (tappable chips via `collectionsForItemProvider`).
- **Exit / review:** sort/share/rename/delete a collection or album from its app bar; retry-all/
  cancel-all/clear-finished on the queue; item-detail overflow + last-played/collections.
  **Implemented (CI-verifiable; no APK needed).**

### `[~]` P9j — Settings, About & Studio polish *(pure Dart; closes P9)*
- **Settings app-bar overflow** (`settings_screen.dart`) — a `⋮` menu with **Reset to defaults**
  (confirm → `SettingsController.resetToDefaults`, which restores prefs but **preserves the app-lock
  and accepted disclaimer**), **Clear cache** (`clearDirectory(getTemporaryDirectory())` → "Freed X"),
  and **About**.
- **Clear-cache util** (`lib/core/storage/cache_cleaner.dart`) — `clearDirectory(Directory)` best-effort
  deletes entries and tallies files/bytes; never throws on empty/missing dir. Distinct from P9f's
  library orphan cleanup.
- **About screen** (`about_screen.dart`, route `/about`) — app mark + version
  (`PackageInfo.fromPlatform` → "vX.Y.Z (build N)"), on-device tagline, **Open-source licenses**
  (`showLicensePage`), and a link to the **disclaimer**. `package_info_plus` promoted to a direct dep.
- **Media-Studio post-op** (`media_studio_screen.dart`) — the success SnackBar's action becomes
  **Actions**, opening the shared `showMediaActions` sheet (Open · Share · Add to collection · …) for
  the freshly-edited output (reuses P9g; nothing lost since the sheet's first entry is Open).
- **Exit / review:** Reset reverts prefs with lock+disclaimer intact; Clear cache frees temp space;
  About shows the real version + opens licenses/disclaimer; Studio "Actions" shares/files the new item.
  **Implemented (CI-verifiable; no APK needed).** This closes P9 (a→j).

---

## Deferred (cut from P9 → `docs/BACKLOG.md`), with rationale
- **Decoy/duress PIN + decoy vault** — security theater; high complexity, dubious real protection.
- **Intruder selfie** — needs CAMERA permission, violating the least-privilege / no-telemetry
  privacy posture (CLAUDE.md §9). Cut on principle.
- **App-icon disguise/alias** — unreliable launcher re-pin post-Android-10; common "app
  disappeared" reports.
- **Background audio** (P9c), **download scheduling** (P9d), **per-folder lock**, **FTS5** search.
