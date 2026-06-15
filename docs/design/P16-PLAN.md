# P16 — Universal intake + typed types, UX & GraphRAG: subphase plan

> The sub-roadmap for **P16** (see `docs/ROADMAP.md` and the vision one-pager
> `docs/things-engine.md`). P16 is the **third and final phase of the Things Engine band
> (P14–P16)** — it turns the typed library into the everything-library's home. It completes
> ADR-0002's curator with **branch (a) direct-parse** (structured JSON-LD/OpenGraph/microdata
> → a Thing with no model call), opens **universal "Grab anything" intake** (URL, file,
> web-article, manual entry, camera/barcode — all routed through the same store + curator),
> gives the **~6 priority types bespoke cards + exporters** (the long tail stays generic —
> ADR-0001), deepens the **Things Browser** into a searchable, relationship-aware home,
> surfaces the **authored-edge + reified-relationship moat** (ADR-0004), and extends
> **typed-node GraphRAG to answer over any Thing** via a Thing-level embedding index. P16 is
> **device-universal** for the floor — direct-parse capture, storage, bespoke/generic
> rendering, the browser, and authored edges run on **every device**; only the **model fill**
> (curator branches b/c) and **GraphRAG generation** are AI-tier-gated and **gracefully
> disabled** with a friendly reason. Deep contracts: `docs/decisions/` (ADR-0001 schema-as-data
> · ADR-0002 narrow-then-fill curator, branch a · ADR-0004 relationships/provenance/authored
> moat), `docs/AI-SPEC.md` §2/§5–6, `docs/GRAPH-SPEC.md` §10.

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named
  `claude/p16<sub>-<topic>`. Each keeps CI green (`dart format` · `flutter analyze` ·
  `flutter test`), runs `build_runner` if codegen (drift/riverpod/freezed/json) changed, and
  updates `docs/VERIFICATION.md` for new user-facing/on-device behaviour.
- **Each subphase gets its own plan** (plan → approve → execute, CLAUDE.md §7). This doc is the
  **map**: it locks the decomposition + phase-level decisions; per-subphase design happens at
  that subphase's start.
- **No schema migration:** P16 introduces **no Drift `vN→vN+1` bump** — search reuses the
  promoted `name`/`type` columns, edges/reified Notes reuse `thing_edges`/`things`, and the
  only index change is the **Cozo `thing_embedding`** relation (P16f), applied via the
  `GraphSyncService` fingerprint rebuild. A dedicated Things FTS5 table is deferred to BACKLOG.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). **P16a** is
  pure-Dart and ships as a standalone green-CI PR; the subphases that touch real intake, the
  camera, UI, the native graph, or the model — **P16b–P16f** — need APK spot-checks and are
  **batched** into the P16 consolidated on-device pass (**P16g**).
- **Build on existing seams, don't fork them:** the `Curator`/`thing_classifier`/
  `priority_types` routing; `ThingRepository`/`ThingSuggestionRepository`/`ThingEdgeRepository`;
  `SchemaOrgVocabulary`/`validateThingDoc`/`grabbitProvenanceBlock`; the P15d
  `postSuggestionNotification` + `SuggestionReviewScreen`; the `ShareIntakeService`/
  `AddDownloadScreen` intake patterns; `things_browse_providers` + `ThingsBrowserScreen`;
  `RagRetriever` + `NodeHydration`; and `GraphSyncService.backfillEmbeddings` + `cozo_schema`/
  `graph_projection`.
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Branch (a) direct-parse is the device-universal capture floor (ADR-0002).** A pure parser
  reads already-structured signals — JSON-LD `<script type="application/ld+json">`, OpenGraph
  `og:*`, and microdata/RDFa — into a validated `ThingDoc` with **zero inference**, stamped
  `grabbit:provenance = direct-parse`. Only when no structure is present does capture escalate
  to the P15 curator (branches b/c), which is tier-gated. Direct-parse, storage, the generic/
  bespoke render, the browser, and authored edges run on **every device**.
- **One curator, many intakes.** Every new intake path (file, web-article, manual, barcode)
  funnels through a single `CaptureService` seam → branch (a) if structured, else curator. Web-
  article fetch is a **user-initiated** network call (consistent with downloads) — no account,
  no cloud.
- **Commit model: assert-direct for deterministic captures, review only AI (ADR-0004).**
  Deterministic, user-initiated captures — manual entry, branch (a) direct-parse, barcode —
  **assert straight into `things`** via `CaptureCommitService.commitThing` (mints `thing_<micros>`,
  no source-media edge) with a confirmation + Undo. Only **model-extracted** (AI-inferred, branch
  b/c) captures stay suggest-don't-assert: a pending suggestion surfaced through the P11 inbox,
  asserted only on confirm. (The media-coupled `thing_suggestions`/`/item/:id/suggestions` review
  is generalized for non-media model captures in P16b-2.)
- **Barcode = on-device GTIN/ISBN capture only.** A scan writes the code into a `Product`
  (gtin*) or `Book`/`CreativeWork` (isbn) Thing skeleton; the user/curator fills the rest.
  **No external product/book lookup** (CLAUDE.md §1/§9). An opt-in online/offline-dump lookup
  (OpenFoodFacts / Open Library) is backlogged.
- **Bespoke for the ~6 priority types, generic for the long tail (ADR-0001).** Recipe / Event
  / Place / Article / Product + the three MediaObjects earn **bespoke cards + exporters**; a
  `thingCardFor(type)` dispatcher falls back to the existing generic key/value render
  (`thingDisplayFields`) for the ~1000 other types. **The bespoke catalog is NOT expanded** —
  the long tail is handled by data, not new Dart per type.
- **Exporters are on-device, share-based.** Event → `.ics` (VEVENT), Place → `geo:`/maps deep
  link + share, Recipe/Article → formatted text via `share_plus`, Product → text incl. gtin.
- **Thing-level embedding recall completes typed-node GraphRAG.** A `thing_embedding` Cozo
  relation keyed by `things.id` (built from each Thing's JSON-LD text) makes non-MediaObject
  Things semantically searchable in "Ask your library"; retrieval/hydration already generalize
  (GRAPH-SPEC §10). Generation stays tier-gated exactly as P13d/P14e — incapable devices keep
  the retrieval-only fallback, now over any Thing.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[x]` P16a — Direct-parse (branch a) + unified capture core *(pure Dart; CI)*
Complete the curator's three branches and add the single intake seam everything routes through.
- A pure `direct_parse.dart`: extract JSON-LD / OpenGraph / microdata from HTML (or a metadata
  map) → candidate `ThingDoc`(s), `validateThingDoc` (drop unknown props), stamp
  `grabbitProvenanceBlock(directParse, sourceRef, capturedAt)`. Add the `html` dep (pure-Dart).
- A `CaptureService` / `CaptureRequest` abstraction: route any raw input (fetched HTML, file
  metadata, manual text, barcode payload) → branch (a) when structured, else the P15 `Curator`
  → a `CaptureOutcome` (suggest-don't-assert).
- **Exit / review:** fixture HTML with a JSON-LD `Recipe` → a correct `Recipe` `ThingDoc` with
  no model call; an OG-only page → a generic/`Article` Thing; routing + validation unit-tested.
  *(CI-discharged — no on-device behaviour.)*
- **Status:** shipped — `lib/core/things/capture/`: `direct_parse.dart` (pure `directParse` —
  JSON-LD via `<script type="application/ld+json">` incl. `@graph`/array flattening, `@type`
  string-or-list → most-specific known type, nested `mainEntity`; microdata via
  `itemscope`/`itemprop`; OpenGraph/meta → loose `og:type` map; boundary-validated, container
  types ranked below content, best-first), `capture_service.dart` (the pure ADR-0002 router:
  branch (a) when `html` carries structure → no model, else the P15 `Curator` over `text` →
  `CaptureOutcome{branch, doc, type, confidence, provenance}`; rethrows `unavailable`), and a
  hand-written `capture_service_provider.dart`. Added `html ^0.15.6` (`docs/SPEC.md`). 14 unit
  tests over the real vocab + a fake `generate`. **Persistence + non-media suggestion keying/
  review deferred to P16b** (the media-coupled `thing_suggestions`/`/item/:id/suggestions`).
  Pure-Dart, no codegen — **CI-discharged → `[x]` on merge.**

### `[~]` P16b — Universal "Grab anything" intake surfaces *(UI; APK)*
The visible "add anything" entry — beyond URLs.
- A unified **Grab** action (FAB/sheet) offering: **URL** (existing), **file upload**
  (`file_picker` → media file ⇒ MediaObject leaf path; other file ⇒ `DigitalDocument`/generic
  Thing), **web-article capture** (paste/share a URL → `dart:io` fetch → P16a), **manual entry**
  (typed note/Thing form), **camera/barcode** (scanner — candidate `mobile_scanner`; bundled
  offline ML Kit, de-Googled-clean → GTIN/ISBN into a `Product`/`Book` skeleton, on-device only).
- Each path → `CaptureService`/`CaptureCommitService`; deterministic captures assert directly,
  AI-extracted ones surface via the P15d inbox helper. Camera permission via `permission_handler`.
  Justify new deps in the commit + `docs/SPEC.md`.
- **Split into 4 reviewable PRs (phone-reviewable):**
  - **`[x]` P16b-1 — capture-commit foundation + manual entry + the Grab sheet** *(UI+data; CI)*:
    `CaptureCommitService.commitThing` (the shared assert seam — mints id, upserts, no source edge),
    `buildManualThing` (user-authored `ThingDoc`), the `ManualEntryScreen` (`/grab/manual`: type ·
    name · description · url), the unified `showGrabSheet` (URL + manual rows), and the Dashboard
    **Grab** FAB. No new deps, no migration; manual entry is device-universal (no model). 11 tests.
  - **`[~]` P16b-2 — web-article capture** *(UI+data; APK)*: shipped — paste a URL → `http` fetch
    (`WebPageFetcher` seam) → `CaptureService`: structured markup → direct-parse **asserts directly**;
    markup-less on a capable device → curator → **pending suggestion + review**; low/AI-off → "add
    manually". Generalized the review pipeline for non-media captures: `accept()` writes the
    `isBasedOn` edge only when the source resolves to a Thing (no dangling edge for `cap_*`),
    `postSuggestionNotification` takes an overridable `targetRoute`/`dedupeKey`, and a
    `/capture/:id/suggestions` route reuses the review screen. Added `http`; readable-text extraction
    is a pure-Dart heuristic (no readability package). *APK-owed (batched into the P16 pass).*
  - **`[~]` P16b-3 — file upload** *(UI+data; APK)*: shipped — `file_selector` (Android SAF, no
    permission; chosen over `win32`-conflicting `file_picker`) → a media file is copied into
    app-private storage + inserted as a `MediaItem` (auto-projected to a MediaObject Thing via the
    existing `ThingProjectionService`); any other file is copied in + asserted as a `DigitalDocument`
    Thing via `commitThing`. New `mediaTypeForExtOrNull`, `buildDocumentThing`, `FileImportController`
    (injectable picker), `/grab/file` screen + Grab-sheet row. No Drift migration. *APK-owed.*
  - **`[ ]` P16b-4 — camera/barcode** *(UI+data; APK)*: scanner → GTIN/ISBN → `Product`/`Book`
    skeleton, on-device only.
- **Exit / review:** on a real device each path (file/web/manual/barcode) lands a typed Thing or
  pending suggestion, confirmable via the inbox; ineligible/AI-off degrades to direct-parse/manual.
  *(APK: real intake on device.)*

### `[ ]` P16c — Bespoke priority-type cards + exporters *(UI; APK)*
Make the priority types feel first-class.
- A `thingCardFor(type)` dispatcher → bespoke detail cards for **Recipe/Event/Place/Article/
  Product + MediaObjects** (typed layout over the JSON-LD), falling back to the generic
  `thingDisplayFields` render for the long tail.
- On-device **exporters**: Event → `.ics` (VEVENT), Place → `geo:`/maps deep link + share,
  Recipe/Article → formatted text (`share_plus`), Product → text incl. gtin.
- **Exit / review:** each priority type renders a bespoke card and exports correctly; an unknown
  type still renders generically. *(APK: render/export on device.)*

### `[ ]` P16d — Rich Things Browser *(UI; APK)*
Deepen the P15 v1 into the everything-library's home.
- Add **search** (over promoted `name`/`type`, contains/LIKE) atop the existing `@type` facet
  filter; show **bespoke cards** (P16c) in the list; **relationship-aware navigation** — a Thing
  detail lists its vocabulary + authored edges (`edgesFrom`/`edgesTo` + `NodeHydration`), tap to
  traverse linked Things.
- **Exit / review:** search + filter across a real mixed library; tap-through between linked
  Things; MediaObject Things still route to media detail. *(APK: over a real, mixed library.)*

### `[ ]` P16e — Relationships moat: authored-edge UI + reified relationships *(UI; APK)*
Surface the compounding asset — the links nobody else has (ADR-0004).
- **Authored-edge authoring:** from a Thing, **"Link to…"** → pick another Thing → create a
  `relatedTo` authored edge with a label + optional note (`upsertEdge`, provenance
  `userAuthored`). **Reified relationships:** when the link carries content, promote it to a
  `Comment`/`Note` Thing that `about`s both participants (edge kind 3).
- Reuses `thing_edges`/`things` as-is — **no schema bump**.
- **Exit / review:** author an edge and a reified note across two Things; both persist and appear
  in the browser + graph. *(APK: authoring on device.)*

### `[ ]` P16f — Thing-level embedding index + typed-node GraphRAG over any Thing *(data + engine; APK)*
Make "Ask your library" answer across every Thing type (BACKLOG "From P14e").
- A **`thing_embedding`** Cozo relation keyed by `things.id`, built from each Thing's JSON-LD
  text via `EmbedderEngine` + `GraphSyncService.backfillEmbeddings` (the fingerprint/projection-
  version rebuild — **not** a Drift migration). `RagRetriever` + `NodeHydration` rank and cite
  any Thing; richer Thing-property snippets in the prompt.
- **Exit / review:** a question is answered from a non-media Thing (e.g. an extracted Recipe),
  citing it; generation stays tier-gated with the retrieval-only fallback on incapable devices.
  *(APK: real ask over a real library.)*

### `[ ]` P16g — P16 + Things-Engine band phase close *(docs; APK)*
Close the phase — and the band.
- **Consolidated cross-feature on-device pass** in `docs/VERIFICATION.md`: each intake path →
  typed Thing · bespoke cards + exporters · browser search/filter/relationship-nav · authored +
  reified edges · GraphRAG over non-media Things · graceful gating on an incapable tier.
- Flip the P16 markers per the §7 earned-`[x]` rule; update `docs/ROADMAP.md` /
  `docs/things-engine.md` status (**Things Engine band P14–P16 complete**); route any deferrals
  to `docs/BACKLOG.md`.
- **Exit / review:** the consolidated on-device pass closes P16 and the Things Engine band
  (→ **P17**, the Windows port).

---

## Deferred (out of P16 scope → P17+ / BACKLOG)
- **Opt-in barcode → product/book lookup** (online API and/or a bundled **OpenFoodFacts** data
  dump as an optional on-device offline dataset; **Open Library** for ISBNs) → BACKLOG, revisit
  post-band; must preserve the no-cloud/no-telemetry posture. *(From P16b.)*
- **Things FTS5 index** (full-text over Thing properties) → BACKLOG; add only if promoted-column
  name-search proves insufficient. *(From P16d.)*
- **Expanded bespoke-type catalog** beyond the ~6 priority types → not pursued (ADR-0001: the
  long tail is data + the generic render, not per-type Dart).
- **Physical `media_items`→`things` merge** stays the deferred open question (ADR-0003, BACKLOG).
