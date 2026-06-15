# Third-Party Notices

GrabBit is licensed under **GPL-3.0** (see [`LICENSE`](LICENSE)). It bundles, links, or downloads the
third-party components below, each under its own license. This file preserves their notices and points to
their sources, as required when conveying the combined work.

## Bundled / linked in the shipped app (Android)

### youtubedl-android (JunkFood02 fork) — the download engine
- **License:** GPL-3.0 (per upstream)
- **Artifact:** `io.github.junkfood02.youtubedl-android:{library,ffmpeg}` (Maven Central)
- **Source:** https://github.com/JunkFood02/youtubedl-android
- Bundles the following as native libraries:
  - **ffmpeg** — LGPL-2.1-or-later / GPL (per the build shipped by youtubedl-android). Source:
    https://ffmpeg.org/
  - **yt-dlp** — Unlicense (public domain). Source: https://github.com/yt-dlp/yt-dlp
  - **Python (CPython)** — PSF License. Source: https://www.python.org/

### CozoDB — on-device graph + vector engine
- **License:** MPL-2.0 (standard variant, GPL-compatible)
- **Artifact:** `io.github.cozodb:cozo_android` (native library, linked **unmodified**)
- **Source:** https://github.com/cozodb/cozo

### schema.org vocabulary — Things validation/grounding data (P14)
- **License:** **CC BY-SA 3.0** (https://creativecommons.org/licenses/by-sa/3.0/)
- **Asset:** `assets/vocab/schemaorg-current-https.jsonld` — the schema.org vocabulary **v30.0**, vendored
  **unmodified** as a read-only data asset (not code; GrabBit's own code stays GPL-3.0).
- **Source:** https://schema.org · https://github.com/schemaorg/schemaorg (`data/releases/30.0/`)
- **Attribution:** "schema.org" — © schema.org community; see `assets/vocab/README.md`.

### ML Kit barcode model (via `mobile_scanner`, P16b-4) — barcode/QR scanning
- **License:** `mobile_scanner` plugin **MIT**; the on-device barcode-scanning model binary is
  Google's ML Kit, **bundled in the APK** and run offline (no Google Play Services).

## Downloaded on demand at runtime (not bundled in the app)

- **Embedding / generation models** (Gecko, paraphrase-multilingual-MiniLM-L12-v2, SmolLM2, Qwen3 /
  Qwen2.5, Gemma-4 E2B): **Apache-2.0**.
- **whisper.cpp** speech-to-text models (via `whisper_ggml_plus`): **MIT**.
- **ML Kit** OCR / translation / language-id (`google_mlkit_*`): **MIT** plugins; the on-device model
  binaries are Google's, downloaded over HTTPS and run offline (no Google Play Services).

## Flutter / Dart packages

The remaining Flutter and Dart package dependencies retain their own (overwhelmingly permissive —
MIT / BSD / Apache-2.0) licenses. See `pubspec.lock` and each package's `LICENSE` in the pub cache
(`flutter pub deps`).

---

Where a component is copyleft (youtubedl-android, ffmpeg, CozoDB), its corresponding source is available at
the URLs above; GrabBit links/bundles these **unmodified**.
