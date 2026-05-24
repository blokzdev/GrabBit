# P8 — Download Engine Power & Intake: subphase plan

> The sub-roadmap for **P8** (see `docs/ROADMAP.md`). P8 deepens the downloader into a
> power-user tool and makes getting links in effortless. Everything is **on-device =
> FREE** (CLAUDE.md §1): no cloud, no accounts, and **no authenticated/cookie work**
> (that stays in v2, P15). Most of P8 is native (Pigeon → Kotlin → youtubedl-android),
> so it is verified on-device.

## How subphases work
- Each subphase is a **commit** on `claude/p8-download-power`. It must keep CI green
  (`dart format` · `flutter analyze` · `flutter test`), run `build_runner` if codegen
  (freezed/json/drift/pigeon) changed, and update `docs/VERIFICATION.md`.
- **One foundational native batch:** P8b expands `DownloadRequest`/`DownloadRequestDto`/
  `YtDlpHost.kt`. P8c and P8d **consume** those fields, so P8b lands first.
- **On-device review:** APK builds are **manual / user-triggered** (Actions minutes are
  scarce — CLAUDE.md §6). Batch the native subphases (P8a + P8b + P8c) into one APK build;
  P8d is pure-Dart and ships as a standalone green-CI PR.
- **PR cadence:** open the PR into `main` at phase end (per CLAUDE.md §7). No PR is opened
  automatically.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[~]` P8a — Android share-sheet intake
- `ACTION_SEND` / `ACTION_SEND_MULTIPLE` (`text/plain`) `<intent-filter>` on `MainActivity`
  in `android/app/src/main/AndroidManifest.xml` (launchMode is already `singleTop`, so
  `onNewIntent` handles warm-start delivery).
- **Hand-rolled Pigeon intent channel** rather than `receive_sharing_intent` — GrabBit
  already owns its Pigeon bridge and the package has a history of AGP/namespace breakage
  (avoid abandoned plugins, CLAUDE.md §2). Kotlin reads the shared text and hands the URL
  to Dart on launch/resume.
- Dart: a startup/resume listener routes the shared URL to `add_download_screen.dart`
  pre-filled, reusing the paste path in `downloader_controller.dart`. **Pure-Dart +
  tested:** URL extraction/normalization from arbitrary shared text (find first URL, strip
  tracking params). Links-only — shared local files are out of scope here.
- **Exit / review:** share a link from the YouTube / Instagram app (and a browser) → GrabBit
  opens Add-Download pre-filled with that URL.
- **Status:** implemented (Pigeon `ShareHostApi`/`ShareFlutterApi`, `MainActivity` intent
  handling, manifest `ACTION_SEND`/`ACTION_SEND_MULTIPLE` filter, `ShareIntakeService` +
  `extractSharedUrl` with tests, Add-Download pre-fill). **Pending on-device verification.**

### `[~]` P8b — Engine request expansion + power-download options *(foundational native batch)*
- Add fields to `DownloadRequest` (`lib/core/engine/download_engine.dart`),
  `DownloadRequestDto` (`pigeons/engine.dart`), and the arg-builder in
  `android/app/src/main/kotlin/dev/blokz/grabbit/YtDlpHost.kt`:
  - `rateLimitBytesPerSec` → `--limit-rate`
  - `concurrentFragments` → `--concurrent-fragments N` *(the safe speed win — aria2c is cut,
    see `docs/BACKLOG.md`: youtubedl-android ships no aria2c binary)*
  - `extraArgs: List<String>` → Seal-style escape hatch, **Advanced-mode only, validated at
    the boundary** (CLAUDE.md §8); warn the user
  - `useDownloadArchive` → `--download-archive <app-private file>` (skip already-downloaded
    items on playlist/channel re-runs)
  - `audioCodec` / `audioBitrate` → `--audio-format` / `--audio-quality`
- Mirror the new options in `SettingsModel` (JSON blob — **no DB migration**); re-run
  freezed/json codegen. Pure-Dart + tested: settings serialization, arg-mapping validation.
- **Exit / review:** set a rate-limit + concurrent-fragments, add a custom arg, and re-run a
  playlist with the archive on → already-downloaded items are skipped.
- **Status:** implemented — 5 new `DownloadRequest`/DTO fields + `YtDlpHost.kt` arg mapping;
  6 new settings; shared `download_request_builder` (single + batch) with tested `parseExtraArgs`;
  "Faster downloads (beta)" toggle + Advanced "Advanced download options" section. CI-green
  (builder/mapper/settings tests). **Pending on-device verification.**

### `[~]` P8c — Subtitles, SponsorBlock, chapters *(extends P8b; same APK batch)*
- **Subtitles:** replace the `subtitles` bool with `subtitleLangs: List<String>`,
  `subtitleFormat`, `autoSubs`, `burnIn` → `--sub-langs` / `--write-auto-subs` /
  `--convert-subs`. **Burn-in is a post-download ffmpeg step** (`-vf subtitles=…`) via the
  existing `ffmpeg_kit_flutter_new` path (Advanced-only — it's a full re-encode).
- **SponsorBlock:** a `sponsorBlock` field (mode mark/remove + categories) →
  `--sponsorblock-mark` / `--sponsorblock-remove`. Pure yt-dlp postprocessor, no extra binary.
- **Chapters:** `--embed-chapters`; optional `--split-chapters`. **Split is the trickiest
  plumbing** — it breaks the one-task → one-folder → one-item pickup convention in
  `YtDlpHost.kt`; the library-import side must map N produced files → N library items with
  threaded metadata.
- **Exit / review:** download with chosen subtitle languages (optionally burned-in),
  SponsorBlock segments removed, and chapters embedded / split into separate items.
- **Status:** implemented — structured subtitle fields (`--sub-langs`/`--write-auto-subs`/
  `--convert-subs`/`--embed-subs`) replacing the `subtitles` bool; SponsorBlock mark/remove +
  category chips; embed/split chapters. Completion handler hardened via a unit-tested
  `classifyDownloadOutputs` (excludes subtitle/JSON sidecars) + N-file import for split-chapters.
  Burn-in shipped as a Media Studio tool (`burnInSubtitlesArgs`, sidecar discovery). CI-green.
  **Pending on-device verification.**

### `[~]` P8d — Advanced format/codec + audio-preset picker *(pure Dart, CI-green)*
- In `add_download_screen.dart` (Advanced mode), list the probed `MediaInfo.formats`
  (resolution / codec / filesize from the existing `probe`) and let the user pick a concrete
  `formatId`; add an audio codec/bitrate picker feeding the P8b fields. Pulls in the BACKLOG
  advanced-format-picker item. Widget-tested.
- **Exit / review:** in Advanced mode, pick a specific format and an audio codec/bitrate; the
  download honours both.
- **Status:** implemented — pure-Dart `formatSelectorFor` (video-only auto-merges `+bestaudio`);
  generalized `enqueue` with per-download audio overrides; `_FormatPicker` adds an Advanced
  "Choose a specific format" list + audio codec/bitrate dropdowns. CI-green. **Pending on-device
  verification.** *(Completes P8.)*

---

## Deferred (cut from P8 → `docs/BACKLOG.md`)
- **aria2c external downloader** — fragile ABI-specific binary, APK-heavy, re-opens the 16 KB
  page-size issue; `--concurrent-fragments` covers ~90% of the value.
