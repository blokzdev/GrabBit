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

### `[ ]` P7b — Shared component library
- Restyle reusable widgets to the system: `MediaGrid`/`MediaTile`, `confirm()` dialog,
  settings tiles/section headers, error banners, queue task tile, filter bar.
- Add shared **empty / skeleton-loader / error** widgets in `lib/core/widgets/`.
- Expressive go_router page transitions + thumbnail **hero** animation.
- **Exit / review:** components demoed across a couple of screens; empty/skeleton/error
  render correctly.

---

## Per-screen

| Subphase | Screen(s) | Routes |
|---|---|---|
| `[ ]` P7c | Home — Library + Explorer views | `/` |
| `[ ]` P7d | Add Download | `/add` |
| `[ ]` P7e | Selection | `/select` |
| `[ ]` P7f | Queue | `/queue` |
| `[ ]` P7g | Item Detail | `/item/:id` |
| `[ ]` P7h | Metadata Edit | `/item/:id/edit` |
| `[ ]` P7i | Media Studio | `/item/:id/studio` |
| `[ ]` P7j | Collections (list + detail) | `/collections`, `/collection/:id` |
| `[ ]` P7k | Settings | `/settings` |
| `[ ]` P7l | Disclaimer + Lock | `/disclaimer`, `/lock` |

Each screen subphase: confirm intent in `DESIGN_SPEC.md §7` → implement with P7a tokens +
P7b components → empty/loading/error + Simple/Advanced parity → on-device review → tick.

---

## Cross-cutting

### `[ ]` P7m — Responsive / foldable / accessibility
Large-screen + unfolded-foldable layouts (wider column / two-pane, not stretched phone);
touch targets ≥48dp; semantics labels; dynamic-type; AA contrast — swept across all
screens. Closes the phase.

---

## Phase exit criteria
All subphases done; every screen verified on-device in light/dark + dynamic color;
new icon/splash render; no regression in the P0–P6 on-device checks
(`docs/VERIFICATION.md`). → open the P7 PR into `main`.
