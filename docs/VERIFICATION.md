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
2. Download the `grabbit-debug-apk` artifact (a zip of per-ABI APKs), transfer to
   the phone, and install **`app-arm64-v8a-debug.apk`** (the right one for any
   modern phone) — allow "install unknown apps" for your browser/files app.
   (`armeabi-v7a` = older 32-bit devices, `x86_64` = emulators.)

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
- [ ] A completed download still produces a playable media file **and** a `.jpg`
      thumbnail (embedding didn't break the library's thumbnail pickup). (Files now
      live under `media/<taskId>/` — see P4.)

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
- [ ] Home shows **badge counts** on the Queue + Collections actions; **pull-to-refresh**
      reloads the library grid; the **Save to device** button shows its destination.
- [ ] With 2 concurrent downloads, the progress **notification** shows averaged progress
      (not whichever updated last).
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
- [ ] **P5b** Home Library | Explorer toggle switches views. In Explorer: the
      "New folder" FAB creates a folder (nested under the current one); folder tiles
      navigate and the breadcrumb walks back. Rename/delete a folder (delete moves its
      media + subfolders back to root, nothing lost). Long-press items to multi-select,
      then Move to a folder; single-item "Move to folder" works from item detail too.
- [ ] **P5c** Filter the Library by **platform, channel, playlist** and a
      **description keyword** (search now matches descriptions too); item detail shows
      **username + playlist**. Library search/sort/collections still work.

## P6 — Media Studio: Editing Tools  *(v1)*
- [ ] **P6a** The APK installs with ffmpeg_kit bundled (note size; `flutter build apk
      --split-per-abi` keeps per-install size down). Open a video's **Studio** action.
- [ ] **P6a** Trim a video (range slider) → a new playable library item; original kept.
- [ ] **P6a** Extract a frame (scrubbed position) → a new image item; progress + Cancel
      work during the job.
- [ ] **P6b** Flip/mirror/rotate an image and a video; reverse; convert container /
      extract audio → each a new item.

## P7 — Branding & Frontend Revamp  *(v1)*

### P7a — Brand foundation
- [ ] Launcher shows the new **rabbit-motif icon**; on Android 13+ enabling **themed icons**
      tints the silhouette and the **download chevron reads as a hollow cutout**.
- [ ] Cold start shows the branded **splash** (brand background + bunny) in both light and dark.
- [ ] App renders in the new theme (indigo + amber accent) in light/dark, **dynamic color**
      on and off; headings use **Outfit**, body uses **Inter** (fonts work **offline** —
      verify with networking disabled on first launch).
- [ ] No regression in existing P0–P6 flows after the theme swap.

### P7b — Shared components
- [ ] **Library** shows the **skeleton grid** while loading (animated shimmer, not a bare
      spinner), a friendly **empty state**, and an **error state** with Retry on failure.
- [ ] **Queue** shows the **skeleton list** while loading, an **empty state**, and status
      **pills** (running/queued/held/paused/done/failed) above the list.
- [ ] Tapping a library tile **animates the thumbnail (Hero)** into the item detail screen,
      and back on pop.
- [ ] **Video** tiles show a centered **play badge**; audio/image tiles do not.
- [ ] Add-download and Selection error banners use the new shared style; the "Update the
      downloader engine" action still appears for engine-related errors and opens Settings.

### P7c — Home (Library + Explorer)
- [ ] App bar shows the **mark + "GrabBit" wordmark** (legible in light/dark + dynamic color);
      Sort / Collections badge / Queue badge all work.
- [ ] Queue icon shows a small **running dot** while a download is actively in progress, and
      no dot when nothing is running.
- [ ] Segmented toggle switches **Library ↔ Explorer**; the FAB swaps Add ↔ New folder.
- [ ] Library: populated grid · empty state with an inline **Add** action · pull-to-refresh ·
      grid shows ≈2 columns on a phone, more on a tablet/large screen.
- [ ] Explorer: **breadcrumb** walks back to root; **folder cards** (glyph + name + item count)
      open on tap; **rename**/**delete** from the card menu (delete moves contents to root);
      **long-press** media → multi-select → **Move to folder**; **New folder** FAB; empty-folder
      state; skeleton while loading and an error+Retry on failure.

### P7d — Add Download
- [ ] The URL field's **paste** button fills the field from the clipboard.
- [ ] While probing a link, a **skeleton** preview card shows (not a bare spinner).
- [ ] Resolved link shows a **preview card**: thumbnail (neutral placeholder if it fails to
      load), a **duration** pill, title, and uploader.
- [ ] Quality **preset chips** reflect the available qualities; **Add to queue** is tonal and
      **Download now** is the amber **accent** pill; both enqueue correctly.
- [ ] An unsupported/extractor error shows the shared error banner with the **"Update the
      downloader engine"** action (opens Settings).
- [ ] Pasting multiple links / a playlist still routes to the Selection screen.

### P7e — Selection
- [ ] An expanded playlist/channel shows a grid of selectable **entry tiles** (thumbnail when
      available, else a type icon); tapping toggles selection with a clear **selected** state.
- [ ] App bar shows the live **selected/total** count; **All** / **None** work.
- [ ] A failed link shows a per-source **error card**; a set that yields nothing shows the
      **empty** state.
- [ ] Bottom bar: **quality dropdown** + **tonal** "Add to queue" (held) + **accent** "Download
      now" (starts immediately); both route home with a "View queue" snackbar.
- [ ] Entry tiles show a **duration** caption when the source reports it.

### P7f — Queue
- [ ] Each task is a **card** with a status-colored **leading avatar** + glyph; the title is
      the media title (not the raw URL) with a `status · site · duration` line.
- [ ] A **progress bar** shows only while a task is **running/paused** (indeterminate at 0%),
      not for queued/done/canceled/failed.
- [ ] Per-task actions work: running/queued → Pause + Cancel (confirm); held → Start + Remove;
      paused → Resume + Remove; failed → Retry + Remove; done/canceled → Remove.
- [ ] **Summary pills** (running/queued/held/paused/done/failed) update live and match the
      tile status colors.
- [ ] App bar: **Start all / Resume all / Pause all / Clear completed** appear contextually;
      Back/Home never strands.
- [ ] Empty + active states render; loading shows the skeleton, load failure shows error+retry.

### P7g — Item Detail
- [ ] Hero media: a **video** plays (Chewie) and an **image** pinch-zooms; the thumbnail
      **Hero**-animates in from the library tile and back on pop.
- [ ] Large title + a `site · Saved <date>` subtitle; **detail chips** (type / duration /
      resolution / size) show when available.
- [ ] Metadata rows (uploader / username / playlist / uploaded date) appear when present; the
      **description expands/collapses** ("Show more" / "Show less").
- [ ] Tag chips render when the item has tags.
- [ ] **Save to device** is a prominent **accent** button showing the destination; after
      saving (or for an already-exported item) it shows the **"Saved to device"** state.
- [ ] Move / Edit / Studio app-bar actions work; loading shows a skeleton, a missing item
      shows the "Item not found" state.

### P7h — Metadata Edit
- [ ] Editing **Title** and **Notes** and tapping **Save** persists and is reflected on the
      item detail screen.
- [ ] **Tags**: add a tag (field + Add / submit) and remove via the chip's delete; updates live.
- [ ] **Collections**: create one inline via **New**, and toggle membership via the checkboxes;
      empty shows the "No collections yet." hint.
- [ ] Section headers (Details / Tags / Collections) and themed filled fields render cleanly;
      loading-skeleton / error / not-found states appear as expected.

### P7i — Media Studio
- [ ] A media **preview** shows above the tools; tools are grouped into clean cards.
- [ ] **Video**: Trim (range slider + MM:SS) produces a new item; Extract frame → image;
      rotate/flip/mirror/reverse/extract-audio each produce a new item (original kept).
- [ ] **Image**: rotate/flip/mirror and convert (JPG/PNG/WEBP) produce a new item.
- [ ] The **running overlay** (scrim + operation label + % + Cancel) shows during a job and
      **Cancel** aborts it; the result opens via the snackbar "Open" action.
- [ ] Unsupported types show the "Editing not available" empty state; loading/error/not-found
      render. *(Crop is deferred — see `docs/BACKLOG.md`.)*

### P7j — Collections
- [ ] The list shows each collection as a row (icon + name + **item count**) with a delete
      action; the **New collection** FAB opens a name dialog and creates one.
- [ ] Tapping a collection opens its scoped **media grid** (same cards as Library, Hero into
      detail); deleting a collection keeps its media in the library.
- [ ] Empty states render for no-collections and for an empty collection; loading shows the
      skeleton, load failure shows error+retry.

### P7k — Settings
- [ ] Each section (Downloads / Downloader engine / Storage / Appearance / Security) renders as
      an **icon header + grouped card**; loading shows the skeleton, load failure shows error+retry.
- [ ] Every control persists: Advanced mode, default quality, max-concurrent (1–5), Wi-Fi only,
      filename template (token chips + live preview), subtitles/thumbnail/metadata.
- [ ] Engine tile shows the yt-dlp version + **Update** (progress while running) + auto-check switch.
- [ ] Storage: auto-save switch + export-folder picker (and clear-to-default).
- [ ] Appearance: theme dropdown + dynamic-color switch apply live.
- [ ] Security: app-lock switch prompts a PIN; biometric switch appears only when lock is on.

### P7l — Disclaimer + App Lock
- [ ] First run shows the **branded disclaimer** (rabbit mark + shield + scrollable terms);
      tapping "I understand and agree" persists and leaves the screen (loading variant shows).
- [ ] With app-lock enabled, relaunch shows the **lock screen**; the correct PIN unlocks, a
      **wrong PIN** shows the error **and a shake**, and there's no back/nav escape.
- [ ] When biometric unlock is enabled, the biometric prompt appears and unlocks.

### P7 (overall)
- [ ] Every screen reflects the new **Material 3 Expressive** design (color/type/shape/
      motion) in light, dark, and dynamic-color modes — no leftover MVP styling.
- [ ] **Empty / loading (skeleton) / error** states render on each screen (empty
      library, loading grid, failed probe, etc.) — no bare spinners or raw error text.
- [ ] Layout adapts on a **large screen / unfolded foldable** (not a stretched phone
      layout); touch targets ≥48dp; text scales with the system font-size setting.
- [ ] **Simple vs Advanced** mode parity preserved across the revamped screens.

## P8 — v1 Beta & Production Readiness  *(v1)*
- [ ] Large library (100s of items) scrolls smoothly; big playlist picker is responsive.
- [ ] i18n scaffolding present; subtitle-language selection works (if shipped).

## Device-test refinements  *(v1, tracked in `docs/BACKLOG.md`)*
- [ ] Single video → **Download now** starts immediately; **Add to queue** holds it
      (shows "Held (batch)") until **Start all** runs it.
- [ ] After either single-video action the app returns **Home** with a snackbar
      ("Download started" / "Added to queue") whose **View queue** opens the queue.
- [ ] Playlist/batch picker: **Download now** runs the selection; **Add to queue**
      holds it; same Home + snackbar behaviour.
- [ ] The **Queue screen always has a working back/Home** control — reachable via the
      Home queue button (back) *and* after a download action (Home), never stranding you.
- [ ] Queue **header summary** reflects running/queued/held/paused/done/failed counts;
      **Resume all** re-queues paused tasks; **Pause all** / **Start all** still work.

---

## v1 release (full regression with the **release** APK)
1. **Release signing** configured (keystore + CI secret) so the release APK installs
   — done in **P8**.
2. Build with **Build APK → release = true**, install the signed release APK.
3. Run **every** section above (P0 → P8) end-to-end on a real device.
4. Confirm: privacy (nothing in Gallery until exported), app lock, background
   downloads, and playback all work on the AOT release build.
