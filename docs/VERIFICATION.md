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

### P7m — Adaptive layout + a11y
- [ ] **Phone (Compact):** a bottom **NavigationBar** with Library · Queue · Collections ·
      Settings; the Queue tab shows the pending **badge** + accent **running dot**, Collections
      shows its count badge; tapping a tab switches and keeps each tab's state.
- [ ] **Rotate / resize / tablet / unfolded foldable (Medium+):** the bottom bar becomes a
      **NavigationRail**; on a **laptop/desktop** window (Large+) the rail is **extended**
      (labels shown). Folding/unfolding moves between these without losing your place.
- [ ] Single-column screens (Add, Settings, Edit, Item Detail, Queue, Collections list,
      Disclaimer) are **centered and width-capped** on wide windows — not stretched edge-to-edge;
      the media **grids add columns** then cap/center on very wide/desktop windows.
- [ ] **TalkBack** announces the search-clear button and the **selected** state of
      selection/grid tiles; touch targets stay ≥48dp; at **200% font scale** nothing clips
      into an error.
- [ ] *(Deferred to P7n — needs a foldable device):* two-pane list-detail, hinge avoidance,
      tabletop posture.

### P7 (overall)
- [ ] Every screen reflects the new **Material 3 Expressive** design (color/type/shape/
      motion) in light, dark, and dynamic-color modes — no leftover MVP styling.
- [ ] **Empty / loading (skeleton) / error** states render on each screen (empty
      library, loading grid, failed probe, etc.) — no bare spinners or raw error text.
- [ ] Layout adapts on a **large screen / unfolded foldable** (not a stretched phone
      layout); touch targets ≥48dp; text scales with the system font-size setting.
- [ ] **Simple vs Advanced** mode parity preserved across the revamped screens.

## P8 — Download Engine Power & Intake  *(v1)*
- [ ] **Share-sheet intake**: share a link from YouTube / Instagram / a browser → GrabBit
      opens Add-Download pre-filled with that URL.
- [ ] **Power options**: a rate-limit and a concurrent-fragments setting take effect; an
      Advanced custom-arg is applied; re-running a playlist with the download archive on
      skips already-downloaded items.
- [ ] **Audio presets**: extract audio with a chosen codec/bitrate.
- [ ] **Subtitles / SponsorBlock / chapters**: download with selected subtitle languages;
      SponsorBlock segments are marked/removed; chapters embed, and split-chapters produces
      N separate library items.
- [ ] **Burn-in subtitles (Media Studio)**: an item with a subtitle sidecar → Studio →
      "Burn in <lang>" produces a hard-subbed new item (P8c).
- [ ] **Advanced format picker**: pick a concrete probed format (resolution/codec) in
      Advanced mode and the download honours it.

## P9 — Library, Playback & Privacy Depth  *(v1)*
- [ ] **DB upgrade (P9a)**: a P8-era library upgrades to schema **v4** cleanly (no data loss).
- [ ] **Favorites & sort (P9b-1)**: tap the tile star (and the item-detail star) → the Favorites
      chip filters to starred; the new sorts (Title Z–A, Smallest, Recently played) work.
- [ ] **Delete (P9b-1)**: item-detail Delete (confirm) removes it from the library and deletes
      the file.
- [ ] **Smart albums (P9b-2)**: Collections → **Albums** lists Platforms / Channels / Recently
      played; each opens the right filtered grid.
- [ ] **Duplicates (P9b-3)**: download the same video twice → Storage & cleanup → Find duplicates
      → Scan groups them; deleting one resolves the group.
- [ ] **Storage (P9b-3)**: Settings → Storage & cleanup shows total + by-type/by-platform
      breakdown and largest items; deleting a large item frees space.
- [ ] **Preventive dedupe (P9b-4)**: re-paste a saved URL → "Already in your library" banner
      (Open jumps to it; download still works); a playlist with saved items shows "Saved" badges
      and the Hide-already-saved toggle hides/deselects them.
- [ ] **Player (P9c-1)**: change playback speed; toggle Loop; pick a subtitle track; screen stays
      awake during playback; after playing, the item appears under Albums → Recently played.
- [ ] **Queue reorder (P9d)**: drag a queued task to a new position → the order persists across an
      app restart, and the next download starts in the new order (the top queued task runs first).
- [ ] **Queue dashboard (P9d)**: during real downloads the header shows overall progress, counts
      ("N downloading · M queued · K done"), combined **live speed**, longest **ETA**, and total
      size when known; it disappears once nothing is active.
      *(Picture-in-Picture (was P9c-2) is deferred — see `docs/BACKLOG.md`.)*
- [ ] **Block screenshots (P9e)**: with the Privacy → "Block screenshots" toggle ON, a screenshot
      is blocked and the recent-apps preview is blank; with it OFF, screenshots/recording work
      again (the setting is honored at startup, not just after toggling).
- [ ] **Auto-lock (P9e)**: with app-lock on and Auto-lock = 1 minute, leaving and returning within
      a minute does **not** require the PIN, but returning after a minute (or with "Immediately")
      shows the lock screen; a cold start always locks.
- [ ] **PIN lockout (P9e)**: entering a wrong PIN shakes + buzzes; after 5 wrong tries the lock
      screen shows a countdown and disables Unlock + biometrics, and the cooldown **survives an app
      restart**; a correct PIN clears it.
- [ ] **PIN management (P9e)**: setting a PIN requires entering it twice (mismatch is rejected);
      "Change PIN" updates it; turning app-lock off is confirm-gated and removes the PIN.
- [ ] **Secure delete (P9e)**: with Privacy → "Secure delete" ON, deleting a private item removes
      it (best-effort overwrite; verify the file is gone and the item leaves the library).
- [ ] **Low-storage guard (P9f)**: set "Pause when storage is low" and fill the device near the
      threshold → new downloads stay queued with a "Paused — low storage" banner; freeing space
      resumes them. (A download that fills the disk mid-run still fails with "Not enough storage".)
- [ ] **Battery pause (P9f)**: enable "Pause on low battery" → downloads hold below the threshold or
      in OS power-saver, and resume when charging / above the threshold.
- [ ] **Cleanup (P9f)**: Storage → "Clean up leftover files" reclaims space from orphaned files left
      by past deletions and reports the amount; library items are untouched.
- [ ] **Device space (P9f)**: the Storage screen shows real device usage ("X used of Y, Z free"),
      not just GrabBit's own usage.
- [ ] **Item context menu (P9g)**: long-press a tile in the Library / a Collection / a Smart album /
      Storage-largest / Duplicates → the action sheet opens; Save to device, Add to collection, Move
      to folder, and Delete all work without opening the detail screen.
- [ ] **Share & links (P9g)**: "Share file" opens the Android share sheet with the actual file;
      "Open source link" opens the source in a browser; "Copy source URL" puts it on the clipboard.
- [ ] **Queue task menu (P9g)**: a task's ⋮ menu moves it to the top/bottom of the queue (persists)
      and copies/opens its source URL.
- [ ] **Collection rename (P9g)**: a collection's ⋮ menu renames it (and still deletes).
- [ ] **Library multi-select (P9h)**: long-press a tile → "Select" enters multi-select; tapping more
      tiles grows the count; "Select all" and "Clear" work; the bulk bar's Delete / Save / Move /
      Add-to-collection / Favorite / Share act on every selected item.
- [ ] **Collection/album actions (P9i)**: a collection or smart album sorts within (newest/title/
      largest…) and "Share all" shares every file; a collection's app-bar menu renames/deletes it.
- [ ] **Whole-queue actions (P9i)**: the queue's app-bar menu offers Retry all failed, Cancel all,
      and Clear finished, each acting on the matching tasks.
- [ ] **Item-detail (P9i)**: the app bar is Favorite + a single ⋮ menu (Save/Move/Studio/Edit/Share/
      Copy/Open/Delete); the body shows "Last played" and the collections the item belongs to.
- [ ] **Settings overflow (P9j)**: the Settings app bar's ⋮ menu offers Reset to defaults / Clear
      cache / About. **Reset** (after confirm) reverts download/appearance/storage/privacy prefs while
      the app lock (PIN still works) and accepted disclaimer stay intact. **Clear cache** frees temp
      space and reports "Freed X".
- [ ] **About screen (P9j)**: shows the real app version "vX.Y.Z (build N)"; "Open-source licenses"
      opens the license page; the disclaimer tile opens the user-responsibility screen.
- [ ] **Studio post-op (P9j)**: after an edit completes, the snackbar's **Actions** opens the action
      sheet for the new item — Share it out and Add it to a collection from there.
- [ ] **AMOLED dark theme (P9k)**: Settings → Appearance → "Pure black (AMOLED)" — in dark mode the
      background turns true black while cards/inputs/app bar stay distinguishable; light mode and
      dynamic color are unaffected; the choice persists across restarts.
- [ ] **Cross-fade loading (P9l)**: opening Library/Queue/Collections/a smart album/an item/Studio,
      the skeleton **cross-fades** into the loaded content (no abrupt snap); pull-to-refresh still works
      and does **not** re-trigger the fade.
- [ ] **Selection bar animation (P9l)**: entering multi-select (library grid and folder explorer) — the
      bottom action bar **slides/grows up and fades in**; clearing the selection collapses it back out
      smoothly rather than popping.
- [ ] **Favorite pop (P9l)**: on an item's detail screen, tapping the star **scale-pops** between
      filled/outline.
- [ ] **Storage states (P9m)**: open Storage & cleanup — a **shimmering skeleton** shows while usage
      loads, then cross-fades to the breakdown; if a query fails the screen shows an **error with a
      Retry** (rather than a silent zeroed screen).
- [ ] **Empty-state CTAs (P9m)**: with an empty queue, the empty state offers **"Add a link"** that
      opens the add-download screen; in an empty folder, **"Create folder"** opens the create-folder
      prompt.

## P10 — Baseline edge AI + Cozo graph/vector foundation  *(v1)*

### P10a — Cozo engine foundation  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Engine loads (arm64)**: Settings → About → **Graph engine self-test** → snackbar reads
      **"Graph OK — N relations ready"** (N = the deterministic node/edge relations).
- [ ] **Persists across restart**: force-quit and reopen → run the self-test again → still
      "Graph OK" with the same N (schema not recreated; the SQLite file at `<app-support>/graph/`
      survived).
- [ ] **Core unaffected**: the downloader/library/queue all work exactly as before (the graph
      engine is additive).
- [ ] **Graceful degrade (optional)**: on a non-arm64 build (e.g. an `x86_64` emulator, where the
      Cozo lib isn't bundled) the self-test reports **"unavailable"** and the app does **not** crash.

### P10b-1 — Graph sync (Drift→Cozo projection)
- [ ] **Library projects into the graph**: with an empty library the About self-test shows
      "0 media · 0 edges"; after downloading an item, within ~2s it shows **media/edges > 0**
      (e.g. media ≥ 1, edges ≥ 1 for `onPlatform`).
- [ ] **Edits reflect**: favorite/tag/move-to-folder/add-to-collection an item → counts/edges update
      (re-run the self-test); **delete** an item → media count drops (no orphan left).
- [ ] **Manual rebuild**: Settings → Graph database → **Rebuild graph index** → snackbar reports
      "Graph rebuilt — M media · K edges".
- [ ] **Persists across restart**: force-quit + reopen → self-test still reports the same counts
      (no rebuild needed); the downloader/library are unaffected throughout.

### P10b-2a — Embedder foundation + first-run AI setup  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **First run shows AI setup**: a fresh install → disclaimer → after accepting, the
      **"Set up AI features"** screen appears (before Home).
- [ ] **Skip works**: tap **Skip for now** → lands on Home, no download; force-quit + reopen → the
      AI-setup screen is **not** shown again.
- [ ] **Set up downloads the model**: re-install (or enable from Settings) → **Set up** →
      a progress bar runs to 100% (~114 MB Gecko_256, one time) → lands on Home.
- [ ] **Settings opt-in**: Settings → Graph database → **Semantic search** toggle off by default;
      turning it on downloads the model (snackbar "Semantic search ready"); turning it off stops use.
- [ ] **Test embedder**: Settings → Graph database → **Test embedder** → after the model is
      downloaded, snackbar reads **"Embedder OK — 768-d · N embedded"**; before download it reads
      "enable Semantic search first".
- [ ] **Existing-install upgrade**: updating over a prior install does **not** show the AI-setup
      screen, and semantic search stays off until opted in.
- [ ] **Graceful without AI**: with semantic search off (or on a device where the embedder can't
      load), the downloader/library/queue/graph all work exactly as before.

### P10b-2b — vector index (cached embedding backfill)  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Initial index**: with a non-empty library, enable **Semantic search** (or AI-setup → Set up) →
      after the download, **Test embedder** reports "768-d · **N embedded**" where N = library size.
- [ ] **Incremental add**: download a new item → within ~2 s the embedded count goes **N+1** (only the
      new item embedded, not the whole library).
- [ ] **Edit re-embeds**: rename an item (or edit its metadata) → it's re-embedded (cache invalidates);
      counts stay consistent.
- [ ] **Delete prunes**: delete an item → embedded count drops by 1 (no orphan vector left).
- [ ] **Cached across restart**: force-quit + reopen → embeddings persist; **no re-download, no
      re-embed** (count unchanged, instant).
- [ ] **Off = no work**: with Semantic search disabled, adding/deleting items does no embedding work;
      Test embedder reads "enable Semantic search first".
- [ ] **Non-arm64 / never-opted-in**: zero AI work; the graph's deterministic features + the whole app
      are unaffected.

### P10b-3 — Cozo hardening + deterministic edges  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Close on background / reopen**: open the app, background it, return → the graph self-test
      (About) still reports OK (store reopened cleanly, no SQLite-lock error); downloads keep working
      across background/foreground cycles.
- [ ] **`duplicateOf`**: download the same file/URL twice (so two items share a `contentHash`) →
      after sync the graph edge count rises (duplicate pair recorded).
- [ ] **`coDownloadedWith`**: queue a burst of downloads close together → edges link them; items
      downloaded far apart (>5 min) are not linked.
- [ ] **Model self-heal (manual/dev)**: this isn't user-triggerable in v1 (one pinned model) — only
      relevant if the embedder model/dim ever changes; the `embedding_meta` guard then rebuilds the
      index. No user step.
- [ ] **Batch embedding**: enabling Semantic search on a non-trivial library still completes embedding
      with no regression (now in batches); Test embedder reports the expected count.
- [ ] **Malformed query**: the graph self-test / app never hard-crashes on a bad CozoScript — errors
      surface as a friendly message.

### P10c-a — Query foundation + semantic search  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Smart toggle gated on AI**: with Semantic search **off** (or on a device the embedder can't
      run), the Library search bar shows **no Text/Smart toggle** and behaves exactly as before.
- [ ] **Opt in → toggle appears**: enable Semantic search (download the model) → a **Text / Smart**
      toggle appears above the Library search box.
- [ ] **Semantic relevance, offline**: in **Smart** mode, type a meaning-based query (not a literal
      title word) and submit → relevant items rank to the top; confirm in **airplane mode** (fully
      on-device). Empty query shows the "Smart search" prompt, not the empty-library state.
- [ ] **Submit, not live**: results update on **submit** (keyboard search action), not on every
      keystroke; Text mode stays live-as-you-type.
- [ ] **No crash on empty/cold index**: Smart search before any embeddings exist returns a friendly
      "No matches", never a crash.

### P10c-b — Related / "More like this"  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Related appears on detail**: open an item that shares an uploader/playlist/tag (or was
      downloaded alongside others) → a **"More like this"** carousel shows sensible related items;
      tapping one opens that item's detail.
- [ ] **Works without AI**: with Semantic search **off** (no embeddings), Related still appears for
      items with graph links (same uploader/playlist/tag/co-download) — purely on-device, offline.
- [ ] **Better with AI**: with embeddings present, semantically similar items (not just same-uploader)
      surface and rank near the top.
- [ ] **No duplicates / no self**: the source item never lists itself, and exact duplicates of it
      don't appear in Related (they belong to near-dup clusters, P10c-d).
- [ ] **Graceful empty**: an item with no relations (and no embeddings) shows **no** Related section
      rather than an empty box; never crashes on a cold graph.

### P10c-c-1 — Navigable entity hubs  *(no AI/graph needed — works on any build)*
- [ ] **Tap an uploader**: on item detail, tapping the uploader row opens a hub listing every item
      from that channel.
- [ ] **Tap a tag**: tapping a tag chip opens a hub of all items with that tag.
- [ ] **Tap the platform**: tapping the site (under the title) opens a hub of all items from that
      platform; **tap a playlist** opens that playlist's items.
- [ ] **Sort works**: the hub's sort button reorders (newest/oldest/title/size); back returns to the
      item.
- [ ] **Share all**: the hub's **Share all** action shares every item in that hub.
- [ ] **Empty/edge**: an entity with no other items shows the "Nothing here" empty state; tags/uploaders
      with `/` or unusual characters still open the right hub (value is URL-encoded).

### P10c-c-2 — Graph tag suggestions + related-tags strip  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Tag suggestions appear**: open an item's editor (Edit info) where the library has other items
      sharing its uploader/playlist/tags → a **"Suggested"** row of tag chips appears under the tag
      field; tapping one applies it (and it drops out of the suggestions).
- [ ] **Suggestions exclude existing tags**: a tag already on the item is never suggested.
- [ ] **Related-tags strip on hubs**: open an entity hub (uploader/playlist/tag/site) whose items carry
      tags → a **"Related tags"** strip shows the common tags; tapping a chip opens that tag's hub. A
      tag hub never lists its own tag. Check an **uploader** hub specifically — its name→`uploaderId`
      bridge (via the `uploader` node) is the path CI can't exercise.
- [ ] **Graceful without the graph**: on a device/build with no graph (or empty index), neither the
      suggestions row nor the related-tags strip appears — the editor and hubs are unchanged, no crash.

### P10c-d-1 — Duplicates album + bulk cleanup  *(no AI/graph needed — works on any build)*
- [ ] **Card appears/hides**: with duplicate copies present (Scan in the Duplicates screen if needed)
      → Collections → Albums shows a distinct **Duplicates** card summarizing "M groups · N extra
      copies"; with no duplicates the card is absent.
- [ ] **Clean up (bulk)**: tap **Clean up** → a confirm names the count → confirming removes the
      extras (keeps the oldest of each group); the card updates/hides. The same action exists on the
      Duplicates screen's app bar.
- [ ] **Review + compare**: **Review** opens the Duplicates screen; each row shows **date · size** and
      the kept (oldest) copy carries a **"Keep"** badge; per-item delete still works.
- [ ] **Secure delete honored**: with secure-delete on, bulk Clean up routes through the same secure
      deletion as single deletes.

### P10c-d-2 — Suggested similarity albums + Save  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Suggested section appears**: with Semantic search on and very-similar items present (e.g. the
      same video re-encoded, or near-identical clips) → Collections → Albums shows a **Suggested**
      section of clusters labelled `Like '<title>'`.
- [ ] **Open + Save**: opening a suggestion lists its items (sortable); **Save** prompts a name and
      creates a real collection containing them (verify under the Collections tab).
- [ ] **High precision / no blobs**: suggestions are cohesive (genuinely similar), exclude exact
      byte-identical copies (those live in the Duplicates album), and there's no single giant catch-all
      cluster.
- [ ] **Graceful without AI**: with Semantic search off / unsupported, no Suggested section appears
      (the Duplicates album still works); no crash on a cold/empty index.

### P10c-e — Interactive graph viz: render  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Neighborhood renders**: open a well-connected item → overflow menu → **View in graph** → a
      force-directed graph shows the item at the centre with its channel/playlist/platform/tags and any
      duplicate/co-downloaded media around it.
- [ ] **Pan/zoom + legend**: the graph pans and zooms; the legend maps each colour/icon to its relation
      (Channel/Playlist/Platform/Tag/Duplicate/Co-downloaded).
- [ ] **No embedder needed**: works with **Semantic search off** (deterministic edges); an item with no
      edges shows "No connections yet".
- [ ] **Graceful absence**: on a build/device without the graph the "View in graph" menu item is absent
      and the screen (if reached) shows "Graph unavailable"; no crash on a cold graph.

### P10c-f — Interactive graph viz: interaction  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Tap a media node** (centre / duplicate / co-downloaded / expanded item) → opens that item.
- [ ] **Tap an entity node** (channel/playlist/platform/tag) → expands to show its media as child
      nodes (spinner while loading); tap again collapses.
- [ ] **Long-press** any node → sheet: media → "Open item"; entity → "Open hub" + "Expand/Collapse".
- [ ] **Edge filters**: the legend chips toggle each relation's nodes/edges on and off.
- [ ] **Bounded**: an entity with many items expands to a capped set (no runaway); pan/zoom stay smooth.

### P10d-1 — Dashboard: foundation  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Default landing**: a cold launch opens on the **Dashboard** (`/`), now the first of **5** nav
      destinations (Dashboard · Library · Queue · Collections · Settings).
- [ ] **Library moved**: the Library opens from its own (2nd) destination; the FAB **Add** flow,
      batch **selection**, and the queue **Home** button all still land somewhere sensible (now the
      Dashboard).
- [ ] **Onboarding**: a brand-new install (disclaimer → AI setup) ends on the Dashboard; enabling the
      app lock and unlocking also returns to the Dashboard.
- [ ] **Stat tiles**: library count, storage used (with device "free of total" when available), queue
      pending (+ "N downloading" while active), and collections count show real values and **tap
      through** to the matching screen.
- [ ] **Honest states**: a fresh install shows the empty state with an **Add a download** action; the
      tiles shimmer while loading.
- [ ] **5 tabs on a narrow phone** stay usable; on a tablet/foldable the rail shows all five.

### P10d-2 — Dashboard: charts  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Storage by type / by platform** donuts render with a centre total and a legend (label +
      size); percentages on the larger slices; small platforms fold into a muted **"Other"** slice
      (visible with 6+ platforms).
- [ ] **Library activity** bars show additions over the last 30 days; weekly date ticks (intl), no
      clipped/overlapping labels at phone width.
- [ ] **Honest per-tile states**: with a populated library the charts draw; on an empty/partial
      library the tile shows its compact "no data" message; each shimmers while loading and offers
      **Retry** on error.
- [ ] **Dark + AMOLED**: slice colours keep contrast against the surface; "Other" reads muted but
      visible.
- [ ] **Dynamic colour** (Material You wallpaper): the palette retints; no clashing hard-coded hues.
- [ ] **RTL** (e.g. Arabic): legend/axis alignment mirrors; date labels still render.

### P10d-3 — Dashboard: content tiles  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Recently added** row shows newest downloads; tapping a tile opens the item; **See all** →
      Library.
- [ ] **Recently opened** row appears only after opening some items and reflects access order;
      stays hidden on a never-opened library.
- [ ] **Suggested for you** appears only with semantic search ON and ≥1 cluster; tapping a row opens
      the suggestion → **Save as collection** works; hidden when AI is off.
- [ ] **Duplicates** callout appears only when exact duplicates exist; **Review** → Duplicates screen.
- [ ] **Explore graph** card appears on a graph-capable device with ≥1 item and opens the seed item's
      graph; **absent** on a build/device where the graph is unavailable.
- [ ] **Auto-hide**: a fresh/empty library shows only the stat cards + chart empty states (no content
      tiles); each tile appears the moment it has something to show.

### P10e — Extractive TextRank summary
- [ ] An item with a **long description** shows a **Summary** TL;DR (bullet sentences) above the full
      metadata/description — on *any* device, **no** model download and **no** network.
- [ ] Items with **no / short** descriptions show **no** Summary section (auto-hidden).
- [ ] Summary bullets are **verbatim excerpts** of the description (extractive), readable, and stable
      across reopening the item.
- [ ] Runs on a **low-end device** without jank or crash (pure Dart, synchronous, tiny input).

### P10f-1 — Transcript-text capture (pure-Dart)
- [ ] Download an item **with subtitles enabled** (so `.vtt/.srt` sidecars land), then **More → Get
      transcript** → a **Transcript** section appears with the spoken text (built offline from the local
      captions), and the **Summary** now derives from the transcript (not the description).
- [ ] **Settings → Auto-build transcripts** ON → a fresh download that has captions gets a transcript
      with no manual step.
- [ ] **Settings → Backfill transcripts on open** ON → opening an older item that has sidecars builds
      its transcript once (Transcript/Summary appear after a moment).
- [ ] Auto-caption "rollover" repetition is **de-duplicated** — the transcript reads as continuous
      text, not repeated phrases.
- [ ] Both Settings toggles show an **(i)** info affordance explaining what they do.

### P10f-2 — On-demand caption fetch (native — needs an APK build)
- [ ] On an item with **no local captions**, **More → Get transcript** opens a **language picker**
      (default = app language); pick one → captions fetch over the network → a **Transcript** section +
      transcript-derived **Summary** appear, and the fetched subtitle is also selectable in the player.
- [ ] **Other…** in the picker accepts a typed language code (e.g. `nl`).
- [ ] Picking a language the video lacks → *"No captions available in <Language>"* (no crash);
      offline / bad URL → *"Couldn't fetch captions…"*.
- [ ] The fetch creates **no entry in the download Queue** and **no new library item**.
- [ ] An item that already has local captions still builds **offline** (no network) via the same action.

### P10f-3 — Auto-download captions setting (needs an APK build)
- [ ] **Settings → Transcripts** shows a dedicated section with **Auto-download captions**,
      **Auto-build transcripts**, and **Backfill transcripts on open** (each with an `(i)` tooltip).
- [ ] Turn **Auto-download captions** ON (leave "Download subtitles" off) → download a captioned video →
      a caption file is fetched; with **Auto-build transcripts** also on, a **Transcript** + Summary
      appear with no manual step.
- [ ] A video with **no** captions → downloads fine, no error, no transcript.
- [ ] With explicit **Download subtitles** languages set, those still win (the setting doesn't override).

### P10f-4 — Timestamped, tap-to-seek transcript (needs an APK build)
- [ ] On a **video/audio** item with a transcript, the Transcript section shows **timestamped lines**
      (`m:ss` + text) in a scrollable block with **Show full transcript** / **Show less**.
- [ ] **Tapping a line seeks** the player to that time.
- [ ] During playback, the **current line highlights** and the list **auto-scrolls** to keep it visible.
- [ ] An **image** item (no player) — or a transcript whose caption sidecar was removed — shows the
      **flat** transcript (no timestamps), with no crash.
- [ ] A transcript captured **before P10f-4** (no stored cues) gains the synced view on first open
      (cues are derived from the sidecar and saved).

### P10g-1 — Transcript-powered semantic index (Gecko_256) (needs an APK build)
- [ ] Enabling **Semantic search** downloads **Gecko_256 (~114 MB)**; **Test embedder** reports
      "768-d · N embedded".
- [ ] **Transcript-powered:** an item whose **transcript** (not its title/description) mentions a term
      is returned when you search that term.
- [ ] **Model upgrade:** a user who already had the old `Gecko_64` model + semantic search on sees an
      **"Update AI model"** row in Settings (no silent download); tapping it fetches Gecko_256 and
      re-embeds. Declining leaves the app working.
- [ ] On a device that can't run the model, semantic search degrades gracefully (no crash).
- [ ] **Known limitation (until P12):** Gecko is English-optimized — non-English queries/content return
      results without crashing, but relevance is weaker. The multilingual engine lands in P12.

### P10g-2 — Pluggable embedder registry (pure architecture; CI-covered)
- [ ] No new user-facing surface — covered by `flutter test` (factory model-propagation + Unavailable
      fallback + `activeEmbedderModel` default). On-device sanity: semantic search + "related" behave
      exactly as P10g-1 and **Test embedder** still reports "768-d · N embedded" (the refactor is transparent).

### P10h — Full-text search over transcripts & metadata (FTS5)  *(no AI/graph needed — works on any build)*
- [ ] **Search by spoken content:** an item whose **transcript** (not its title/description) mentions a
      word is returned in the **keyword** (non-semantic) search when you type that word.
- [ ] **Relevance auto-select:** typing a query switches the sort to **Relevance** automatically; the
      strongest matches appear first; clearing the query restores the previous sort. Picking another sort
      while a query is active overrides it (and is kept as you refine the query).
- [ ] **Has-transcript filter:** toggling it in the filter sheet narrows the grid to items with captions;
      "Clear all" resets it.
- [ ] **Migration/backfill:** an app **upgraded from a pre-P10h build** can immediately search its
      **existing** library (the v6→v7 backfill ran) — including by transcript text captured earlier.
- [ ] **Live updates:** editing a title or (re)building a transcript updates search results without a
      restart; odd characters in the query (`-`, `"`, `:`) never error.

### P10i-a — Multi-select type filter + type-aware option narrowing  *(no AI/graph needed — works on any build)*
- [ ] **Multi-select types:** the Video / Audio / Image chips toggle independently; selecting several shows
      the **union** of those types; deselecting all (none selected) shows everything.
- [ ] **Type-aware narrowing:** with **only Image** selected, the **Has transcript** row disappears from the
      filter sheet; reselecting Video/Audio brings it back.
- [ ] **Reconciliation:** turning **Has transcript** on, then narrowing to **Image-only**, silently clears it
      (no stuck/hidden filter); the grid isn't left empty by an inapplicable filter.

### P10i-b — Duration & upload-date sorts  *(no AI/graph needed — works on any build)*
- [ ] **Type-aware sorts:** the **Longest / Shortest** sort options appear only when the type selection
      includes Video/Audio; they vanish for an **Image-only** selection and return when Video/Audio is
      reselected. **Newest/Oldest uploaded** appear for every selection.
- [ ] **Duration order:** sorting by **Longest / Shortest** orders by media length; items with **no known
      duration** (split-chapter files, images) sort **last** in both directions — they never float to the top.
- [ ] **Upload-date order:** sorting by **Newest/Oldest uploaded** orders by the source's original upload
      date (not the download date); items lacking an upload date sort **last**.
- [ ] **Reconciliation:** pick **Longest**, then narrow to **Image-only** → the sort silently resets
      (Newest) and the grid isn't left empty. Run a **search** (→ Relevance), narrow to **Image-only**, then
      clear the search → the restored sort is valid (not a stuck/hidden duration sort).

### P10i-c — Media dimensions: capture & backfill  *(no AI/graph needed — works on any build)*
- [ ] **Video capture:** download a video → its detail screen shows a resolution chip (e.g. `1920×1080`).
- [ ] **Image capture:** download an image → the chip shows the image's pixel size.
- [ ] **Audio:** download audio → **no** resolution chip (audio has no dimensions, correctly).
- [ ] **Split-chapters:** a `--split-chapters` download → each chapter item shows the source video's
      resolution.
- [ ] **Migration / upgrade:** install over a build that predates this work (or whose DB lacks the
      width/height columns) → the app **opens without a "no such column" crash**.
- [ ] **Backfill:** after upgrading, existing **video/image** items gain resolution chips within a moment
      of relaunch (background backfill); **audio** items stay chip-less and aren't re-scanned every launch.

### P10i-d — Range filters + quality filter + sectioned sheet  *(no AI/graph needed — works on any build)*
- [ ] Open **Filters** → the sheet shows labelled sections (Duration · Resolution · Downloaded · Uploaded ·
      Content · Platform/Channel/Playlist) and **scrolls** without overflow on a small screen.
- [ ] **Duration / Resolution buckets:** selecting a bucket narrows the grid; tapping the **active** chip
      clears it. "4K" shows only ≥2160p items; items with unknown duration/size are **excluded**.
- [ ] **Downloaded / Uploaded buckets:** narrow by the right date; items with **no upload date** are
      excluded from an Uploaded bucket.
- [ ] **Type-aware:** with **Image-only** selected the **Duration** section hides (and an active duration
      bucket clears); with **Audio-only** the **Resolution** section hides; reselecting brings them back.
- [ ] The filter **badge** count includes active buckets; **Clear all** resets every filter incl. buckets.
- [ ] **Tag facet (consistency sweep):** the filter sheet shows a **Tag** dropdown listing tags in use;
      picking one narrows the grid to items with that tag, counts toward the badge, and is reset by
      **Clear all**; the tag entity-hub still works unchanged.

### P10j-a — Settings widget foundation + touch-friendly help  *(no AI/graph needed — works on any build)*
- [ ] **Settings renders unchanged:** every section (Downloads, Transcripts, Advanced download options in
      Advanced mode, Downloader engine, Storage, Appearance, Security, Privacy, Graph database) and every
      control still appears, toggles, and persists exactly as before (behavior-preserving refactor).
- [ ] **Info help opens on a single tap** (not long-press): tap the **(i)** on any Transcripts row →
      a bottom sheet with the setting's title + plain-language explanation appears; dismiss by swipe/scrim.
- [ ] Dropdowns (quality, theme, audio format, etc.) still open and apply the chosen value.

### P10j-b — Captions & transcripts unified section  *(no AI/graph needed — works on any build)*
- [ ] Settings shows **one "Captions & transcripts" section** (the old separate *Transcripts* group and
      the *Downloads* subtitle rows are gone); it reads as a pipeline: download captions → build a
      searchable transcript.
- [ ] **Behavior unchanged — download with explicit caption languages:** turn on **Download captions**,
      set a language, download a video that has subtitles → the caption file is written exactly as before.
- [ ] **Behavior unchanged — auto-fetch only:** leave **Download captions** off, turn on **Auto-fetch
      captions for transcripts**, download → captions are fetched in the app's language so a transcript
      can build (same as the pre-P10j "Auto-download captions"). The `(i)` on that row explains the
      precedence (picked caption languages win).
- [ ] **Backfill is independent:** with **Build a searchable transcript** OFF, **Backfill on open** is
      still visible and still builds a transcript when you open an older captioned item.
- [ ] Toggling **Download captions** reveals/hides the Caption languages / Caption format detail rows.

### P10j-c1 — Hybrid IA: settings sub-screens + General section  *(no AI/graph needed — works on any build)*
- [ ] The **Settings landing** is short: a nav card with **Downloads**, **Captions & transcripts**,
      **AI & graph** links, then **Downloader engine**, **Storage**, **Appearance**, **Security**,
      **Privacy**, **General** inline.
- [ ] Each nav row **opens its sub-screen** (own AppBar + back): Downloads holds the download options
      (and Advanced download options in Advanced mode); Captions & transcripts holds the P10j-b pipeline;
      AI & graph holds rebuild / semantic search / test embedder. Back returns to the landing.
- [ ] Every moved control still **persists** (e.g. toggle Advanced mode / Faster downloads on the
      Downloads sub-screen, Download captions on the Captions sub-screen) and survives leaving + reopening.
- [ ] **General section** runs the maintenance actions: **About** opens the About screen; **Reset to
      defaults** confirms then resets; **Clear cache** frees temporary files. The `⋮` overflow still works.

### P10j-c2 — settings search + InfoHint rollout  *(no AI/graph needed — works on any build)*
- [ ] The **search bar** atop Settings filters as you type: e.g. "sponsorblock", "amoled", "subtitles"
      (synonym) each show matching controls with their section name.
- [ ] Tapping a **sub-screen** result opens that sub-screen (e.g. "SponsorBlock" → Downloads); tapping a
      **landing** result clears the search and scrolls that section into view.
- [ ] **No results** shows a clean "No settings match …" message; clearing the field restores the landing.
- [ ] The new `(i)` **hints** open on tap (single tap, not long-press) on: Faster downloads, Concurrent
      fragments, Download speed limit, Pause when storage is low, Low-battery threshold,
      Skip already-downloaded, SponsorBlock (Downloads); Semantic search, Rebuild graph index (AI & graph);
      Secure delete, Dynamic color, Pure black (AMOLED) (landing).

## P11 — Activity Inbox  *(v1)*
*(Forward-looking — detailed checks added per subphase as the phase is built.)*

### P11a — Notifications data foundation  *(no AI/graph needed — works on any build)*
- [ ] A debug APK built over an **existing pre-P11 install** opens with **no data loss** — the
      schema v8→v9 upgrade adds the `notifications` table without disturbing library/queue/settings.
      (No inbox UI yet; this is the migration smoke check. The seam, repository, retention sweep and
      gating are CI-covered by unit tests.)

### P11b — Inbox UX + notification settings  *(no AI/graph needed — works on any build)*
*(No producers yet — P11c wires real events. To exercise P11b on-device, post a couple of synthetic
entries, or verify after P11c lands.)*
- [ ] The Dashboard app-bar **bell** shows an **unread badge** when there are unread entries; tapping
      it opens the **Activity** inbox and the badge **clears** (opening marks all read).
- [ ] The inbox lists entries **newest-first** with severity-styled icons; **swipe** a row to dismiss
      it; **category filter chips** narrow the list; **Clear all** (with confirm) empties it.
- [ ] Tapping an entry that has a target **deep-links** to the relevant screen.
- [ ] The Dashboard **recent-activity tile** shows the latest entries (and is **hidden** when there
      are none); **See all** opens the inbox.
- [ ] **Settings → Notifications**: the four category toggles and the retention choice (Forever /
      7 / 14 / 30 / 90 days) **persist across relaunch**; settings **search** finds them
      (e.g. "retention", "download notifications").

### P11c — producers wired through the seam  *(no AI/graph needed — works on any build)*
- [ ] A real **download completing** adds a "Downloaded" entry that **deep-links to the item**
      (split-chapter downloads link to the library; the entry shows "Saved N files").
- [ ] A **failed** download (e.g. a bad/unsupported link) adds an **error** entry with a friendly
      reason that links to the queue — and it appears **even with the Downloads toggle off** (errors
      are always recorded). A **transient retry** does **not** post; only the terminal failure does.
- [ ] **Canceling** a download posts **nothing**.
- [ ] With **auto-transcribe on**, a captioned download adds a separate "Transcript ready" entry
      (one per download); with the **Transcripts toggle off**, none. Opening an item and letting the
      offline backfill build a transcript posts **nothing** (foreground).
- [ ] **Settings → AI & graph → Rebuild graph index** adds a **graph** entry (success with counts, or
      "Graph engine unavailable"); a normal **library edit** (which triggers the debounced auto-sync)
      posts **nothing**.
- [ ] Opening the Inbox **sweeps expired** entries (per the retention setting; "Forever" keeps them).

### P11d — OS notifications  *(native — needs an APK build)*
- [ ] With the app **backgrounded**, a finished download raises a system notification on the
      **Activity** channel; tapping it opens the item (and works from a **cold start** — app fully
      killed, tap launches into the item).
- [ ] A backgrounded **failed** download raises a notification that opens the **queue**.
- [ ] A completion while the app is **foregrounded** raises **no** system notification (the in-app
      inbox/badge still updates).
- [ ] Turning off **Settings → Notifications → Download activity** suppresses the system popup, while
      a failure is still recorded in the in-app inbox.
- [ ] Everything stays **on-device** (no network/telemetry) and the Inbox is **behind the app lock**.

### P11e — Actionable inbox entries + per-item read  *(no AI/graph needed — works on any build)*
- [ ] A **failed-download** entry's `⋮` (or long-press) offers **Retry** → the download re-runs and the
      stale error entry disappears (with a "Retrying…" snackbar).
- [ ] **Open source URL** launches the original link in the browser; **Copy source URL** copies it —
      for both a **completed** entry (from the item) and a **failed** one (from the queue task).
- [ ] **Share file** on a completed entry opens the system share sheet for the downloaded file.
- [ ] **Dismiss** from the menu removes the entry (matching swipe-to-dismiss).
- [ ] An entry whose item/task was deleted hides the actions that no longer apply (no crash).
- [ ] Entries stay **unread (bold + dot)** until tapped; opening the inbox no longer clears everything;
      the bell badge decrements as entries are read; **Mark all read** clears the badge in one tap.

## P12 — Device-tiered edge LLM engine  *(v1)*
> **On-device pass (owed).** P12's native paths (the tier probe, onnxruntime embedder, flutter_gemma
> generation, whisper transcription) can't be CI-verified — the rows below are the one manual regression
> pass to run on **two devices: one low-RAM (Basic tier) + one mid/high-RAM (Standard/Advanced)**.
> Run top-to-bottom on each; the embedder+LLM+whisper "coexist" rows and the "persists across restart"
> rows only need the capable device. Subphase tags are kept for traceability. *(Pure-Dart subphases
> (P12b, c-1, d-1, e-1) have no row — they're CI-tested.)*
- [ ] **(P12a)** On launch, logcat shows `[P12a] device tier: <tier>  (DeviceProfile(ramMb: …))` whose
      RAM/tier match the real device — spot-check on **two** phones (one low-RAM, one high-RAM). The app
      behaves identically (embedder still Gecko; semantic search unaffected). *(No UI in P12a — the tier
      is surfaced in Settings in P12g.)*
- _(P12b) Model-download infra (`ModelDownloadService` + SHA-256 catalog) is pure-Dart and has no live
  caller yet — exercised by unit tests, **no on-device row**. The first real on-device download lands
  with P12c (multilingual embedder)._
- _(P12c-1) The XLM-R multilingual tokenizer is pure-Dart, **fidelity-tested in CI** against HuggingFace
  golden vectors — **no on-device row**. On-device multilingual embedding is verified at P12c-2/c-3._
- [ ] **(P12c-2)** AI settings → **Test multilingual embedder** → downloads MiniLM (~127 MB, progress +
      SHA-256 verified) → reports cross-lingual similarity where the en/es translation pair scores **far
      higher** than the unrelated sentence. The active embedder is **unchanged** (Gecko); semantic search
      behaves as before.
- [ ] **(P12c-2)** The app installs + runs (and the self-test works) on a **16 KB-page** Android 15
      device; the per-ABI APK is larger (onnxruntime native libs) but installs fine.
- [ ] **(P12c-3)** On a **mid/high-tier** device with semantic search on, AI settings shows the
      **Multilingual semantic search** switch → enable → MiniLM downloads + the library **re-indexes** →
      non-English search / "related" visibly improves. Toggle off → re-indexes back to Gecko (English).
      The choice **persists** across restart.
- [ ] **(P12c-3 → updated P12-sweep)** On a **low-tier** device the multilingual option shows a muted
      **"Multilingual semantic search — available on more capable devices"** disabled tile (no longer
      hidden); the embedder stays Gecko (semantic search still works).
- _(P12d-1) The generation engine + tier-gated model ladder are pure-Dart and have **no live consumer** —
  exercised by unit tests, **no on-device row**. On-device generation (picker + Labs self-test) lands with
  P12d-2._
- [ ] **(P12d-2)** On a **mid/high-tier** device, AI settings shows a **text-generation card** with the
      tier's models (Recommended/size-band badges + size). Pick the recommended → it downloads (progress;
      a near-full device shows a **friendly "not enough storage"** instead of a doomed multi-GB fetch) →
      **Test text generation** streams a sentence **offline**.
- [ ] **(P12d-2 → updated P12g)** On a **low-tier** device the generation card shows a muted
      **"On-device text generation — needs more memory than this device has"** tile (no longer hidden;
      see P12g) — no crash, no empty section.
- [ ] **(P12d-2)** Embedder + LLM **coexist**: run a semantic search, then a generation self-test, in the
      same session without the plugin conflicting (close-before-swap if needed).
- _(P12e-1) The transcription engine contract + whisper catalog/matrix/providers are pure-Dart, exercised
  by unit tests — **no on-device row**. On-device transcription (picker + Labs self-test) lands with P12e-2._
- [ ] **(P12e-2)** On any tier, AI settings shows a **speech-transcription card** with the tier's whisper
      models (Recommended/size-band badges + size). Pick one → it downloads (progress; a near-full device
      shows a **friendly "not enough storage"**) → **Test transcription** transcribes the bundled sample
      clip **offline** and shows the recognized text.
- [ ] **(P12e-2)** On a **low-tier** device the transcription card is **still shown** (offers whisper-tiny)
      and the self-test works — transcription is never gated off entirely (unlike generation).
- [ ] **(P12e-2)** Embedder + LLM + **whisper coexist**: run a semantic search, a generation self-test, and
      a transcription self-test in the same session without a native conflict or crash.
- [ ] **(P12e-3) Manual fallback, model ready**: on a **caption-less** item with transcription on + a model
      downloaded, **More → Get transcript** (after captions come up empty) → "Transcribing on-device…" →
      transcript + tap-to-seek cues appear in the player, **offline**.
- [ ] **(P12e-3) Manual on-ramp, disabled**: with transcription **off**, Get transcript on a caption-less
      item offers **"Set up transcription?"** → confirming downloads the model, **flips the AI-settings
      toggle on**, and transcribes. Declining leaves a plain "no captions" message.
- [ ] **(P12e-3) Manual on-ramp, enabled no model**: with transcription on but no model, Get transcript
      offers a **one-time download** → then transcribes; the model is reused next time (no re-download).
- [ ] **(P12e-3) Captioned item unaffected**: an item **with** captions still builds its transcript from the
      sidecar — whisper never runs (no model download prompt, instant).
- [ ] **(P12e-3) Auto fallback**: with **Auto-transcribe** + transcription on + a model present, downloading
      a **caption-less** video auto-builds a whisper transcript and posts the usual "Transcript ready".
- [ ] **(P12e-3) Auto needs-model nudge**: same as above but **no model** → the caption-less item is skipped
      (no queue stall) and a single **"Finish setting up transcription"** notice appears, deep-linking to
      **AI settings**; fully-off transcription posts **no** nudge.
- [ ] **(P12e-3) Search lights up**: after a caption-less item is transcribed, it now surfaces in **keyword
      search** and (with semantic search on, after the next backfill) **semantic search**.
- [ ] **(P12g) Device-tier banner**: AI settings shows a **"Your device: \<Basic|Standard|Advanced\>"**
      banner with a one-line blurb + an InfoHint explaining on-device scaling; the label matches the
      device (a high-RAM phone → Advanced, an old/low-RAM one → Basic).
- [ ] **(P12g) Gating is legible**: on a **Basic (low)** device, generation shows the "needs more memory"
      reason while **semantic search + transcription still work**; on **Standard/Advanced** the generation
      **model picker** is shown instead.
- [ ] **(P12g) Onboarding tier**: the first-run AI setup screen surfaces **"Your device: \<tier\>"** before
      the user opts in.
- [ ] **(P12g) Opt-ins persist**: enabling a capability + picking a model survives an app restart; the
      model selector switches the active model (capable device).

## P13 — LLM features + local GraphRAG  *(v1)*

### P13a — Abstractive summarization  *(install `app-arm64-v8a-debug.apk`; needs a capable device)*
- [ ] On a capable (mid/high) device with text generation enabled + a model downloaded: open an item
      that has a transcript or description → an **"AI summary"** block appears above the extractive
      "Summary"; tap **Summarize with AI** → tokens **stream** in, **fully offline** (airplane mode).
- [ ] The summary **persists across an app restart** (cached); **Regenerate** re-runs it.
- [ ] On a **low-end** device (or with generation off): the **"AI summary" affordance is absent** and the
      extractive TextRank "Summary" still shows — no empty state, no crash.
- [ ] On a capable device with generation **not yet enabled**: tapping **Summarize with AI** shows a
      "set up text generation" hint and opens **AI settings** (the on-ramp).

### P13a-2 — Auto-summarize on download  *(install `app-arm64-v8a-debug.apk`; needs a capable device)*
- [ ] AI settings → with text generation enabled, the **Auto-summarize new downloads** toggle is visible;
      enable it. Finish a download (an item with a description/transcript) → an **AI summary** appears on
      the item **and** an Activity Inbox entry ("Summary ready"), **fully offline**.
- [ ] With auto-summarize on but **no generation model downloaded**: a download produces a one-time
      "Finish setting up summaries" inbox nudge that opens **AI settings** (no summary written).
- [ ] **Default off** (and when generation is disabled): downloads produce **no** auto-summary and no AI
      nudge; the queue still drains normally; the on-demand "Summarize with AI" still works.

### P13b-1 — OCR (on-demand)  *(install `app-arm64-v8a-debug.apk`; image item)*
- [ ] Open an **image** item that contains legible text → a **"Text in image"** section shows a **Scan
      text** button; tap it → the recognized text appears, **fully offline** (airplane mode), and persists
      across an app restart; **Rescan** re-runs it.
- [ ] After scanning, **search** the library for a word that appears **only in the image text** → the image
      is returned (OCR feeds full-text search). With semantic search on, "related"/search also benefit.
- [ ] An image with no readable text shows a "No readable text found" note (no crash). A **video/audio**
      item shows **no** OCR section.

### P13b-2 — Translation  *(install `app-arm64-v8a-debug.apk`; foreign-language item)*
- [ ] Open an item whose **description/transcript is in another language** → overflow **Translate…** → pick
      your language → confirm the **~30 MB pack download** (Wi-Fi) → the description + transcript render
      **translated**; toggling **Show original** flips back. After the pack is present, re-translating is
      instant and works **offline** (airplane mode).
- [ ] An item already in your language → "Already in <language>" notice (no-op). Undetectable text →
      "Couldn't detect the language".
- [ ] On a host without ML Kit, the **Translate…** action is absent (graceful).

### P13b-3 — Auto-OCR on download (+ image-download fix)  *(install `app-arm64-v8a-debug.apk`)*
- [ ] **Image download fix:** download a single image (e.g. an Instagram/X photo, or a photo carousel) →
      it now appears in the library as an **image item** (previously it produced nothing), shows **its own
      picture as the thumbnail** in the grid/dashboard/collections (not a movie-icon placeholder), and is
      exactly **one** item even though yt-dlp also writes a thumbnail sidecar. The video case is unchanged
      (the video is the item; its thumbnail is still a thumbnail).
- [ ] **Export:** export a downloaded image item to the gallery → it lands in the **Images** collection
      and opens in the device gallery.
- [ ] AI & graph settings → enable **Image text (OCR) · Auto-scan new image downloads**. Download an image
      with legible text → its text becomes **searchable** + a "Text found in image" Activity Inbox entry,
      **fully offline**.
- [ ] **Default off:** with the toggle off, image downloads are not auto-scanned (on-demand "Scan text"
      still works). A **video** download is never auto-OCR'd. The queue still drains normally.

### P13c — Smart auto-tagging  *(install `app-arm64-v8a-debug.apk`; needs a capable device)*
- [ ] On a capable device with text generation enabled: open an item → **Edit info** → Tags → an **AI
      suggestions** row with a **Suggest tags with AI** button. Tap it → sensible lowercase tag chips appear,
      **fully offline** (airplane mode); tapping a chip **adds** the tag (it moves into the tag list and feeds
      facets) and removes it from the suggestions.
- [ ] AI suggestions **exclude** tags already applied; tags are never added without a tap.
- [ ] On a **low-end** device the AI row is **absent** (the graph co-occurrence "Suggested" chips still work);
      with generation **not enabled**, the button routes to **AI settings** (on-ramp).

### P13c-2 — Auto-tag on download  *(install `app-arm64-v8a-debug.apk`; needs a capable device)*
- [ ] AI & graph settings → with generation enabled, the **Auto-tag new downloads** toggle is visible; enable
      it. Finish a download (item with description/transcript) → sensible **AI tags are applied** + an
      Activity Inbox entry ("N tags added"), **fully offline**. The tags show a **✦ marker** in the editor +
      on item detail, and appear as **search facets**; any AI tag can be **deleted**.
- [ ] A **manually-added** tag has no marker. **Default off:** downloads aren't auto-tagged; with generation
      off there's a one-time "finish setting up auto-tagging" nudge; the queue still drains.

### P13d-1 — GraphRAG retrieval engine  *(CI-covered; no APK check)*
- No on-device check: P13d-1 ships the **pure-Dart retrieval/context engine** only (no UI, schema, or
      native path). It's exercised by unit tests (fake embedder + graph + seeded in-memory metadata). The
      end-to-end **"Ask your library"** flow is verified at P13d-2 (chat screen + generation).

### P13d-2a — "Ask your library" chat  *(install `app-arm64-v8a-debug.apk`; needs a capable device + a downloaded generation model)*
- [ ] On a capable device with a generation model set up, the Dashboard shows an **"Ask"** entry; tapping it
      opens the chat. (On a low-end device, or with the graph index unavailable, the entry is absent.)
- [ ] Ask a natural-language question about your library → the answer **streams in**, is **grounded** in your
      items, and shows inline **`[n]` citations** plus a **Sources** row — **fully offline** (airplane mode).
- [ ] Tapping a citation (inline `[n]` or a Sources chip) **opens the cited item**.
- [ ] Ask a follow-up → it still answers (fresh retrieval + prior turns as context); the turns **persist**
      (the transcript stays on screen for the session).
- [ ] Ask something your library can't answer → a graceful **"couldn't find anything"** reply (no invented
      answer).
- [ ] With generation **not** set up (eligible device, no model), sending shows the **on-ramp** snackbar and
      routes to AI settings.

### P13d-2b — Conversation list + manage  *(install `app-arm64-v8a-debug.apk`; needs a capable device + a downloaded generation model)*
- [ ] Ask questions in **two separate chats** (open Ask → New chat each time) → the Dashboard "Ask" entry now
      opens a **conversation list** showing both, **most-recent-first**, each with a **preview** of its last
      message and a relative time.
- [ ] **Reopen** a chat from the list → its prior turns show, and a **new question continues with retained
      context** (the answer reflects the earlier turns) — **fully offline**.
- [ ] **Rename** a chat (row menu → Rename) → the new title persists in the list and on the open chat's app bar.
- [ ] **Archive** a chat → it leaves the main list; it appears under **Archived chats** (app-bar overflow) and
      can be **Unarchived** back; **Delete** removes a chat (and its messages) for good (after a confirm).
- [ ] With no chats yet, the list shows an **empty state** whose CTA starts a chat.

### P13d-3 — Retrieval-only fallback + tier-aware depth + RAM co-residency  *(install `app-arm64-v8a-debug.apk`)*
- [ ] On a **low-end device** (no generation model fits) with Smart search on, the Dashboard "Ask" tile is
      **still shown** (subtitle "Find the most relevant items") and opens the **retrieval-only** screen.
- [ ] Type a query → the **most relevant items** appear (tappable → item), **fully offline**; nothing is
      persisted (no conversation list entry is created). With Smart search off / embedder not ready, an
      **on-ramp** to AI settings is shown instead of empty results.
- [ ] **Tier-aware depth:** on a capable device, multi-turn answers stay coherent; mid-tier feeds back a
      shallower history window than high-tier (no over-stuffing / slowdowns).
- [ ] **RAM co-residency (the P12d-2 carry-over):** on real **low/mid** hardware, a full generated, cited
      answer runs while the Cozo **HNSW index is live** — no OOM, crash, or jank; repeated turns stay stable.

### P13e-1 — Community-detection auto-albums  *(install `app-arm64-v8a-debug.apk`; needs a real library)*
- [ ] On a library with shared signals (same channels / playlists / tags / co-downloaded batches), Collections
      → **Albums** shows a **"Discovered"** section of coherent multi-signal groups, each labeled by its
      dominant shared signal ("Around 'recipes'", "Mostly <channel>", …).
- [ ] Works on a **low-end device** (no generation model / embedder needed — entity graph only).
- [ ] Tapping a discovered album opens its items; **Save** creates a normal collection containing them.
- [ ] The Discovered section is **absent** when the graph index is unavailable (e.g. unsupported ABI).

### P13e-2 — Centrality "Rediscover" strip  *(install `app-arm64-v8a-debug.apk`; needs an established library)*
- [ ] On a library with cross-links (shared channels/playlists/tags or co-downloaded batches), a **"Rediscover"**
      strip appears on the **Dashboard** (below "Recently opened") **and** atop the **Library**, surfacing items
      that are well-connected but that you **haven't opened in a while**.
- [ ] Items opened in the **last ~2 weeks do not** appear (no overlap with "Recently opened"); tapping a tile
      opens the item.
- [ ] The strip is **absent** on a small/new library, while searching/filtering/selecting in the Library, and
      when the graph index is unavailable.
- [ ] Works on a **low-end device** (entity graph only — no embedder/LLM).

### P13e-3a — "How are these related?" connection path  *(install `app-arm64-v8a-debug.apk`; needs a real library)*
- [ ] In item detail, the **"How is this related to…?"** action opens a searchable picker (current item
      excluded); picking a genuinely-related item shows a readable **connection chain** (cards + connectors like
      "same channel" / "shared tag '…'" / "downloaded together"); tapping a card opens that item.
- [ ] Two **unrelated** items (no shared channel/playlist/tag, never co-downloaded) show **"No connection
      found"**.
- [ ] The action is **absent** when the graph index is unavailable (e.g. unsupported ABI); works on a
      **low-end device** (entity graph only — no embedder).

### P13e-3b — Graph-view polish + in-graph path  *(install `app-arm64-v8a-debug.apk`; needs a real library)*
- [ ] In the graph view, the **zoom in / out / reset** controls work, and pan/zoom **survives** expanding a
      node, toggling a legend filter, and the expansion spinner (no layout jump / re-scatter).
- [ ] The **"Find path…"** app-bar action → pick a target → the canvas switches to a highlighted **path**
      (items linked by connector bridges) with a banner; path item nodes are tappable (open) and long-pressable
      (re-seed the graph there); **"Back to neighborhood"** restores the original view.
- [ ] An unrelated target shows **"No connection found"**; existing P10c-e/f interactions (expand, legend
      filter, long-press sheet) still work; everything is **absent** when the graph is unavailable.

### P13f-1 — Model download & management UX  *(install `app-arm64-v8a-debug.apk`; needs a capable device)*
- [ ] In Settings → AI, each generation/transcription model tile reads its state — **Active** / **Downloaded** /
      **~MB** — and downloading a model shows an **inline progress** indicator (not just a snackbar).
- [ ] A **downloaded-but-inactive** model offers **"Delete download"**, which frees the space (the model stays
      selectable and re-downloads on demand); the active model has no delete (avoids breaking the active feature).

### P13f-2 — Translation language packs  *(install `app-arm64-v8a-debug.apk`)*
- [ ] In Settings → AI, the **Translation** card lists each **downloaded ML Kit language pack** by name with
      its size (**~30 MB · Downloaded**); before any translation it shows the **empty-state** line.
- [ ] **"Delete language pack"** removes a pack and frees the space (offline); it re-downloads on demand the
      next time you translate that language.
- [ ] **"Download a language"** → pick a language → confirm the **~30 MB over Wi-Fi** prompt → the pack
      downloads and then appears in the list (offline after the fetch).
- [ ] The whole **Translation card is absent** on a host where ML Kit translation can't run (non-Android).

### P13 — consolidated cross-feature on-device pass  *(the phase-close gate; run on one low-tier + one mid/high device)*
The single owed verification for the whole phase: it exercises the P13 features **together** (the
per-subphase rows above stay as the granular per-feature reference). Running this pass is what closes P13.
- [ ] **Generation stack on one model:** download a generation model once, then on a capable device —
      an item's **abstractive summary** streams + persists; **auto-summarize-on-download** fills a new
      download's summary; **auto-tag-on-download** applies AI-marked tags; **"Ask your library"** answers a
      multi-turn question, **grounded + cited** — all **offline**, on the same resident model, no OOM.
- [ ] **LLM + Cozo HNSW RAM co-residency** (BACKLOG from P12d-2 / P13d): on a **mid** device, run Ask while
      semantic search / "related" are active — generation and the live HNSW index stay resident together
      within the memory budget (no crash, no thrash).
- [ ] **ML Kit (device-universal):** on-demand **OCR** + **auto-OCR-on-download** make image text
      searchable; **translation** translates an item and **language-pack management** (Settings → AI) lists /
      adds / deletes packs — all **offline** after the one-time pack fetch.
- [ ] **Graph analytics together:** **Discovered** (community) albums, the **Rediscover** strip (Dashboard +
      Library), **connection path** (chain screen + in-graph highlight), and graph-view polish all read
      coherently on a **real** library.
- [ ] **Gating interplay (low / ineligible device):** every LLM feature shows a friendly floor/disabled
      state — extractive (TextRank) summary, **retrieval-only** Ask, no AI tag suggestions — **never a crash
      or empty gap**; **OCR/translate still run** (ML Kit-gated, not tier-gated).
- [ ] **Opt-ins persist across restart** (auto-summarize / auto-OCR / auto-tag toggles, the selected model,
      downloaded language packs) and everything stays **offline** (airplane mode) bar the one-time model /
      pack fetches.

## P14 — Things Engine foundation  *(v1)*
> P14a/P14b are pure-Dart/Drift (CI-discharged, no APK owed). The checks below are **batched** into the
> P14 consolidated on-device pass (CLAUDE.md §7); until it runs they stay open and the subphases sit at `[~]`.

### P14c — MediaObject projection + rebuildable backfill + sync hook  *(install any debug APK; needs a real library; works offline)*
- [ ] **Backfill over a real library:** after updating to this build, every existing download has a
      `MediaObject` Thing — the Things count (P14f diagnostic / DB inspect) equals the library item count.
- [ ] **New download projects on completion:** download an item, and its `MediaObject` Thing appears
      (correct `VideoObject`/`AudioObject`/`ImageObject` type, `name`/`url`/`contentUrl`) without any manual action.
- [ ] **Edit re-projects:** renaming an item / editing metadata updates its Thing within a couple of seconds
      (the debounced listener), with no duplicate rows.
- [ ] **Idempotent + prunes deleted:** deleting a library item removes its `MediaObject` Thing; reopening the
      app (re-running the backfill) creates no duplicates and leaves the count stable.
- [ ] **Fully offline** (airplane mode) — projection touches no network.

## P19 — v1 Beta, Production Readiness & Launch  *(v1)*
- [ ] Large library (100s of items) scrolls smoothly; big playlist picker is responsive; the
      AI/graph index build doesn't jank the UI.
- [ ] i18n scaffolding present.
- [ ] **Donations link** in the About screen opens the external donations page; nothing is sold
      in-app; no ads, no telemetry.
- [ ] Distribution: signed release APK on the GitHub Release; landing-site install steps work.

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
   — done in **P19**.
2. Build with **Build APK → release = true**, install the signed release APK.
3. Run **every** section above (P0 → P19) end-to-end on a real device.
4. Confirm: privacy (nothing in Gallery until exported), app lock, background downloads, playback,
   and the **on-device AI + graph** features (incl. Cozo loading on the AOT release build) all work.
