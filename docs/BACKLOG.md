# GrabBit — Backlog

> Living list of device-test findings and UX/feature refinements that don't map to a
> roadmap phase. Cleared via small PRs. `docs/ROADMAP.md` holds the phase plan (P0–P13);
> `docs/VERIFICATION.md` holds the on-device checklist.

## In progress
- [ ] **Engine auto-update on launch** + Settings toggle (fresh installs were failing
      YouTube with "Please sign in" until a manual yt-dlp update). — *batch 1, PR A*
- [ ] **Download start choice**: single videos get "Download now" vs "Add to queue"
      (held, manual start), matching the batch screen. — *batch 1, PR B*
- [ ] **Queue back button**: the queue screen could strand the user (reached via
      `context.go`); fix navigation + add a defensive Back/Home. — *batch 1, PR B*
- [ ] **Queue manager polish**: header counts + "Resume all". — *batch 1, PR B*

## Deferred / future refinements
- [ ] Queue **drag-to-reorder** and per-item move up/down.
- [ ] Queue **dashboard**: aggregate speed / ETA / total size; multi-select batch ops.
- [ ] Media Studio **crop** tool (image + video) — interactive rectangle UI.
- [ ] Broader **UI polish** pass (spacing, empty states, responsive layouts).
- [ ] **16 KB page-size** validation on Pixel 9 / Android 15+ (ffmpeg/python native
      libs); adopt a 16 KB-aligned ffmpeg-kit build if needed.

## Done
_(moved here as items ship)_
