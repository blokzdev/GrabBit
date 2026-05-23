# P7 — Branding & Frontend Revamp: subphase plan

> The sub-roadmap for **P7** (see `docs/ROADMAP.md`). The design system is in
> `docs/design/DESIGN_SPEC.md`. The UI is designed **directly in Flutter** and reviewed
> on-device; there is no separate wireframing step.

## How subphases work
- **Foundation first** (P7a → P7b), then **one subphase per screen**, then a cross-cutting
  pass (P7m).
- Each subphase is a **commit** on `claude/p7-branding-frontend-revamp`. It must keep CI
  green (`dart format` · `flutter analyze` · `flutter test`), run `build_runner` if codegen
  changed, and update both `DESIGN_SPEC.md` (tick the screen) and `docs/VERIFICATION.md`.
- **On-device review:** APK builds are **manual / user-triggered** (Actions minutes are
  scarce — CLAUDE.md §6). Batch a few subphases per build when practical.
- **PR cadence:** open the PR into `main` at a reviewable checkpoint (at minimum at phase
  end, per CLAUDE.md §7); cadence confirmed with the maintainer. No PR is opened
  automatically.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

## Foundation

### `[x]` P7a — Brand identity & design foundation
- ✅ Rabbit-ears **SVG** logo (3 directions presented; **Direction B** chosen): `logo.svg`
  (full color) + `logo_mono.svg` (silhouette with the download chevron **hollowed out** for
  the themed/monochrome layer). Rasterized to PNG masters via a Sharp dev tool (`tool/brand/`).
- ✅ **Adaptive launcher icon** (foreground / brand background / **monochrome**) via
  `flutter_launcher_icons`, and the Android-12+ branded **splash** (light/dark) via
  `flutter_native_splash`.
- ✅ Deps: `flutter_svg`; dev `flutter_launcher_icons`, `flutter_native_splash`. Brand type
  **Outfit + Inter bundled** in `assets/fonts/` (offline/privacy-first — no `google_fonts`
  runtime fetch). `assets/brand/` registered; added to `docs/SPEC.md`.
- ✅ `lib/core/theme/app_theme.dart` → full **Material 3 Expressive** theme (brand seed
  `#5A3FE0` + amber accent, Outfit/Inter type, pill buttons/chips, rounded cards/sheets,
  component themes), `DynamicColorBuilder` in `lib/app.dart` still working.
- ✅ `GrabBitTokens extends ThemeExtension` (spacing, radii, elevation, motion, brand colors).
- **Exit / review:** new icon + splash render on-device; app adopts the new theme in
  light/dark + dynamic color with no regressions. *(on-device spot-check pending — see
  `docs/VERIFICATION.md` P7.)*

### `[x]` P7b — Shared component library
- ✅ Shared state widgets in `lib/core/widgets/`: `EmptyState`, `ErrorView`,
  `ErrorBanner` (consolidates the two ad-hoc banners; caller passes the "Update engine"
  action), `Skeleton`/`MediaGridSkeleton`/`ListSkeleton` (custom no-dep shimmer), and
  `SectionHeader` (extracted from settings).
- ✅ Restyled shared components onto tokens: `MediaTile`/`MediaGrid` (token radii/spacing,
  scrim/role colors, **video play badge**, thumbnail **Hero**), queue task tile + status
  **pills**, library filter bar, settings section headers; `GrabBitTokens.of(context)`
  resilient accessor added.
- ✅ Thumbnail **Hero** (tile → `/item/:id`, lightweight flight shuttle); kept the global
  `FadeForwards` route transition.
- ✅ Wired the new empty/skeleton/error states into **Library** + **Queue** (demo); other
  screens adopt them in their own subphases.
- **Exit / review:** components demoed on Library + Queue; empty/skeleton/error render. CI
  green (format · analyze · 147 tests · debug APK). *(on-device spot-check pending — see
  `docs/VERIFICATION.md`.)*

---

## Per-screen

| Subphase | Screen(s) | Routes |
|---|---|---|
| `[x]` P7c | Home — Library + Explorer views | `/` |
| `[x]` P7d | Add Download | `/add` |
| `[x]` P7e | Selection | `/select` |
| `[x]` P7f | Queue | `/queue` |
| `[x]` P7g | Item Detail | `/item/:id` |
| `[x]` P7h | Metadata Edit | `/item/:id/edit` |
| `[x]` P7i | Media Studio | `/item/:id/studio` |
| `[x]` P7j | Collections (list + detail) | `/collections`, `/collection/:id` |
| `[x]` P7k | Settings | `/settings` |
| `[x]` P7l | Disclaimer + Lock | `/disclaimer`, `/lock` |

**P7c done:** Home shell rebranded (mark + wordmark app bar, queue running dot, tokenized
toggle); Explorer revamped to a **unified folder + media grid** (folder cards with glyph /
name / item-count + rename/delete menu; media tiles keep multi-select), restyled breadcrumb +
selection bar, and adopted the P7b empty/skeleton/error states; Library empty state gained an
inline **Add** action. CI green (format · analyze · 154 tests · debug APK). *(on-device
spot-check pending — see `docs/VERIFICATION.md`.)*

**P7d done:** Add Download restyled — paste affordance on the URL field, probing **skeleton**,
**preview card** (thumbnail + duration pill + title/uploader), and **pill** actions (tonal
"Add to queue" + accent "Download now"); tokenized throughout. Advanced format/codec picker
**deferred** to `docs/BACKLOG.md`. CI green (format · analyze · 159 tests · debug APK).

**P7e done:** Selection restyled — entry tiles mirror the library `MediaTile` (thumbnail with
type-icon fallback, scheme-role selection badge, duration caption), shared `EmptyState` for no
entries, `MediaGridSkeleton` while expanding, and a tonal bottom bar with the quality dropdown +
**pill** actions (tonal "Add to queue" + accent "Download now"). CI green (format · analyze ·
160 tests · debug APK).

**P7f done:** Queue task list elevated to status-aware **cards** — leading status avatar
(color + glyph), title, `status · site · duration` line, progress bar **only while active**,
and per-task actions (Pause/Cancel/Resume/Retry/Remove). Status palette shared between the
summary pills and tile avatars. CI green (format · analyze · 162 tests · debug APK).

**P7g done:** Item Detail revamped — hero media (player / zoomable image), large title,
technical **detail chips** (type · duration · resolution · size), metadata rows + an
**expandable description**, tag chips, and a prominent **accent "Save to device"** primary
(destination + "Saved" banner); Move/Edit/Studio stay as app-bar actions; loading-skeleton /
error / not-found states. Added a shared `formatBytes` util. CI green (format · analyze ·
168 tests · debug APK).

**P7h done:** Metadata Edit restyled to a clean form — shared `SectionHeader`s
(Details / Tags / Collections), themed filled Title/Notes fields, tag chips + add field,
collections checkboxes with inline "New" create, a labeled **Save** action, and
loading-skeleton / error / not-found states. CI green (format · analyze · 169 tests · debug APK).

**P7i done:** Media Studio restyled — a media **preview** header, tools grouped into **cards**
(Trim / Extract frame / Transform / Convert), themed sliders/chips (shared `formatDuration`),
shared empty/error/not-found + loading skeleton, and a polished **running overlay** (scrim +
op label + % + Cancel). Engine/ops/repo untouched; **crop** stays deferred (`docs/BACKLOG.md`).
CI green (format · analyze · 171 tests · debug APK).

**P7j done:** Collections restyled — list rows (circular icon avatar, name, **item count**,
delete) with an "New collection" extended FAB + name dialog; detail uses the shared `MediaGrid`.
Shared empty/skeleton/error states; added a `collectionItemCountsProvider` (group-by aggregate,
mirrors the folder counts). CI green (format · analyze · 175 tests · debug APK).

**P7k done:** Settings restyled — each section (Downloads / Downloader engine / Storage /
Appearance / Security) is an **icon-led `SectionHeader` + grouped card** (`SectionHeader` gained
an optional `icon`); themed filled filename field (token chips + preview); shared skeleton/error
states; all controls + logic unchanged. CI green (format · analyze · 176 tests · debug APK).

**P7l done:** Disclaimer + App Lock rebranded — Disclaimer leads with the **brand mark** + a
shield "Your responsibility" subheader over the scrollable terms and a full-width pill accept;
Lock gets a branded lock badge, a themed filled PIN field, a full-width Unlock, biometrics
secondary, and a **shake** on wrong PIN. Added a Lock-screen widget test. CI green
(format · analyze · 177 tests · debug APK).

Each screen subphase: confirm intent in `DESIGN_SPEC.md §7` → implement with P7a tokens +
P7b components → empty/loading/error + Simple/Advanced parity → on-device review → tick.

---

## Cross-cutting

**P7m done:** Adaptive-layout foundation + unified navigation + a11y sweep. Added a
window-size-class utility (`core/layout/window_size.dart`: Compact/Medium/Expanded/Large/
Extra-large) and a `ContentBounds` max-width wrapper so single-column screens (Add, Settings,
Metadata Edit, Item Detail, Queue, Collections list, Disclaimer) center/cap (~640) instead of
stretching, and galleries cap (~1280) on desktop while still adding columns. Navigation unified
into a `StatefulShellRoute` (Library · Queue · Collections · Settings) rendered as a bottom
`NavigationBar` on Compact → `NavigationRail` on Medium/Expanded → **extended rail** on
Large/desktop (`AdaptiveNavigationScaffold`); the Queue running-dot/badge + Collections count
moved to the nav destinations. a11y: search-clear tooltip, `Semantics` on selection tiles,
scrim-contrast bump; verified no overflow at 200% text scale. CI green (format · analyze ·
186 tests · debug APK).

### `[→]` P7n — Two-pane list-detail + foldable hinge/posture polish — **moved to `docs/BACKLOG.md`**
Deferred from the phase: it builds on the P7m foundation but needs a foldable emulator/device
to verify (headless CI can only check size-class branching), so it's tracked as a device-tested
backlog batch rather than blocking P7.

---

## Phase exit criteria
All subphases done (P7n deferred to the backlog); every screen verified on-device in light/dark
+ dynamic color; new icon/splash render; no regression in the P0–P6 on-device checks
(`docs/VERIFICATION.md`).
