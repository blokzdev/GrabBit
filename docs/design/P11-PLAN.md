# P11 — Activity Inbox: subphase plan

> The sub-roadmap for **P11** (see `docs/ROADMAP.md` §P11). P11 gives the app one durable,
> on-device place to surface and manage everything it does in the background — download
> outcomes, transcript/backfill results, AI/graph activity, errors, capability-gating
> notices, reminders. Built **before** the AI phases so their background work wires into the
> seam as it's written. **Entirely local — no telemetry, no push, no cloud, no accounts**;
> lives behind the app lock. Everything is **on-device = FREE** (CLAUDE.md §1).

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named
  `claude/p11<sub>-<topic>`. Each must keep CI green (`dart format` · `flutter analyze` ·
  `flutter test`), run `build_runner` if codegen (freezed/json/drift) changed, and update
  `docs/VERIFICATION.md`.
- **One schema migration:** the only DB change lands once in **P11a** (v8→v9). Do not bump
  the schema again later in the phase.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). P11a–P11c
  are pure-Dart/UI and ship as standalone green-CI PRs; **P11d** (OS notifications) is the
  one native subphase and needs an APK spot-check.
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Per-category notify toggles gate inbox writes** — a category whose toggle is off is not
  recorded at all (not merely OS-silenced). Toggles for **download / transcript / ai / graph**;
  **`error` severity and the `system`/`reminder` categories are always recorded**.
- **Severities:** `info · success · warning · error`. **Categories:** `download · transcript ·
  ai · graph · system · reminder`.
- **Retention:** `notificationRetentionDays` (default 30; `0` = keep forever), swept **lazily**
  on app/inbox open — no background scheduler. `expiresAt` is derived per-row at insert, so
  changing the setting only affects future entries.
- **Dedupe:** entries sharing a `dedupeKey` collapse onto the newest unexpired one (resurfaced
  to the top, re-marked unread, `coalesceCount++`). `dedupeKey == null` ⇒ never coalesced.
- **`itemId` carries no foreign key** — the inbox is an append-only log that must outlive the
  items it references; deep-link targets resolve defensively at tap time.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P11a — Notifications data foundation *(pure Dart; CI-verifiable)*
The durable data layer only — no UI, no producers, no OS notifications.
- `notifications` Drift table at **schema v9** (`lib/core/db/database.dart`): id, category,
  severity, title, body?, targetRoute?, itemId? (no FK), taskId?, dedupeKey?, createdAt,
  updatedAt, readAt?, expiresAt?, coalesceCount; five indices (created_at, read_at, category,
  expires_at, dedupe_key) added idempotently to `_createIndices()`; a `from < 9` migration branch.
- **`NotificationCenter.post(...)`** seam (`features/notifications/data/notification_center.dart`)
  owning category-gating + dedupe/coalesce + `expiresAt` derivation — the single write path.
- **`NotificationsRepository`** + co-located Riverpod providers
  (`features/notifications/data/notifications_repository.dart`): `watchFeed({category})`,
  `watchUnreadCount()`, `insert`, `latestByDedupeKey`, `coalesce`, `markRead`/`markAllRead`,
  `dismiss`, `clear({category})`, `sweepExpired(now)`. Feed/count providers are **hand-written**
  (Drift row type, per CLAUDE.md §8).
- Settings fields added now (gating/sweep need them): `notificationRetentionDays`,
  `notifyDownload/Transcript/Ai/Graph` + setters. P11b builds only the UI on these.
- Lazy retention sweep wired non-blocking at startup (`app.dart` post-frame callback).
- `NotificationCategory`/`NotificationSeverity` string constants; `newNotificationId()` id minter.
- **Tests:** v8→v9 migration test; repository/seam tests (post, dedupe/coalesce, read-reset,
  category-gating no-op, always-record override, retention sweep, retention-0 forever,
  unread-count, dismiss/clear, category filter).
- **Exit / review:** a pre-P11 install upgrades to v9 with no data loss; the seam/repo/sweep/gating
  pass CI. **Implemented; pending on-device upgrade spot-check.**

### `[~]` P11b — Inbox UX + notification settings *(pure Dart/widget)*
- `/inbox` screen (`InboxScreen`): newest-first feed, severity-styled tiles, tap → deep-link,
  swipe-to-dismiss (`Dismissible`), category `FilterChip`s, Clear-all (confirm + snackbar). Opening
  marks all read so the bell badge clears.
- App-bar **bell + unread badge** on the Dashboard (`_InboxBellAction`, Material 3 `Badge` over
  `unreadNotificationCountProvider`); Dashboard **recent-activity tile** (`RecentActivityTile`,
  auto-hides when empty). Not a 6th nav destination — `/inbox` is pushed over the shell.
- **`/settings/notifications`** sub-screen (`SettingsSubScaffold`): retention dropdown (Forever /
  7 / 14 / 30 / 90 days) + the four per-category toggles, each with an `InfoHint`; landing nav tile +
  five settings-search index entries.
- Shared `notification_style.dart` (severity→icon/color, category icon/label, `relativeTime`) reused
  by the inbox tile and the Dashboard tile.
- **Exit / review:** the bell badge reflects unread; opening the inbox marks read; filters/dismiss/
  clear work; retention + toggles persist. **Implemented (CI-verifiable; no APK needed); pending
  on-device spot-check.**

### `[~]` P11c — Producers wired through the seam *(pure Dart)*
- Queue (`queue_controller`): `_onDone` posts a download/success entry (deep-link to `/item/<id>`, or
  `/library` for split-chapter sets) and, when auto-transcribe built one, a single transcript/success
  entry per task; `_onError` posts a download/**error** entry (`friendlyError()` body, `/queue` route)
  **only on terminal failure** — transient retries stay silent. `_persistCompleted` returns
  `(primaryId, itemCount, transcriptCount)` to compose those.
- **Cancel/pause are intentionally not notified** (deliberate foreground actions, not "missed"
  activity). The item-detail transcript paths (manual button + offline backfill-on-open) are
  foreground too → not notified.
- **Graph** posts from the explicit Settings → "Rebuild graph index" action
  (`ai_settings_screen._rebuildGraph`: success / unavailable-warning / error), **not** from
  `GraphSyncService` — so the debounced auto-sync and startup `syncIfStale` stay silent.
- Inbox-open retention sweep added to `InboxScreen.initState` (second trigger after app startup).
- `download_<id>` dedupe key is shared by success+error (a retried task updates one entry);
  `transcript_<id>` and `graph_rebuild` are separate.
- **Exit / review:** real background work produces durable, de-duplicated, deep-linking entries.
  **Implemented (CI-verifiable; no APK needed); pending on-device spot-check.**

### `[~]` P11d — Terminal OS notifications *(native — needs an APK build)*
- `flutter_local_notifications` (already in `pubspec`; `POST_NOTIFICATIONS` already in the manifest and
  requested at download start by the foreground service) — so **no pubspec/manifest/Kotlin change**:
  pure-Dart wiring behind a `SystemNotificationService` interface (Android impl + Noop, mirroring
  `BatteryService`). Raises a system notification on download complete/failed on a **distinct**
  `grabbit_activity` channel (separate from the foreground-service `grabbit_downloads`/id-42 progress
  notification), gated by the same `notifyDownload` toggle.
- Only raised when the app is **backgrounded** (a new `appLifecycleStateProvider`, updated from
  `app.dart`'s lifecycle observer) — the in-app inbox already covers the foreground case. Errors honor
  the toggle for the OS popup, but the inbox still records them unconditionally.
- Tap carries the entry's `targetRoute` as payload → `appRouterProvider.go(route)` (with an `/inbox`
  fallback for stale targets). Cold-start taps route via `getNotificationAppLaunchDetails()` at startup,
  mirroring share-intake's `takeInitialUrl()`.
- **Exit / review:** with the app backgrounded, a finished/failed download raises an OS
  notification that opens the relevant screen (cold start too); disabling the category suppresses it;
  a foregrounded completion raises no OS popup. *(Notification status-bar icon polish backlogged.)*

### `[~]` P11e — Actionable inbox entries + per-item read *(pure Dart)*
- Per-entry `⋮` / long-press menu on inbox tiles (mirroring P9g `showMediaActions`,
  `showNotificationActions` in `notification_actions.dart`) — **lean** set: **Retry** a failed download
  (reuses the existing `QueueController.retry(taskId)` — then dismisses the stale error entry + a
  "Retrying…" snackbar), **Open source URL**, **Copy source URL**, **Share file** (completed items),
  **Dismiss**. Context-aware by category/severity, resolved defensively from `itemId`
  (`mediaItemByIdProvider`) / `taskId` (`queueRepositoryProvider.byId`) — both may be deleted, so the
  source URL falls back item→`sourceUrl` else task→`url`, and each row only renders when its target
  exists. (No per-entry "Open" — tap navigates; no per-entry "Mark read" — see below.)
- **Read-model refinement:** dropped bulk **mark-all-read-on-open**; entries are now marked read
  **per item when opened/tapped** (modern behavior, so the unread badge/bold styling is meaningful),
  plus an explicit **"Mark all read"** app-bar action.
- **Exit / review:** a failed-download entry retries from the inbox (and the entry clears); completed
  entries share/open/copy their URL; stale targets degrade gracefully; entries stay unread until tapped;
  "Mark all read" clears the badge.
