# GrabBit — Backlog

> Living list of device-test findings and UX/feature refinements that don't map to a
> roadmap phase. Cleared via small PRs. `docs/ROADMAP.md` holds the phase plan (P0–P16);
> `docs/VERIFICATION.md` holds the on-device checklist.

## In progress
_(nothing active — pick the next batch from below)_

## Deferred / future refinements
- [ ] **P11d — dedicated notification status-bar icon.** OS notifications use
      `@mipmap/ic_launcher` as the small icon, which Android renders as a solid square in the status
      bar. Ship a monochrome white/transparent small icon (e.g. `@drawable/ic_stat_grabbit`) for the
      proper finish. *(From P11d — cosmetic only.)*
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
      v2/P16: it's native, on-device-only verification, and pure polish.)*
- [ ] **Duplicate bulk-cleanup keep-policy** — P10c-d-1's **Clean up** keeps the *oldest* copy in each
      group. Offer alternatives (keep *largest* / *newest* / let the user pick which to keep) if the
      fixed policy proves too blunt on-device. *(From P10c-d-1.)*
- [ ] **Similarity-clustering scale path** — P10c-d-2 computes Suggested-album clusters by pulling all
      embeddings and doing **pairwise cosine in Dart** (exact, simple, fine for modest libraries). If
      it gets slow on large libraries, move to **HNSW-per-item** queries or **materialize `similarTo`
      edges** during sync (the schema already reserves the relation). *(From P10c-d-2.)*
- [ ] **Cross-type related entities on hubs** — P10c-c-2 shipped a tag-only **"Related tags"** strip
      (co-occurrence over `taggedWith`). Extend it to related **creators / playlists**, ranked by
      degree/PageRank (per `docs/GRAPH-SPEC.md §7`), as typed chips that open the matching hub. The
      uploader-name↔`uploaderId` bridge used for the tag strip already shows the pattern. *(From P10c-c-2.)*
- [ ] **(testing debt) Tag-suggestion apply-on-tap assertion** — the metadata editor's suggestion-chip
      tap isn't asserted to persist: a real Drift write under the fake-async widget harness needs
      `tester.runAsync` **and** a seeded `media_items` row (to satisfy the `media_tags` FK). The widget
      test currently asserts the chip is wired (`onPressed != null`); the `addTagToItem` write itself is
      unit-tested in the repository test. *(From P10c-c-2.)*
- [ ] **TikTok photo/slideshow (`/photo/`) posts** aren't downloadable — an **upstream yt-dlp
      limitation** (the TikTok extractor doesn't match `/photo/`; falls back to generic →
      "Unsupported URL"). Tracked at yt-dlp #10870/#9990. Not fixable in-app; GrabBit now shows a
      clear "not supported yet" notice for it (and any unsupported link) instead of a misleading
      "update" prompt. Revisit if/when yt-dlp adds photo-post support.
- [ ] **Enumerate a video's available caption languages** in the P10f-2 "Get transcript" picker
      (instead of the curated list). **Deferred indefinitely:** YouTube's `automatic_captions` lists
      ~100 machine-translated languages, so a useful "available" list needs fragile filtering (real
      `subtitles` + the *original* auto-caption language); it also needs native probe/JSON-parsing
      changes + a `MediaInfo`/Pigeon DTO field and a pre-picker network round-trip (latency + a failure
      surface). The curated picker is robust (yt-dlp simply no-ops on an unavailable language), so this
      isn't worth the complexity now. *(From P10f-2.)*
- [ ] **(testing debt) Widget test for the P10f-2 "Get transcript" UI flow** — the menu →
      language-picker → fetch → store path isn't widget-tested: it does real `dart:io` caption-file
      reads (don't complete in `flutter_test`'s fake-async zone) and the screen has a perpetual
      related-items shimmer (so `pumpAndSettle` hangs). The request-building (`buildCaptionFetchRequest`)
      + `skipDownload` serialization/mapping are unit-tested; the end-to-end flow is APK-verified.
      Revisit with `tester.runAsync` + faked transcript/engine providers. *(From P10f-2.)*
- [ ] **Settings search → scroll-to-and-highlight the exact control.** P10j-c2's search opens the
      target sub-screen (or scrolls to a landing section); it doesn't yet scroll to and flash the
      specific row within a sub-screen. The sub-screens are short so this is minor; add a transient
      highlight + per-control anchors if it proves fiddly on device. *(From P10j-c2.)*
- [ ] **Fuzzy / typo-tolerant settings search.** P10j-c2 does plain case-insensitive substring over
      label + keywords. Add light fuzzy matching (e.g. token prefix / small edit distance) if exact
      substring proves too strict in practice. *(From P10j-c2.)*
- [ ] **Persist recent settings searches** (and consider a single global, app-wide search that spans
      Settings + library). Out of scope for P10j-c2's Settings-only quick-jump. *(From P10j-c2.)*
- [ ] **Activity Inbox — batch/bulk download summary.** A playlist/bulk job posts one entry per task
      (`download_<id>` dedupe is per-task). Coalesce a batch into a single "N downloads completed"
      entry to cut inbox noise. *(From P11c.)*
- [ ] **Activity Inbox — undo on swipe-dismiss.** Swiping a notification dismisses it immediately;
      add a "Dismissed · Undo" snackbar to restore an accidental swipe. *(From P11c.)*
- [ ] **Activity Inbox — retroactive retention re-derivation.** `expiresAt` is derived per row at
      insert (P11a), so changing the retention setting only affects *future* entries. A future pass
      could recompute existing rows on change. *(Accepted P11a tradeoff; from P11c.)*
- [ ] **Activity Inbox — `reminder`-category producers.** The `reminder` category + always-record
      gating exist with no producer yet. Candidate nudges (items missing transcripts, a held batch
      waiting to start, low-storage reminder) — needs a product call to avoid nagging. *(From P11c.)*
- [ ] **Things Engine (v2) — the typed-artifact library.** Reframe the library as a domain-agnostic
      graph of schema.org Things (Recipe/Event/Place/Article/Product + the MediaObjects), captured by a
      narrow-then-fill curator and reasoned over by on-device GraphRAG. Strategic decisions are locked;
      not yet scheduled (no P-number). *(Things Engine v2 — `docs/things-engine.md`, ADR-0001–0004.)*
- [ ] **Things Engine — full physical spine (open question).** v2 adopts the *logical* spine (Things
      are the conceptual/graph model; `media_items` stays canonical, `MediaObject` is the file-leaf).
      Whether to physically absorb `media_items` into the generic `things` table is **deferred /
      unscheduled** — real file-lifecycle migration weight, no urgency. *(Things Engine v2 — ADR-0003.)*

## Pulled into the roadmap
_(promoted out of the backlog into a planned phase — see `docs/ROADMAP.md`)_
- [ ] **Dashboard home** → scheduled as **P10d** (`docs/design/P-AI-PLAN.md`): a 5th nav destination
  and the new default landing (`/`), visualizing the on-device footprint with `fl_chart`. Split into
  P10d-1 (foundation), P10d-2 (charts), P10d-3 (recent/suggestions/graph). *(Raised during P10c-e.)*
- [x] **Advanced format/codec picker** on Add Download → shipped in **P8d**
  (`docs/design/P8-PLAN.md`). *(Was deferred from P7d.)*
- [x] Queue **drag-to-reorder** + aggregate **dashboard** (live speed / ETA / total size) →
  shipped in **P9d** (`docs/design/P9-PLAN.md`). Speed/size are recovered by parsing the
  yt-dlp progress line in Dart (`core/engine/progress_line.dart`).
- [ ] **FTS5 full-text search** → scheduled as **P10h** (`docs/ROADMAP.md`): SQLite FTS5 over
  transcript + description + title, so the library is searchable by **spoken content** (P10f
  transcripts), not just title/description `LIKE`. *(Promoted now that transcripts exist.)*

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
- [ ] **Configurable storage location** (internal vs SD / external app-specific dir) — deferred
      from P9f: scoped-storage complexity (volume enumeration, migrating an existing library,
      removable-media eject). The P9f low-storage guard mitigates the immediate pain.
- [ ] **Extractive TextRank summarization** (pure-Dart, zero-dependency) — considered for P9 and
      deferred to **P13** as the always-available baseline tier beneath the local LLM summary
      (see `docs/ROADMAP.md` P13). Acts on captured descriptions/subtitles/transcripts.

## Done
- [x] **Engine auto-update on launch** + Settings toggle (fresh installs were failing
      YouTube with "Please sign in" until a manual yt-dlp update). — *batch 1, #25*
- [x] **Download start choice**: single videos get "Download now" vs "Add to queue"
      (held, manual start), matching the batch screen. — *batch 1, #26*
- [x] **Queue back button**: the queue screen could strand the user (reached via
      `context.go`); fixed navigation + added a defensive Back/Home. — *batch 1, #26*
- [x] **Queue manager polish**: header counts + "Resume all". — *batch 1, #26*
