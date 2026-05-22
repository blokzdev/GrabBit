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

### `[ ]` P7a — Brand identity & design foundation
- Design the rabbit-ears **SVG** logo; present **2–3 directions** for sign-off.
- Generate the **adaptive launcher icon** (foreground / background / **monochrome**),
  **notification** icon, and themed **splash** (light/dark).
- Add deps: `flutter_svg`; dev `flutter_launcher_icons`, `flutter_native_splash`;
  `google_fonts` (or bundled font). Register `assets/brand/` in `pubspec.yaml`. Justify
  in commit + add to `docs/SPEC.md`.
- Expand `lib/core/theme/app_theme.dart` into a full **Material 3 Expressive** theme
  (color/type/shape/motion + component themes), keeping `DynamicColorBuilder` in
  `lib/app.dart` working; replace the `0xFF6750A4` seed with the brand seed.
- Add `GrabBitTokens extends ThemeExtension` (spacing, radii, elevation, durations, brand
  colors) in `lib/core/theme/`.
- **Exit / review:** new icon + splash render on-device; app adopts the new theme in
  light/dark + dynamic color with no regressions.

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
