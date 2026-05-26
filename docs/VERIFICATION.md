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
      a progress bar runs to 100% (~110 MB, one time) → lands on Home.
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
- [ ] Download an item **with subtitles enabled** (so `.vtt/.srt` sidecars land), then **More → Build
      transcript** → a **Transcript** section appears with the spoken text, and the **Summary** now
      derives from the transcript (not the description). No model/network.
- [ ] For an item with **no caption files**, **Build transcript** shows *"No caption files found for
      this item"* — no crash; the description-based summary is unaffected.
- [ ] **Settings → Auto-build transcripts** ON → a fresh download that has captions gets a transcript
      with no manual step.
- [ ] **Settings → Backfill transcripts on open** ON → opening an older item that has sidecars builds
      its transcript once (Transcript/Summary appear after a moment).
- [ ] Auto-caption "rollover" repetition is **de-duplicated** — the transcript reads as continuous
      text, not repeated phrases.
- [ ] Both Settings toggles show an **(i)** info affordance explaining what they do.
- [ ] *(On-demand fetch of captions for items that have none — with a language selector — is P10f-2,
      native.)*

## P11 — Activity Inbox  *(v1)*
*(Forward-looking — detailed checks added when the phase is built.)*
- [ ] Background work posts durable entries to the Inbox: a finished/failed **download**, a built
      **transcript/backfill**, a **graph** index rebuild — each shows up with the right category/severity.
- [ ] The app-bar **bell** shows an **unread badge**; opening the **Inbox** marks items read and the
      badge clears.
- [ ] Tapping an entry **deep-links** to the relevant item/screen; **swipe-to-dismiss** and
      **clear / mark-all-read** work; **category filters** narrow the list.
- [ ] Items **auto-clear** per **Settings → notification retention** (and "keep forever" when set to 0);
      the sweep happens on open, no background scheduler.
- [ ] Everything stays **on-device** (no network/telemetry) and the Inbox is **behind the app lock**.

## P12 — Device-tiered edge LLM engine  *(v1)*
- [ ] First AI-feature use runs a **device-capability diagnostic** and shows the device tier.
- [ ] A model **downloads on demand** with progress + integrity check; cached for reuse; install
      stays lean until then.
- [ ] On a **capable** device: generate text / transcribe a short clip **offline**.
- [ ] On a **low-end** device: LLM features are **cleanly disabled with a friendly reason** (no
      crash, no silent no-op).

## P13 — LLM features + local GraphRAG  *(v1)*
- [ ] **Transcription / summarization / translation / OCR** each work (capability-gated) and write
      results back to the item.
- [ ] **"Ask your library"**: a natural-language question returns a grounded answer citing real
      library items — **fully offline** (airplane mode).
- [ ] **Graph-clustered auto-albums**, **"Rediscover"** (centrality), and **path/bridge** discovery
      produce sensible results.
- [ ] All P13 features gate gracefully on incapable devices.

## P14 — v1 Beta, Production Readiness & Launch  *(v1)*
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
   — done in **P14**.
2. Build with **Build APK → release = true**, install the signed release APK.
3. Run **every** section above (P0 → P14) end-to-end on a real device.
4. Confirm: privacy (nothing in Gallery until exported), app lock, background downloads, playback,
   and the **on-device AI + graph** features (incl. Cozo loading on the AOT release build) all work.
