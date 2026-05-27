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

### `[ ]` P11b — Inbox UX + notification settings *(pure Dart/widget)*
- `/inbox` screen: grouped feed, severity styling, tap → deep-link, swipe-to-dismiss, category
  filters, mark-all-read, clear.
- App-bar **bell + unread badge** (reuses the existing Material 3 `Badge` pattern); Dashboard
  **recent-activity tile**. (Not a 6th nav destination.)
- **`/settings/notifications`** sub-screen (P10j sub-screen pattern): retention control + the four
  per-category toggles with `InfoHint`s; landing nav tile + settings-search index entries.
- **Exit / review:** the bell badge reflects unread; opening the inbox marks read; filters/dismiss/
  clear work; retention + toggles persist.

### `[ ]` P11c — Producers wired through the seam *(pure Dart)*
- Queue: `_onDone`/`_onError`/`_onCanceled` post download complete/failed/pause-reason entries
  (deep-link to the item; `friendlyError()` body on failures; per-task `dedupeKey`).
- P10f transcript backfill / auto-transcribe posts on completion/failure.
- `GraphSyncService` posts on **failure** and on **explicit/manual** rebuilds only — never the
  debounced auto-sync (would spam). Inbox-open sweep trigger added.
- **Exit / review:** real background work produces durable, de-duplicated entries that deep-link.

### `[ ]` P11d — Terminal OS notifications *(native — needs an APK build)*
- `flutter_local_notifications`: Android channel + `POST_NOTIFICATIONS` runtime permission
  (API 33+); raise a system notification on download complete/failed, gated by the same category
  toggles. Complementary to the existing foreground-service progress notification.
- **Exit / review:** with the app backgrounded, a finished/failed download raises an OS
  notification that opens the relevant screen; disabling the category suppresses it.
