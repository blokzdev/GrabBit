# GrabBit — Backlog

> Living list of device-test findings and UX/feature refinements that don't map to a
> roadmap phase. Cleared via small PRs. `docs/ROADMAP.md` holds the phase plan (P0–P15);
> `docs/VERIFICATION.md` holds the on-device checklist.

## In progress
_(nothing active — pick the next batch from below)_

## Deferred / future refinements
- [ ] **P7n — Two-pane list-detail + foldable hinge/posture polish.** Show list-detail
      side-by-side on Expanded+ widths (Library↔Item Detail, Collections↔detail); avoid the
      hinge via `MediaQuery.displayFeatures`/`hinge`; preserve selection/scroll across
      fold/unfold; optional tabletop posture for the in-app player. Builds on the P7m
      window-size foundation (`core/layout/window_size.dart`, `AdaptiveNavigationScaffold`).
      **Needs a foldable emulator/device to verify** — headless CI can only check size-class
      branching, so this is deliberately a device-tested batch. *(Deferred from P7m.)*
- [ ] **Library/Explorer error-state widget test** (testing debt) — driving a `StreamProvider`
      into its error state was unreliable under the fake-async widget-test harness; revisit via
      a `ProviderContainer`-level assertion. (`ErrorView` itself is unit-tested.) *(From P7b.)*
- [ ] Media Studio **crop** tool (image + video) — interactive rectangle UI.
- [ ] Broader **UI polish** pass (spacing, empty states, responsive layouts). —
      *now folded into **P7 — Branding & Frontend Revamp***
- [ ] **16 KB page-size** validation on Pixel 9 / Android 15+ (ffmpeg/python native
      libs); adopt a 16 KB-aligned ffmpeg-kit build if needed.
- [ ] **Picture-in-Picture** for the in-app player. *(Deferred from P9c-2 → revisit in
      v2/P15: it's native, on-device-only verification, and pure polish.)*
- [ ] **TikTok photo/slideshow (`/photo/`) posts** aren't downloadable — an **upstream yt-dlp
      limitation** (the TikTok extractor doesn't match `/photo/`; falls back to generic →
      "Unsupported URL"). Tracked at yt-dlp #10870/#9990. Not fixable in-app; GrabBit now shows a
      clear "not supported yet" notice for it (and any unsupported link) instead of a misleading
      "update" prompt. Revisit if/when yt-dlp adds photo-post support.

## Pulled into the roadmap
_(promoted out of the backlog into a planned phase — see `docs/ROADMAP.md`)_
- [x] **Advanced format/codec picker** on Add Download → shipped in **P8d**
  (`docs/design/P8-PLAN.md`). *(Was deferred from P7d.)*
- [x] Queue **drag-to-reorder** + aggregate **dashboard** (live speed / ETA / total size) →
  shipped in **P9d** (`docs/design/P9-PLAN.md`). Speed/size are recovered by parsing the
  yt-dlp progress line in Dart (`core/engine/progress_line.dart`).

## Cut from P8 / P9 (deliberate — kept here with rationale)
- [ ] **aria2c external downloader** — youtubedl-android ships no aria2c binary; bundling an
      ABI-specific binary is fragile, APK-heavy, and re-opens the 16 KB page-size issue.
      `--concurrent-fragments` (shipped in P8b) gets ~90% of the value.
- [ ] **Decoy / duress PIN + decoy vault** — security theater; high complexity, dubious
      real-world protection, easy to get subtly wrong.
- [ ] **Intruder selfie on failed unlock** — requires CAMERA permission, directly violating
      the least-privilege / no-telemetry privacy posture (CLAUDE.md §9). Cut on principle.
- [ ] **App-icon disguise / activity-alias** — unreliable launcher re-pin post-Android-10;
      a common source of "app disappeared" reports.
- [ ] **Background audio playback** — valuable, but adds a second foreground-service type to
      coordinate with the download service; revisit in v2.
- [ ] **Download scheduling** (run at a time / wifi window) — needs WorkManager + alarm logic.
- [ ] **Per-folder lock** — adds lock-state to the virtual-folder model + many UI gates.
- [ ] **FTS5 full-text search** — start with indexed `LIKE` (P9b); adopt FTS5 only if perf demands.
- [ ] **Configurable storage location** (internal vs SD / external app-specific dir) — deferred
      from P9f: scoped-storage complexity (volume enumeration, migrating an existing library,
      removable-media eject). The P9f low-storage guard mitigates the immediate pain.
- [ ] **Extractive TextRank summarization** (pure-Dart, zero-dependency) — considered for P9 and
      deferred to **P12** as the always-available baseline tier beneath the local LLM summary
      (see `docs/ROADMAP.md` P12). Acts on captured descriptions/subtitles/transcripts.

## Done
- [x] **Engine auto-update on launch** + Settings toggle (fresh installs were failing
      YouTube with "Please sign in" until a manual yt-dlp update). — *batch 1, #25*
- [x] **Download start choice**: single videos get "Download now" vs "Add to queue"
      (held, manual start), matching the batch screen. — *batch 1, #26*
- [x] **Queue back button**: the queue screen could strand the user (reached via
      `context.go`); fixed navigation + added a defensive Back/Home. — *batch 1, #26*
- [x] **Queue manager polish**: header counts + "Resume all". — *batch 1, #26*
