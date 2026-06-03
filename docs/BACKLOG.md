# GrabBit — Backlog

> Living list of device-test findings and UX/feature refinements that don't map to a
> roadmap phase. Cleared via small PRs. `docs/ROADMAP.md` holds the phase plan (P0–P16);
> `docs/VERIFICATION.md` holds the on-device checklist.

## In progress
_(nothing active — pick the next batch from below)_

## Deferred / future refinements
- [ ] **Library "hide / filter AI tags" facet.** P13c-2 marks AI-applied tags (`media_tags.source = 'ai'`)
      and shows a ✦ on their chips, but the library tag facet (`watchDistinctTags`) treats them like any tag.
      Add a "hide AI tags" / "AI-tagged only" filter (and maybe a bulk "remove all AI tags on this item") if
      auto-tagging proves noisy. Also: promote an AI tag to 'user' when the user re-adds/keeps it. *(From P13c-2.)*
- [ ] **AI tag casing/normalization.** `addTagToItem` trims but doesn't lowercase, so P13c's AI suggestions
      are lowercased while manual/graph tags keep their case (e.g. `Live` vs `live` can coexist). Consider a
      single normalization policy (case-fold on store, or a display-case + fold-key) if duplicate-case tags
      become noisy. *(From P13c.)*
- [ ] **Translation — translate the summaries + cache + pack management.** P13b-2 translates the
      **description + transcript** only (the derived AI/TextRank summaries stay in the source language) and
      is **ephemeral** (re-translates each time; no DB cache). Future: also offer translated summaries, cache
      translations per target language, and a Settings screen to view/delete downloaded language packs (each
      ~30 MB). Also: surface a clear message for languages ML Kit can't translate. *(From P13b-2.)*
- [ ] **OCR — non-Latin scripts.** P13b-1 ships the **bundled Latin** ML Kit recognizer (no Google Play
      Services, offline). Chinese/Japanese/Korean/Devanagari need their own ML Kit script models (extra APK
      size or a download). Add a script choice if users want non-Latin OCR. *(From P13b-1.)*
- [ ] **Unconditional `--write-thumbnail` for image downloads.** `YtDlpHost.kt` passes
      `--write-thumbnail --convert-thumbnails jpg` for every download, so an image download wastes a fetch
      writing a thumbnail of the photo. P13b-3 handles this defensively in Dart (the classifier keeps the
      largest image as the photo and the smaller as its thumbnail), but a cleaner fix would gate the flag off
      at request time for image downloads (needs an `isImage`/`writeThumbnail` hint through the Pigeon
      `DownloadRequest`). *(From P13b-3 sweep.)*
- [ ] **Image formats outside `mediaTypeForExt`.** `.heic`/`.heif`/`.avif`/`.tiff` aren't in the image set,
      so such a download is classified as a `video` item. Add them (+ confirm the player/thumbnail handle
      them) if real downloads produce them. *(From P13b-3 sweep.)*
- [ ] **Auto-summarize — queue-decoupled background run.** P13a-2 generates the auto-summary **inline** in
      `_persistCompleted` before the next download pumps (gated on "model present" so it can't stall on a
      fetch), exactly like `autoTranscribe`. Generation is heavier than whisper-tiny, so a fuller design
      would run it **off the critical path** after the queue drains. Shares the existing "queue-decoupled
      background transcription" deferral below; the **LLM + Cozo HNSW RAM co-residency** check (P13d) also
      applies once auto-summary and the graph index can be resident together. *(From P13a-2.)*
- [ ] **AI summary — staleness on later transcript.** The cached `aiSummary` (P13a) is generated from
      `transcript ?? description` at the moment the user runs it; if a transcript is added *after* a
      description-based summary, the cache isn't auto-invalidated (the user can hit **Regenerate**). A
      future pass could flag/refresh it when the source changes. *(From P13a.)*
- [ ] **AI summary — long-transcript handling.** `buildSummaryPrompt` head-truncates the source to a char
      budget (small models have a limited context window). Long transcripts get only their head summarized;
      windowed chunking + a map-reduce summary is the richer path, tracked with the P13/GraphRAG
      multivector chunking work. *(From P13a.)*
- [ ] **(testing debt) Widget test for the P13a "Summarize with AI" flow** — the `_AiSummarySection`
      stream→persist→Regenerate path isn't widget-tested: the item-detail screen's player + perpetual
      related-items shimmer make `pumpAndSettle` unreliable (same boundary as the P10f-2 transcript flow).
      The pure pieces (`buildSummaryPrompt`, `aiSummaryAction`, `updateAiSummary`, the v11 migration) are
      unit-tested; the end-to-end UI is APK-verified. Revisit with `tester.runAsync` + a faked engine.
      *(From P13a.)*
- [ ] **Richer per-capability tier explainers.** P12g surfaces the device tier (banner + onboarding line)
      and a single generation "needs more memory" reason. A fuller treatment could show, per capability,
      exactly which models a device can/can't run and why — deferred as noise vs. value for v1; revisit if
      users ask "why can't I run X". (Also considered + dropped: surfacing raw `soc`/RAM in the UI —
      privacy/noise.) *(From P12g.)*
- [ ] **Structured-extraction model pick + real `generateStructured` impl.** P12f shapes the
      `generateStructured` seam (on `GenerationEngine`) and the `structured_extraction` matrix row, but
      both are **inert**: concrete engines throw `unsupported` and the row is empty on every tier. Resolve
      the **function-calling model-license fork** — **FunctionGemma 270M** (Gemma custom use-policy) vs
      **Qwen3-0.6B** (Apache-2.0, clean) — and wire a real impl (the flutter_gemma Chat API exposes only
      `TextResponse` today, so this likely needs a runtime/plugin path for tool-calling). → **P13**.
      *(From P12f.)*
- [ ] **`media_items` → MediaObject projection into `things`.** The v10 `things` table ships **empty**;
      the ADR-0003 field-by-field bridge that projects existing media into `Audio`/`Image`/`VideoObject`
      Things (and Cozo node sync, promoted-column indices/FTS, the bespoke/​generic Thing UI) is the v2
      Things-Engine build. *(From P12f.)*
- [ ] **Long-audio transcription — chunking + progress.** P12e transcribes a whole file in one
      whisper pass (fine for short clips; the queue gates auto-fallback on a downloaded model so it
      can't stall). Long videos want windowed chunking, a progress indicator, and cancellation.
      *(From P12e-3.)*
- [ ] **Word-level transcript cues.** P12e emits segment-level cues (`from_ts`→line). whisper.cpp can
      do word timings (`splitOnWord`); revisit for karaoke-style highlighting in the synced view.
      *(From P12e-3.)*
- [ ] **Queue-decoupled background transcription.** Auto-fallback runs inline in `_persistCompleted`
      before the next download pumps (gated on "model present" so it can't stall on a fetch). A fuller
      design would transcribe off the critical path after the queue drains, allowing a mid-queue model
      fetch without blocking. *(From P12e-3.)*
- [ ] **Device tier — `hasNpu`/`hasGpu` signals.** `DeviceProfile` tiers on RAM + OS today; reliable
      NPU/GPU/accelerator detection is hard and wasn't needed for the RAM-driven tier. Add it if a later
      model needs accelerator-aware gating. *(From P12a.)*
- [ ] **Tier-aware embedder *window* variant.** Gecko ships seq256; higher tiers could load the
      seq512/1024 export (same tokenizer/dim) for more transcript context — a real per-tier embedder
      choice once the catalog + download generalization (P12b) lands. *(From P12a.)*
- [ ] **Model download resume / HTTP Range.** `ModelDownloadService` re-fetches a file whole if a
      download is interrupted (the `.part` is overwritten next run; verify-then-rename means no
      corruption risk). Add `Range`/resume if large-model re-downloads prove costly on flaky networks.
      *(From P12b.)*
- [x] **Rename `InferenceEngine` → `EmbedderEngine`.** Done — pure mechanical rename (engine + factory +
      providers + tests + `OnnxEmbedderEngine`/`FlutterGemmaEmbedderEngine`/`UnavailableEmbedderEngine`);
      the shared `InferenceException`/`InferenceErrorCode` taxonomy kept (used by both AI engines).
      *(From P12d-1; done off-phase before P12d-2.)*
- [ ] **Flagship device tier.** The 3-tier `low/mid/high` lumps 6 GB midrangers with 12–16 GB flagships;
      generation could offer even larger models on a true flagship tier. Add once on-device telemetry from
      testers justifies the threshold split. *(From P12d-1.)*
- [ ] **GraphRAG LLM + HNSW co-residency (P13).** "Ask your library" runs the generation LLM and the Cozo
      HNSW vector index in RAM *together*; P12d only proves generation in isolation (Labs self-test). Validate
      combined memory headroom on real devices when P13 wires GraphRAG. *(From P12d-2.)*
- [ ] **Revisit the generation flagship rung.** Shipped Gemma-4 E2B (2.5 GB) as the flagship because Qwen3-4B
      has no LiteRT build. If a >1.5B **Qwen/SmolLM-family Apache** LiteRT build appears, consider it
      (Gemma-4 is Apache-2.0 + ungated, so this is preference, not a posture fix). *(From P12d-2.)*
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
