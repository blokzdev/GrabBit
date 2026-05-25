# GrabBit — Design Spec

> The **living design system** and source of truth for the P7 frontend revamp. The UI is
> designed **directly in Flutter** (no external wireframing tool) and reviewed on-device.
> This doc defines the brand, tokens, components, and per-screen design intent; the
> subphase breakdown lives in `docs/design/P7-REVAMP-PLAN.md`. Keep this current — each
> screen subphase updates its section and ticks its status.

---

## 1. Brand & principles

**GrabBit** is a privacy-first, on-device social-media downloader and private media
manager for Android. Paste a link → it downloads on-device into a private library; the
user chooses what to export.

**Personality:** calm · trustworthy · premium · a little playful (the rabbit). The
**media is the hero** — chrome stays quiet so thumbnails/video/images carry the screen.

**Design principles**
1. **Content first.** Large media surfaces; restrained chrome; strong hierarchy.
2. **Expressive but legible.** Material 3 Expressive shape/motion/color, never at the
   cost of readability or reach.
3. **Calm confidence.** Generous spacing, few accents, one clear primary action per view.
4. **Honest states.** Every screen has a designed empty, loading (skeleton), and error
   state — never a blank screen or a bare spinner.
5. **Two depths.** Respect **Simple vs Advanced** mode — Simple hides power-options;
   Advanced reveals them without redesigning the screen.

---

## 2. Logo & iconography

**Concept:** two rounded **rabbit ears** that also read as a **downward chevron** — the
"grab"/download gesture. Reads as a friendly mark at large sizes and as a solid
silhouette at small/monochrome sizes. Pairs with a **"GrabBit"** wordmark (display font).

**Assets (P7a, in `assets/brand/`)**
- `logo.svg` — full mark (in-app, splash, about). Rendered via `flutter_svg`.
- `logo_mono.svg` — single-color silhouette for the Android-13 **themed/monochrome**
  launcher layer and the **notification** icon (must be legible at 24dp, flat, no gradient).
- Adaptive launcher icon = **foreground** (mark) + **background** (brand tonal fill) +
  **monochrome** layer, generated via `flutter_launcher_icons`.
- Splash via `flutter_native_splash` (Material splash: brand background + centered mark),
  light + dark.

> **Finalized in P7a (Direction B):** a friendly rounded bunny head + ears with an amber
> "grab" chevron. In `logo_mono.svg` the chevron is **knocked out as transparent negative
> space** so the download cue survives when Android tints the themed/monochrome layer.

---

## 3. Color

Off the default M3 purple (`0xFF6750A4`). **Brand palette** (finalized P7a):

| Role | Light | Dark | Notes |
|---|---|---|---|
| **Brand seed / primary** | `#5A3FE0` (electric indigo-violet) | tonal | confident, modern-Android |
| **Accent (CTA)** | `#FF8A4C` (warm amber) | tonal | primary download/grab actions, FAB; on the `GrabBitTokens` extension (not a `ColorScheme` role) |
| **Surface** | near-white, low-chroma | near-black, low-chroma | lets media pop |
| Error | M3 default error roles | — | from the scheme |

**Policy:** schemes are generated from the seed via `ColorScheme.fromSeed` with
`brightness`. **Material-You dynamic color stays ON by default** (via `DynamicColorBuilder`
in `lib/app.dart`) — the brand palette is the **fallback** when dynamic color is disabled
or unavailable. Never hardcode hex in widgets; read roles from `Theme.of(context).colorScheme`
and brand-specific values from the `GrabBitTokens` extension (§5).

**AMOLED (P9k):** an optional **true-black dark theme** (Settings → Appearance → "Pure black
(AMOLED)"). When on, `AppTheme.dark` overrides the dark scheme's `surface`/lowest-container roles to
`#000000` with graded near-black container roles so cards, inputs, and the app bar stay legible. Off by
default; orthogonal to the light/dark/system choice and dynamic color.

**Motion tokens** (`GrabBitTokens.motionShort/Medium/Long`, §5) are the source of truth for animation
durations — use them for transitions instead of hardcoded `Duration`s.

---

## 4. Typography

Material 3 Expressive type scale. **Display/headline** = a friendly geometric sans
(**Outfit**) to echo the rounded mark; **body/label** = a highly readable sans (**Inter**).
**Bundled** as variable fonts in `assets/fonts/` (no `google_fonts` runtime fetch — keeps
the app offline + privacy-first). Use the M3 roles (`displayLarge` … `labelSmall`)
through `TextTheme`; screens reference roles, not raw sizes. Bias one size up on key
headlines for the expressive feel; keep body ≥14sp and respect the system text-scale.

---

## 5. Tokens (`GrabBitTokens extends ThemeExtension`)

Defined in `lib/core/theme/` (P7a) so screens stop hardcoding values.

- **Spacing:** `xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 40`.
- **Radii:** `sm 8 · md 12 · lg 20 · xl 28 · pill 999` (cards lg/xl; buttons & chips pill).
- **Elevation:** flat surfaces; rely on tonal color over shadow. Levels 0–2 only.
- **Motion:** `short 150ms · medium 250ms · long 400ms`; M3 **emphasized** easing;
  springy container transforms list→detail.
- **Brand colors:** the accent + any brand-specific roles not in `ColorScheme`.

---

## 6. Components

**P7b status:** the shared layer ships in `lib/core/widgets/` — `EmptyState`, `ErrorView`,
`ErrorBanner`, `Skeleton`/`MediaGridSkeleton`/`ListSkeleton` (custom shimmer), `SectionHeader`
— plus token-driven `MediaTile`/`MediaGrid` (video play badge + thumbnail Hero) and queue
status pills. Tokens are read via `GrabBitTokens.of(context)`. Reused per-screen after.

- **Media card / tile** (`MediaGrid`/`MediaTile`) — large rounded thumbnail, play badge
  for video, title + source, "Saved to device" badge, clear selection state.
- **Buttons** — filled (accent) for the single primary action; tonal/outlined for
  secondary; pill shape.
- **Chips** — choice/filter chips, pill shape; selected state high-contrast.
- **App bar** — tonal/flexible; large title where it suits; quiet action icons with
  count badges (Queue/Collections).
- **Bottom sheets & dialogs** — large radius; the shared `confirm()` dialog
  (`lib/core/widgets/confirm_dialog.dart`) restyled, destructive variant in error color.
- **Progress** — determinate linear for downloads/jobs; branded indeterminate where unknown.
- **Empty / skeleton / error** (new shared widgets in `lib/core/widgets/`):
  - *Empty* — friendly illustration (rabbit motif) + short copy + one primary action.
  - *Loading* — **skeleton** placeholders matching the content shape (grid/list), not a
    bare centered spinner.
  - *Error* — clear message + retry (and an "Update engine" CTA where relevant).
- **Transitions** — expressive go_router page transitions; thumbnail **hero** into detail.

---

## 7. Per-screen design intent

Anatomy + required states for each route. Status ticks as each subphase ships
(see `P7-REVAMP-PLAN.md`). `[ ]` = not yet revamped.

### `[x]` Disclaimer — `/disclaimer` (P7l)
First-run welcome/legal. Centered: rabbit mark + shield, "Welcome to GrabBit", 2–3
scrollable disclaimer paragraphs, full-width pill primary "I understand and agree"
(loading variant). Calm, premium onboarding.

### `[x]` App Lock — `/lock` (P7l)
Centered branded lock icon, obscured PIN field (numeric), full-width "Unlock", secondary
"Use biometrics" when enabled. Error variant ("Wrong PIN") with subtle shake. No nav.

### `[x]` Dashboard — `/` (P10d)
The default landing and 1st of **5** nav destinations. Tonal app bar (wordmark). An
"Overview" section of tappable, tonal **stat tiles** (icon + large value + label) in a
responsive grid (2-col phone → 3 tablet → 4 desktop): library count, storage used (with a
device "free of total" subtitle), queue pending (accent-tinted "N downloading" while
active), collections. Tiles drill into `/library` · `/storage` · `/queue` · `/collections`.
States: populated · empty ("Your dashboard is empty" + Add a download) · shimmer skeleton ·
error+retry. Below the stat grid, three full-width `fl_chart` chart sections (each a tonal
card with a `SectionHeader`): **Storage by type** donut, **Storage by platform** donut (small
platforms fold into a muted "Other" slice), and **Library activity** bars (additions over the
last 30 days). Donuts show a centre total + a colour-swatch legend; the palette derives from
the active `ColorScheme` so it follows dynamic colour and dark/AMOLED. Each chart tile has its
own compact states: chart · "no data yet" · shimmer · error+retry. Below the charts, P10d-3 adds
discovery/content sections that **auto-hide when empty** (so a fresh library stays minimal):
**Recently added** + **Recently opened** horizontal media rows (the latter labelled "opened", not
"played", since the library spans video/audio/images and future docs), a **Suggested for you**
list (on-device similarity clusters; hidden when AI is off), a **Duplicates** callout (links to the
Duplicates screen), and an **Explore graph** entry card that opens the newest item's relationship
graph (hidden when the on-device graph is unavailable).

### `[x]` Home — Library view — `/library` (P7c, moved off `/` in P10d)
Tonal app bar (wordmark + Sort, Collections w/ badge, Queue w/ badge + active dot);
"Library | Explorer" segmented toggle; filter bar (search + type chips All/Video/Audio/
Image); responsive media grid (2-col phone, more on large screens); pull-to-refresh;
extended FAB "Add". States: populated · empty ("library is empty" + Add) · skeleton grid.

### `[x]` Home — Explorer view — `/library` (P7c)
Same screen, toggled. Breadcrumb row; mixed folder tiles + media cards; multi-select
(long-press) with "Move to folder"; folder rename/delete; FAB → "New folder". Empty
folder state.

### `[x]` Add Download — `/add` (P7d)
*(P7d: styling pass. The "Advanced = more format/codec options" picker is deferred — see `docs/BACKLOG.md`; presets are the same in both modes for now.)*
Multi-line URL input (paste affordance); resolves to a media preview card (thumbnail/
title/uploader/duration); quality preset chips (Simple = few presets, Advanced = more
format/codec options); two pill actions "Add to queue" (tonal) + "Download now" (accent).
States: probing/loading · error banner with "Update engine" CTA.

### `[x]` Selection — `/select` (P7e)
Multi-item picker for playlists/channels/carousels. App bar with live selected-count +
select-all; responsive grid of selectable thumbnail tiles (checkbox/ring + type icon);
optional per-source error card; bottom bar (quality dropdown + Add/Download). States:
populated · partial selection · source errors.

### `[x]` Item Detail — `/item/:id` (P7g)
Hero media (Chewie player for video / zoomable image); large title; an auto-hiding extractive
**Summary** TL;DR (P10e — pure-Dart TextRank over the description, bullet sentences); metadata section
(uploader, platform, playlist, date, expandable description); tag chips; primary "Save to
device" (shows destination + "Saved" state); secondary actions Move / Edit / Studio.
Video + image variants.

### `[x]` Metadata Edit — `/item/:id/edit` (P7h)
App bar with Save. Title field; multi-line Notes; tags editor (chips + add field);
collections checkboxes + inline create. Clean spaced form with section headers.

### `[x]` Media Studio — `/item/:id/studio` (P7i)
*(crop tool deferred — see `docs/BACKLOG.md`)*
Preview + tools. Video: timeline with range slider (trim, MM:SS), single-handle slider
(frame extract). Transform chips: rotate/flip/mirror/reverse/extract-audio/extract-frame/
convert. Image: rotate/flip/mirror/crop/convert. Primary Apply/Export (new item; original
kept). **Running** overlay: scrim + progress % + Cancel.

### `[x]` Collections (list) — `/collections` (P7j)
List of collection rows (icon, name, count, delete); FAB "New collection" → name dialog.
States: populated · empty.

### `[x]` Collection Detail — `/collection/:id` (P7j)
Collection-scoped media grid (same card system as Library). Populated · empty-collection.

### `[x]` Queue — `/queue` (P7f)
App bar with back/Home (never strands) + contextual actions (Start all / Resume all /
Pause all / Clear completed); status summary pills (Running·Queued·Held·Paused·Done·
Failed); task tiles (title not raw URL, linear progress, status label, per-task actions:
Pause/Cancel/Resume/Retry/Remove). States: active queue · empty.

### `[x]` Settings — `/settings` (P7k)
Sections with headers + leading icons: Downloads (Advanced-mode switch, default quality,
max concurrent 1–5, Wi-Fi only, filename template w/ token chips + preview, subtitles/
thumbnail/metadata switches); Downloader engine (yt-dlp version + Update + progress,
auto-check switch); Storage (auto-save switch, export folder picker); Appearance (theme
dropdown, dynamic-color switch); Security (app lock switch, conditional biometric switch).
Simple vs Advanced parity.

### `[x]` Cross-cutting — Adaptive layout + a11y (P7m)
Layout reacts to the **window-size class** (`core/layout/window_size.dart`: Compact <600 /
Medium 600–839 / Expanded 840–1199 / Large 1200–1599 / Extra-large ≥1600 dp), so the same code
covers phones, tablets, foldables (folded = Compact, unfolded = Medium/Expanded) and desktops.
- **`ContentBounds`** (`core/widgets/content_bounds.dart`) caps + centers content: single-column
  screens at ~640, galleries at ~1280 — no edge-to-edge stretching on wide windows.
- **Unified navigation** (`AdaptiveNavigationScaffold` over a `StatefulShellRoute`): the five
  top-level destinations (Dashboard · Library · Queue · Collections · Settings) render as a bottom
  `NavigationBar` on Compact → `NavigationRail` on Medium/Expanded → **extended rail** on
  Large/desktop. The Dashboard is the default landing (`/`); Queue/Collections badges live on the
  destinations.
- **a11y:** ≥48dp targets (theme), search-clear tooltip, `Semantics` (selected/button) on
  selection + grid tiles, scrim-contrast bump, dynamic-type verified at 200%.

**P7n (deferred to `docs/BACKLOG.md`, needs a foldable device):** two-pane list-detail
(Library↔ItemDetail, Collections↔detail) on Expanded+, hinge avoidance via
`MediaQuery.displayFeatures`, fold/unfold continuity, and tabletop posture for the player.

---

## 8. Definition of done (per screen)
A screen subphase is done when: it uses the P7a tokens + P7b components (no hardcoded
spacing/color); shows empty/loading/error where applicable; preserves Simple/Advanced
parity; works in light/dark + dynamic color; passes CI; is verified on-device; and its
section here + the relevant `docs/VERIFICATION.md` check are updated.
