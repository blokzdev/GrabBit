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

### P4 — Polish + v1 Beta  *(v1)*
- [ ] Error UX + retries, naming templates, Wi-Fi-only, empty/loading states.
- [ ] Daily-driver use with no critical bugs across top sites.

---

## v1 release (full regression with the **release** APK)
1. Set up app signing (release keystore) so the release APK installs — **TODO at
   v1** (not yet configured).
2. Build with **Build APK → release = true**, install the signed release APK.
3. Run **every** section above (P0 → P4) end-to-end on a real device.
4. Confirm: privacy (nothing in Gallery until exported), app lock, background
   downloads, and playback all work on the AOT release build.
