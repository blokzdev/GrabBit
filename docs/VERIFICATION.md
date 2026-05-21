# GrabBit — On-Device Verification Guide

> The manual, on-device test checklist for every phase. CI covers format/analyze/
> unit+widget tests and that a **debug APK builds**; it cannot exercise real
> downloads, the foreground service, notifications, MediaStore/SAF, or biometrics.
> Those live here. Keep this current: when a phase adds user-facing behavior, add
> its checks below in the same PR.

## How to get an APK
1. GitHub → **Actions** → **Build APK** → **Run workflow**.
   - Leave **release** unchecked for normal testing (debug builds faster and
     installs with the debug key).
   - Check **release** only for a v1 release candidate (needs signing — see
     §"v1 release").
2. Download the `grabbit-debug-apk` artifact, transfer to the phone, install
   (allow "install unknown apps" for your browser/files app).

Legend: each item is a check to perform. Re-run any section anytime; run **all**
sections for a full regression (e.g. before a v1 release).

---

## P0 — Skeleton  *(v1)*
- [ ] App installs and launches without crashing.
- [ ] Opens to the **Library** tab showing the empty state ("Your library is empty").

## P1 — Core engine: download + play  *(v1)*
- [ ] Tap **Add**, paste a public **YouTube** URL, tap **Check link** → title +
      thumbnail + quality presets appear.
- [ ] Pick **Best** → item downloads and appears in the Library with a thumbnail.
- [ ] Open the item → it **plays** in the in-app player (video + audio).
- [ ] Repeat with **Audio only** → produces a playable audio file.
- [ ] Try a non-YouTube public link (e.g. another yt-dlp-supported site) → works
      or fails with a clear error (not a crash).
- [ ] Downloaded media is **not** visible in the system Gallery (private by default).

## P2-A — Config + persistent queue  *(v1)*
- [ ] Add several links quickly → the **Queue** screen shows them; no more than
      **max-concurrent** (default 2) run at once, the rest show "Queued".
- [ ] **Pause** a running download → it stops and shows "Paused"; **Resume** → it
      continues/restarts.
- [ ] **Cancel** a download → it leaves the active set.
- [ ] A failed download (e.g. a bad URL) shows **Failed**; **Retry** re-queues it.
- [ ] **Settings** persist across app restart: change Theme, Advanced mode, Max
      concurrent → reopen app → values retained.
- [ ] Theme switch (System/Light/Dark) and Dynamic color toggle apply visibly.
- [ ] Kill the app mid-download, reopen → no task is stuck "running" (orphans
      return to the queue).

## P2-B — Background service + Save to device  *(v1)*
- [ ] Start a download, leave the app (home button) → an ongoing **progress
      notification** shows and the download keeps running.
- [ ] Tap the notification's **Stop** → running downloads pause.
- [ ] First download prompts for the **notification permission** (Android 13+).
- [ ] Item screen → **Save to device** (no folder set) → file appears in the
      **Gallery** (Movies/Music/Pictures → GrabBit) and the item shows "Saved to
      device" with a badge in the grid.
- [ ] **Settings → Export folder** → pick a custom folder → export an item → the
      file lands in **that** folder.
- [ ] **Settings → Auto-save to device** ON → a new download exports automatically
      on completion.
- [ ] **Wi-Fi only** ON while on mobile data → new tasks stay "Queued" and don't
      start; on Wi-Fi they start.
- [ ] After export, the item still **plays in-app** (private master kept).

## P2-C — Manager UX + App lock  *(v1)*
- [ ] Item → **Edit**: change title + notes → saved and shown on the item.
- [ ] Add and remove **tags** → reflected on the item detail.
- [ ] Create a **collection**, add items to it, open it from **Collections** → only
      its items show.
- [ ] Library **search** filters by title; **type chips** (All/Video/Audio/Image)
      filter; each **sort** (Newest/Oldest/Title A–Z/Largest) orders correctly.
- [ ] **Settings → App lock** ON → set a PIN. Background the app and reopen → the
      **Lock screen** appears; correct PIN unlocks, wrong PIN is rejected.
- [ ] Enable **Biometric unlock** → reopening prompts fingerprint/face and unlocks;
      cancelling falls back to PIN.
- [ ] Disable app lock → reopening no longer prompts.

---

## P3 — Multi-Site + Bulk  *(v1)*

### P3-A — Engine: expansion + embedding + metadata  *(merged)*
Independently testable now (the picker UI for expansion lands in P3-B):
- [ ] Download a normal video with embedding on → the saved file carries an
      **embedded thumbnail** and **metadata** (check in a player/file info), and
      **subtitles** are embedded when the source has them.
- [ ] Open a downloaded item → `media_metadata` is populated (uploader,
      **description**, **upload date**) — visible on the item/edit screen.
- [ ] Confirm the downloaded file still lands as `<taskId>.<ext>` with a `.jpg`
      thumbnail (embedding didn't break the library's thumbnail pickup).

### P3-B — Bulk UI  *(merged)*
- [ ] Public **Instagram / TikTok / X** posts download; unsupported URLs (e.g. a
      TikTok user-profile playlist) show a **friendly error + "Update engine" CTA**,
      not a crash.
- [ ] A **YouTube playlist** / **IG or X carousel** expands into a **multi-item
      picker**; select a subset; **"Download now"** runs them; **"Add to batch"**
      holds them.
- [ ] **"Start all"** on the queue runs the held batch; **"Pause all"** pauses
      running.
- [ ] **Multi-URL paste** (several links at once) expands each; one bad URL doesn't
      abort the rest.
- [ ] **Settings → Downloader engine** shows the yt-dlp version; **Update** runs and
      refreshes it.

## P4 — v1 Completion & Refinement  *(v1)*
- [ ] Queue shows media **titles** (not raw URLs); cancel/remove and delete-collection
      ask for **confirmation**; actions show **snackbar** feedback.
- [ ] Item detail surfaces captured **description / upload date / uploader**.
- [ ] Queue **"Clear completed"** works; selection **select/deselect-all** both work.
- [ ] First launch shows a one-time **legal/user-responsibility disclaimer**; it
      doesn't reappear after acceptance.
- [ ] A custom **filename pattern** (Settings → Download filename: chips +
      preview) names the downloaded file; a batch numbers via `{num}`; exporting
      keeps that name. (Files live under `media/<taskId>/`.)
- [ ] **Wi-Fi-only** auto-resumes queued tasks when back on an unmetered network.

## P5 — Media Manager: File Explorer + metadata  *(v1)*
- [ ] **P5a** Upgrading an existing (v1-schema) install migrates cleanly — existing
      media survives and appears at the root, nothing lost.
- [ ] **P5a** A **batch** (playlist) download now records channel/username/upload-date
      and its playlist; item detail shows them (previously batch items had none).
- [ ] **P5b** Create nested folders; rename and delete them (deleted folder's media
      falls back to the root, not lost). Move single + multi-selected media between
      folders; Explorer reflects it; the Home Library | Explorer toggle works.
- [ ] **P5c** Filter the Library by platform, channel, username, playlist, and a
      description keyword; Library search/sort/collections still work.

## P6 — Media Studio: Editing Tools  *(v1)*
- [ ] Trim a video → a new playable library item; the original is preserved.
- [ ] Extract a frame (first / last / scrubbed position) → a new image item.
- [ ] Flip/mirror/rotate an image and a video; convert container/extract audio.
- [ ] Long operations show progress; unsupported ops are disabled with a reason.

## P7 — v1 Beta & Production Readiness  *(v1)*
- [ ] App has a custom **icon / splash / branding**.
- [ ] Large library (100s of items) scrolls smoothly; big playlist picker is responsive.
- [ ] i18n scaffolding present; subtitle-language selection works (if shipped).

---

## v1 release (full regression with the **release** APK)
1. **Release signing** configured (keystore + CI secret) so the release APK installs
   — done in **P7**.
2. Build with **Build APK → release = true**, install the signed release APK.
3. Run **every** section above (P0 → P7) end-to-end on a real device.
4. Confirm: privacy (nothing in Gallery until exported), app lock, background
   downloads, and playback all work on the AOT release build.
