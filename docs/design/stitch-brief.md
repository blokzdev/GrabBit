# GrabBit — Stitch Design Brief (P7 wireframe kickoff)

> Copy-paste prompts for **Google Stitch** (stitch.withgoogle.com) to generate
> wireframes/mockups for every GrabBit screen. These wireframes feed the P7
> **Branding & Frontend Revamp**: they're inspiration for the Flutter rebuild, not
> binding specs.

---

## How to use this file

Stitch generates **one screen per prompt** and works best with a rich, self-contained
description. So:

1. **Set the project theme** in Stitch (or paste the preamble): target **Mobile /
   Android**, **Material 3 (Material You) — Expressive**, generate **light and dark**.
2. For each screen, paste **§A Global preamble** *followed by* that screen's block from
   **§C**. (After the first few, Stitch keeps the style; you can then paste just the
   screen block and a one-line "same GrabBit design system as before".)
3. Generate, then **iterate** in chat ("make the FAB larger", "use a tonal app bar",
   "add an empty state"). Generate the **empty, loading, and error** variants where
   noted.
4. Export the frames (Figma/PNG) and **share them back** — I'll revamp the Flutter UI
   to match, foundation-first.

There are **14 screen blocks** below (12 routes; Home and Collections each have two
views). Generate them in the order listed for a coherent set.

---

## §A — Global design-system preamble  *(prepend to every screen prompt)*

```
App: GrabBit — a privacy-first, on-device social-media downloader and private media
manager for Android. Users paste a link (YouTube, Instagram, TikTok, X) and the app
downloads the video/image on-device into a private in-app library; they choose what to
export to the gallery. Tone: calm, trustworthy, premium, modern. The media (thumbnails,
videos, images) is the hero — chrome stays quiet and lets content shine.

Design language: Material 3 "Expressive" for Android. Use:
- Large, soft rounded shapes (cards ~20–28dp radius; full-pill buttons & chips).
- Vivid tonal color from a single brand seed, with clear light & dark schemes; assume
  Material You dynamic color is also supported, so don't hardcode hues into layouts.
- Expressive type scale: large, confident display/headline text; highly readable body.
- Springy, physical motion; emphasized easing; container transforms between list→detail.
- Prominent FABs, tonal/flexible top app bars, and a pill-style bottom or rail nav.
- Generous spacing and a strong typographic hierarchy; avoid dense, cramped lists.

Brand: a friendly geometric "rabbit" motif (a play on "Grab" + rabbit) — clean rounded
rabbit-ears / rabbit-head glyph that also reads as a download/grab gesture. Suggested
brand seed color: a confident modern violet (~#5A3FE0) with a warm accent (~#FF8A4C)
for primary CTAs; propose a full tonal palette for light and dark. Feel free to show
2–3 logo/mark directions.

Accessibility: WCAG-AA contrast, touch targets ≥48dp, support large/dynamic font sizes,
clear focus/selection states, meaningful empty states (never a blank screen).

Every screen should be designed to also show three states where applicable: an EMPTY
state (friendly illustration + short copy + a primary action), a LOADING state (skeleton
placeholders, not just a spinner), and an ERROR state (clear message + retry).

Platform: Android phone first; also show how the layout adapts on a large screen /
unfolded foldable (two-pane or wider content column, not a stretched phone layout).
```

---

## §C — Per-screen prompts

### 1. Disclaimer / Welcome  — route `/disclaimer`
```
Screen: First-run "Welcome to GrabBit" / legal disclaimer (shown once on first launch).
Layout: centered, single-column, friendly. Top: the rabbit brand mark + a soft shield
icon. Headline "Welcome to GrabBit". Below: 2–3 short scrollable paragraphs of a
user-responsibility / copyright disclaimer (GrabBit hosts no content; the user is
responsible for complying with each site's terms and copyright; downloads stay private
on-device by default). Bottom: a full-width pill primary button "I understand and agree"
(show a loading/disabled variant). Calm, reassuring, premium onboarding feel.
```

### 2. App Lock  — route `/lock`
```
Screen: App Lock / PIN entry (appears when the app is locked). Centered column: a lock
icon (branded), title "Enter PIN". A secure obscured PIN field with a numeric keypad
feel. A full-width primary "Unlock" button. A secondary text button "Use biometrics"
(fingerprint/face icon) shown when biometrics are enabled. Show an error variant with a
"Wrong PIN, try again" message and subtle shake affordance. Minimal, secure, focused —
no nav, no distractions.
```

### 3. Home — Library view  — route `/`  (primary screen)
```
Screen: Home, "Library" view — the main screen. A tonal/flexible top app bar with the
GrabBit wordmark+rabbit mark, and action icons: Sort, Collections (with a count badge),
and Queue (with a count badge + a small notification dot when downloads are active).
Directly below the app bar: a segmented toggle "Library | Explorer" to switch views.
Then a filter bar: a search field ("Search your library") + a type filter (chips or
dropdown: All / Video / Audio / Image). Body: a responsive grid of media cards
(2 columns on phone, more on large screens), each card = a large rounded thumbnail with
a subtle play badge for videos, a title, source/uploader, and a small "Saved to device"
badge when exported. Pull-to-refresh. A prominent extended FAB "Add" (download/plus
icon). Show: the populated grid, an EMPTY state ("Your library is empty — paste a link
to get started" + Add button), and a LOADING state with skeleton cards.
```

### 4. Home — Explorer view  — route `/`  (folder tree)
```
Screen: Home, "Explorer" view (same screen as Library, toggled via the "Library |
Explorer" segmented control). A Dropbox-like virtual folder browser over the private
library. Show a breadcrumb row (Home / Folder / Subfolder) under the segmented toggle.
Body: a list/grid mixing folder tiles (folder icon, name, item count) and media cards.
A multi-select mode: long-press selects items, a contextual top bar shows the selected
count with a "Move to folder" action, plus rename/delete affordances for folders. The
FAB becomes "New folder". Show the populated state and an EMPTY folder state.
```

### 5. Add Download  — route `/add`
```
Screen: Add Download. Top app bar with back + title "Add download". A multi-line URL
input ("Paste one or more links") with a paste affordance; as links resolve it shows a
MEDIA PREVIEW card (large thumbnail, title, uploader/source, duration). Below the
preview: a "Quality" preset picker as a horizontal row of choice chips (e.g. Best, 1080p,
720p, Audio only) — in SIMPLE mode show a few presets; in ADVANCED mode show more
format/codec/quality options. Bottom: two pill buttons side by side — "Add to queue"
(tonal/secondary) and "Download now" (filled/primary accent). Show an ERROR banner
variant: an inline error card ("Couldn't read this link") with a secondary "Update
engine" button. Also show a LOADING/probing state while a link resolves.
```

### 6. Selection (multi-item picker)  — route `/select`
```
Screen: Selection — a thumbnail picker shown when a link expands into many items
(a playlist, channel, or a mixed image/video carousel). Top app bar with back, a title,
and a live selected-count ("3 selected") + a select-all toggle. Body: a responsive grid
of selectable thumbnail tiles (each with a checkbox/selected ring, a type icon, and a
title). Optionally an error card at the top for any source URLs that failed to expand.
A bottom action bar (in a safe area): a "Quality" dropdown + two pill buttons "Add to
queue" and "Download now". Show populated + a partial-selection state.
```

### 7. Item Detail / Viewer  — route `/item/:id`
```
Screen: Item Detail — the media viewer for one saved item. Hero area: a video player
(large rounded surface with play/scrub controls) OR an interactive zoomable image. Below:
the title (large headline), then a metadata section (uploader/username, source platform,
playlist, upload date, and an expandable description). Tags shown as rounded chips in a
wrap. A primary "Save to device" button that shows its destination folder (and a
"Saved" state once exported). A row of secondary actions: "Move" (to folder), "Edit"
(metadata), and "Studio" (editing tools). Premium, content-first, with the media
dominating the top of the screen. Show video and image variants.
```

### 8. Metadata Edit  — route `/item/:id/edit`
```
Screen: Edit metadata. Top app bar with back + a "Save" action. Form: a "Title" text
field; a multi-line "Notes" field; a "Tags" editor (existing tags as removable chips +
an add-tag field); and a "Collections" section with checkboxes for existing collections
plus an inline "Create new collection" affordance. Clean, well-spaced form layout with
clear section headers. Show a state with several tags and a couple of collections checked.
```

### 9. Media Studio (editor)  — route `/item/:id/studio`
```
Screen: Media Studio — on-device editing tools for a saved item. Top: a preview of the
video/image being edited. For video: a horizontal timeline with a RANGE slider for trim
(showing MM:SS start/end), and a single-handle slider for frame extraction. A row of
ActionChips for transforms: Rotate, Flip, Mirror, Reverse, Extract audio, Extract frame,
Convert (format). For images: rotate/flip/mirror/crop/convert chips. A primary "Apply"
/ "Export" button (outputs a new library item; originals are preserved). Show a RUNNING
overlay state: a dimmed scrim with a progress indicator, percentage, and a Cancel button.
Tool-like but friendly; Material 3 Expressive controls.
```

### 10a. Collections — list  — route `/collections`
```
Screen: Collections list. Top app bar "Collections" with back. A list of collection rows
(folder/collection icon, name, item count) with a delete affordance per row. A FAB
"New collection" that opens a small dialog (name field + Create). Show the populated list
and an EMPTY state ("No collections yet — group your media into collections").
```

### 10b. Collection Detail  — route `/collection/:id`
```
Screen: Collection detail — the media grid for one collection. Top app bar with the
collection name + back. Body: the same responsive media-card grid as the Library, scoped
to this collection. Show populated + an empty-collection state.
```

### 11. Queue / Downloads  — route `/queue`
```
Screen: Download Queue. Top app bar "Queue" with a back/Home control (must never strand
the user), plus contextual actions (Start all / Resume all / Pause all / Clear completed).
Directly below: a SUMMARY bar of status counts (Running · Queued · Held · Paused · Done ·
Failed) as small tonal stat pills. Body: a list of download task tiles — each with a
thumbnail/title (the media title, not a raw URL), a linear progress bar, a status label
(percentage / Queued / Held / Paused / Done / Failed), and per-task actions on the right
(Pause/Cancel while running, Resume when paused, Retry when failed, Remove when done).
Show: an active queue (a couple running + queued + one failed), and an EMPTY state
("No downloads in queue").
```

### 12. Settings  — route `/settings`
```
Screen: Settings, organized into clear sections with headers:
- Downloads: an "Advanced mode" switch ("Show all format & quality options"); default
  quality (dropdown); max concurrent downloads (1–5 stepper/slider); "Wi-Fi only" switch;
  a "Filename template" tile (text field with insertable token chips + a live preview);
  switches for subtitles / thumbnail / metadata embedding.
- Downloader engine: shows the yt-dlp version with an "Update" button (+ a progress
  state), and an "Auto-check on launch" switch.
- Storage: "Auto-save to device" switch; an "Export folder" picker row showing the chosen
  folder.
- Appearance: Theme (System / Light / Dark dropdown); "Dynamic color" switch.
- Security: "App lock" switch; a conditional "Biometric unlock" switch.
Use Material 3 list items with leading icons, switches, and section headers. Show both
SIMPLE (fewer options) and ADVANCED (all options) variants. Clean, scannable, premium.
```

---

## Notes for the revamp (not for Stitch)

- Stitch output is **inspiration**, not a 1:1 spec. The Flutter rebuild adapts it to
  Material 3 Expressive widgets, the app's real data, and the existing route/state
  structure (go_router + Riverpod).
- Keep **Simple vs Advanced** parity and the **empty/loading/error** triad on every
  revamped screen.
- Brand color is a starting suggestion; the real seed + tonal palette are finalized in
  the P7 design-foundation PR, and Material-You dynamic color must keep working.
