# GrabBit — Backlog

> Living list of device-test findings and UX/feature refinements that don't map to a
> roadmap phase. Cleared via small PRs. `docs/ROADMAP.md` holds the phase plan (P0–P14);
> `docs/VERIFICATION.md` holds the on-device checklist.

## In progress
_(nothing active — pick the next batch from below)_

## Deferred / future refinements
- [ ] **Advanced format/codec picker** on Add Download — in Advanced mode, list the probed
      `MediaInfo.formats` (resolution / codec / filesize) and let the user pick a specific
      one. Needs `enqueue`/`DownloadRequest` to accept a concrete format selector, not just a
      `QualityPreset`. *(Deferred from P7d, which was a styling pass.)*
- [ ] **Library/Explorer error-state widget test** (testing debt) — driving a `StreamProvider`
      into its error state was unreliable under the fake-async widget-test harness; revisit via
      a `ProviderContainer`-level assertion. (`ErrorView` itself is unit-tested.) *(From P7b.)*
- [ ] Queue **drag-to-reorder** and per-item move up/down.
- [ ] Queue **dashboard**: aggregate speed / ETA / total size; multi-select batch ops.
- [ ] Media Studio **crop** tool (image + video) — interactive rectangle UI.
- [ ] Broader **UI polish** pass (spacing, empty states, responsive layouts). —
      *now folded into **P7 — Branding & Frontend Revamp***
- [ ] **16 KB page-size** validation on Pixel 9 / Android 15+ (ffmpeg/python native
      libs); adopt a 16 KB-aligned ffmpeg-kit build if needed.

## Done
- [x] **Engine auto-update on launch** + Settings toggle (fresh installs were failing
      YouTube with "Please sign in" until a manual yt-dlp update). — *batch 1, #25*
- [x] **Download start choice**: single videos get "Download now" vs "Add to queue"
      (held, manual start), matching the batch screen. — *batch 1, #26*
- [x] **Queue back button**: the queue screen could strand the user (reached via
      `context.go`); fixed navigation + added a defensive Back/Home. — *batch 1, #26*
- [x] **Queue manager polish**: header counts + "Resume all". — *batch 1, #26*
