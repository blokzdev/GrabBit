# P14 — Things foundation + MediaObject projection: subphase plan

> The sub-roadmap for **P14** (see `docs/ROADMAP.md` and the vision one-pager `docs/things-engine.md`).
> P14 is the **first phase of the Things Engine band (P14–P16)** — the spine that turns GrabBit from a media
> store into an on-device **"everything library."** It stands up a generic store of typed **schema.org
> Things** (JSON-LD + promoted columns, in the `things` table seeded empty in P12f), **projects every existing
> download into it as a `MediaObject` Thing** (ADR-0003), lays the **relationships + provenance** plumbing
> (ADR-0004), and makes the Cozo graph + the "Ask your library" GraphRAG **resolve and cite Things**
> (GRAPH-SPEC §10). P14 is **device-universal** — the Things *floor* (store, projection, edges, graph) runs on
> every device; the AI **curator** that creates richer Things is **P15**. It is deliberately **under-the-hood**:
> media still shows as media (a `MediaObject` is just its Thing projection), with only a small **diagnostic**
> surface for verifiability — the rich Things Browser/UX lands in **P15/P16**. Deep contracts:
> `docs/decisions/` (ADR-0001 schema-as-data · ADR-0003 MediaObject bridge · ADR-0004 relationships/provenance),
> `docs/AI-SPEC.md` §2/§5–6, `docs/GRAPH-SPEC.md` §10.

## How subphases work
- **One branch + one PR per subphase**, cut fresh from latest `main`, named `claude/p14<sub>-<topic>`. Each
  keeps CI green (`dart format` · `flutter analyze` · `flutter test`), runs `build_runner` if codegen
  (drift/riverpod/freezed/json) changed, and updates `docs/VERIFICATION.md` for new user-facing/on-device
  behaviour.
- **Each subphase gets its own plan** (plan → approve → execute, CLAUDE.md §7). This doc is the **map**: it
  locks the decomposition + phase-level decisions; per-subphase design happens at that subphase's start.
- **One schema migration:** the only DB change lands once in **P14d** — **v14→v15**, the `thing_edges` table
  (durable authored edges). The `things` table is **reused as-is** (its promoted set is unchanged); do not
  bump the schema elsewhere in the phase.
- **On-device review:** APK builds are **manual / user-triggered** (CLAUDE.md §6). **P14a, P14b, P14d** are
  pure-Dart/Drift and ship as standalone green-CI PRs; the subphases that touch the real library, the native
  graph, or UI — **P14c** (projection backfill), **P14e** (Cozo/GraphRAG over Things), **P14f** (diagnostic) —
  need APK spot-checks and are **batched** into the P14 consolidated on-device pass.
- **Build on existing seams, don't fork them** (GRAPH-SPEC §10): the Drift→Cozo projection
  (`buildGraphRelations`, `lib/core/graph/graph_projection.dart`), the idempotent rebuild/backfill discipline
  (`GraphSyncService.rebuild`/`backfillEmbeddings`), `GraphQueryService` + the node-type-blind algorithms
  (`path_finding`/`community_clustering`/`centrality`), the GraphRAG retriever (`rag_retriever.dart`) and its
  `MetadataRepository` hydration seam, and the migration/backfill patterns in `database.dart`.
- **PR cadence:** open the PR into `main` at each subphase boundary (per CLAUDE.md §7).

## Design decisions (set at planning time)
- **Materialized projection, not on-read.** ADR-0003 leaves the mechanism open; P14 **materializes**
  `MediaObject` Thing rows into `things` via a **rebuildable, idempotent backfill** (the proven
  `backfillEmbeddings`/FTS-backfill shape) — a uniform query surface, with the media tables staying
  **canonical** and Things **derived**. On-read view is the considered alternative, deferred.
- **Device-universal, no AI gating.** The store, projection, vocabulary edges, and graph are the Things
  *floor* and run on every device (`docs/things-engine.md`). The AI **curator** is P15. GraphRAG
  **generation** stays tier-gated exactly as P13d shipped it; **P14e only makes its *hydration* Thing-aware**,
  so an incapable device still gets the retrieval-only fallback — now over Things.
- **Logical spine, not a physical merge.** `things.id` is kept **alignable to `media_items.id`** (no FK); the
  media tables remain the canonical file-backed substrate that `MediaObject` Things reference/derive from. The
  full physical `media_items`→`things` merge stays a **deferred open question** (`docs/BACKLOG.md`, ADR-0003).
- **Schema-as-data, validated at the boundary** (ADR-0001). Things are canonical **JSON-LD**; `name`/`url` are
  a re-derivable **promoted cache** (on conflict the JSON-LD wins). The schema.org vocabulary ships as a
  **read-only, versioned asset** for validation/grounding/rendering — never transcribed into Dart classes.
  Property access is dynamic; validation happens on write/import (CLAUDE.md §8).
- **Suggest-don't-assert, from day one** (ADR-0004). Deterministic Things (the `MediaObject` projection) and
  **vocabulary edges** auto-apply; the **authored-edge store** carries `provenance`/`confidence` so P15's
  AI-inferred edges can be gated through the **P11 Activity Inbox** later. **P14 builds the store + derivation,
  not the authoring/AI** — no edge-authoring UI, no curator.

## Status legend
`[ ]` not started · `[~]` in progress · `[x]` done & verified on-device

---

### `[x]` P14a — Schema.org vocabulary asset + Thing/JSON-LD core *(pure Dart; CI)*
The schema-as-data foundation every later subphase builds on (ADR-0001).
- Vendor the **schema.org vocabulary** (JSON-LD context + type/property definitions) as a **read-only,
  versioned app asset**, with a pure-Dart loader (parse once, cache).
- A pure **Thing/JSON-LD helper** layer: parse/serialize a Thing document, read `@type` + properties
  dynamically, **derive the promoted columns** (`name`, `url`) from the doc, and **validate at the boundary**
  against the asset (is the `@type` known; are these properties defined). No Drift, no UI.
- **Exit / review:** a JSON-LD Thing round-trips; promoted-column derivation + boundary validation behave on
  known and unknown `@type`s; covered by unit tests. *(CI-discharged — no on-device behaviour.)*
- **Status:** implemented (CI-green). Vendored the full **schema.org v30.0** `schemaorg-current-https.jsonld`
  (~1.5 MB) at `assets/vocab/` (+ pinned README, pubspec asset, CC BY-SA 3.0 notice). New `lib/core/things/`:
  `thing_doc.dart` (`ThingDoc` JSON-LD value type + `schemaLocalName`), `schema_org_vocabulary.dart` (pure
  `SchemaOrgVocabulary.parse` → class/subClassOf + domain index; `isKnownType`/`propertiesFor`(inherited)/
  `isDefined`; drops raw JSON after indexing), `thing_validation.dart` (advisory `validateThingDoc`, tolerant
  of `@`-keywords + `grabbit:`), `schema_org_vocabulary_provider.dart` (lazy `FutureProvider`). Tests: vocab
  query (fixture), `ThingDoc` parse/derive, validation truth table, + a real-asset smoke test (loads via
  `rootBundle` in CI; asserts ~1000 types incl. Recipe/VideoObject/Event/Place + inherited props). No
  schema/Drift change; no `build_runner`. **CI-discharged → `[x]` on merge** (the asset loads the same way in
  CI as on-device).

### `[x]` P14b — `ThingRepository` + promoted-column discipline *(Drift; CI)*
The canonical store API over the existing `things` table.
- `ThingRepository(_db)` mirroring `MetadataRepository`: `upsertThing` (write JSON-LD canonical → re-derive
  `name`/`url` on write — ADR-0001), `thingById`, `watchThingsByType`, `countThings`/`watchThingCount`,
  `deleteThing`; a **rebuildable, idempotent promoted-column backfill** `refreshPromotedColumns` (re-derive
  from `jsonld`, same shape as the FTS/dimension backfills). Hand-written `thingRepositoryProvider` (Drift row
  types throw `InvalidTypeException` under codegen — CLAUDE.md §8).
- **Reuses the `things` table as-is** (`id/type/jsonld/name?/url?/createdAt/updatedAt`) — **no schema bump.**
- **Exit / review:** upsert/read/watch/delete + backfill round-trip; promoted columns always reflect `jsonld`;
  unit tests. *(CI.)*
- **Status:** done — `lib/core/things/thing_repository.dart` + `test/core/things/thing_repository_test.dart`.
  `createdAt` is preserved across upserts via the codebase's explicit read-then-write (no `DoUpdate`); the repo
  is store-only (validation stays the writer's job). Pure-Dart/Drift, no `build_runner` —
  **CI-discharged → `[x]` on merge.**

### `[~]` P14c — MediaObject projection + rebuildable backfill + sync hook *(projection pure-Dart CI; backfill APK)*
Every existing (and future) download becomes a typed `MediaObject` Thing — the bridge that makes the library a
Thing graph (ADR-0003).
- A **pure, deterministic projection** `(MediaItem + MediaMetadata) → Audio/Image/VideoObject` JSON-LD,
  field-by-field (e.g. `title→name`, `sourceUrl→url`, `filePath→contentUrl`, `durationSec→duration`,
  `transcript→transcript`, `uploader→author`, `playlist→isPartOf`, dims/size/thumb), stamped with a
  `grabbit:` provenance block `direct-parse`.
- A **rebuildable, idempotent backfill** (diff like `backfillEmbeddings`) that writes/updates `MediaObject`
  Things keyed by `media_items.id`, plus a **sync hook** so new downloads project automatically (extend
  `GraphSyncService`'s table-update listener, or a sibling `ThingSyncService`).
- **Exit / review:** every media item has an up-to-date `MediaObject` Thing; rebuild is idempotent (no dupes,
  prunes deleted); a new download projects on completion; APK spot-check over a real library, offline. *(APK.)*
- **Status:** shipped — `lib/core/things/media_object_projection.dart` (pure projection + `iso8601Duration`)
  + `lib/core/things/thing_projection_service.dart` (diffed backfill + pruning + debounced `tableUpdates`
  listener, the **sibling-service** option), wired non-blocking in `app.dart`. The jsonld-equality diff means
  **no fingerprint/settings field** (it re-derives on data *or* projection-logic change). Tests cover the
  field-by-field mapping, determinism, schema validity against the **real** vendored vocabulary, and
  backfill/idempotence/update/prune. **CI green; the real-library backfill/sync APK spot-check is batched into
  the P14 consolidated on-device pass — stays `[~]` until then** (CLAUDE.md §7).

### `[x]` P14d — Relationships & provenance foundation *(Drift + pure Dart; CI; the one schema bump)*
The durable plumbing for the three edge kinds + provenance (ADR-0004) — store + derivation only, no authoring.
- The **`grabbit:` provenance block** convention inside a Thing's JSON-LD (`provenance` ∈ {`direct-parse`,
  `single-tool`, `narrowed-set`, `user-authored`, `ai-suggested`, `ai-inferred`, `vector-similarity`},
  `sourceRef`, `modelId?`, `confidence?`, `capturedAt`).
- **Vocabulary-edge derivation** (pure, deterministic, rebuildable): object-valued JSON-LD properties →
  Thing→Thing edges (e.g. `MediaObject`→author `Person`, →`isPartOf` playlist) — auto-projected, the same way
  media→entity edges are built today.
- A durable **authored-edge store** — a new **`thing_edges`** Drift table (`subject`, `predicate`/label,
  `object`, `provenance`, `confidence?`, `note?`, `createdAt`) for the loosely-typed `relatedTo` edges a user
  *or* the AI may assert (ADR-0004 kind 2). **The one P14 schema bump (v14→v15)** + a migration test. **No
  authoring UI** (P15+); reified relationships (kind 3) deferred.
- **Exit / review:** provenance round-trips in JSON-LD; vocabulary edges derive deterministically; `thing_edges`
  CRUD + the **v14→v15 upgrade** are tested. *(CI.)*
- **Status:** shipped — `provenance.dart` (the `grabbit:provenance` block + `Provenance` enum, now adopted by
  the MediaObject projection with a deterministic `capturedAt`), `vocabulary_edges.dart`
  (`deriveVocabularyEdges` — structural `@id`-reference detection, since the vocab indexes `domainIncludes`,
  not `rangeIncludes`), the `ThingEdges` Drift table + `thing_edge_repository.dart`, and the **v14→v15**
  migration. Composite PK `{subject,predicate,object}`; **no FK** (mirrors `things.id`, ADR-0003 — edges
  outlive a rebuilt Thing). Pure-Dart/Drift, migration covered by an upgrade test (v13→v14 precedent) →
  **CI-discharged → `[x]` on merge.**

### `[~]` P14e — Cozo Thing projection + Thing-aware hydration → graph & GraphRAG over Things *(graph; APK)*
Make the on-device graph + "Ask your library" operate over Things, reusing the GRAPH-SPEC §10 seams.
- **Edge production (seam 1):** extend the Cozo projection (`graph_projection.dart`/`cozo_schema.dart`) to emit
  **Thing nodes + Thing→Thing edges** (vocabulary + authored) keyed by `things.id`. Node ids are already
  opaque strings, so `path_finding`/`community_clustering`/`centrality` and the query service run **unchanged**.
- **Hydration (seam 2 + guardrail):** a `ThingRepository`-backed **hydration seam** (`thingById` + provider)
  that the GraphRAG retriever (`rag_retriever.dart`) and the graph-view/related/path providers resolve through
  — so "Ask your library" **cites Things** (MediaObject today), not bare media rows. Relation-label styling
  (seam 3) already degrades gracefully for unknown relations — no UI rewrite.
- **Exit / review:** on a capable device, graph features + "Ask your library" resolve/cite `MediaObject`
  Things; **no regression** to related/neighborhood/path/RAG; low/ineligible tiers keep the retrieval-only
  fallback (now over Things). APK spot-check. *(APK.)*
- **Status:** shipped — projection emits `thing`/`thingVocabEdge`/`thingAuthoredEdge` (`graph_projection.dart`
  + `cozo_schema.dart`), `GraphStats`+self-test/rebuild report thing counts, `_edgeBuilderVersion`→4 (startup
  self-heal). New **`thing_hydration.dart`** seam (`hydrateNodes` → `HydratedNode{id,title,type,media}`); the
  RAG retriever cites Things (`RagSource.type`, `[n] title (type)`) and the path/rediscover/albums providers
  resolve through it (media rendering unchanged). **Reuses existing media vectors — no re-embedding** (locked);
  the separate Thing-embedding index is deferred to P15/P16 (BACKLOG + AI-SPEC). CI green (pure projection +
  fake-store rebuild + seam + retriever); **live Cozo/RAG APK check batched into the P14 close → stays `[~]`.**

### `[ ]` P14f — Diagnostic surface + P14 phase close *(UI-light + docs; APK)*
A thin, verifiable window into the new layer, then close the phase.
- A small **diagnostic** (maintainer call — *not* a Thing browser): a Labs/Advanced **"View as Thing
  (JSON-LD)"** action on item detail (shows a media item's projected `MediaObject` + its `grabbit:`
  provenance) + a **Things count** in AI settings.
- **Phase close:** add `docs/VERIFICATION.md` rows + a **"P14 — consolidated cross-feature on-device pass"**
  (projection over a real library · graph/RAG cite Things · provenance present · diagnostic renders); flip the
  P14 markers per the §7 earned-`[x]` rule; update the ROADMAP/`things-engine.md` status; route any deferrals
  to `docs/BACKLOG.md`.
- **Exit / review:** the diagnostic shows a media item's `MediaObject` JSON-LD + provenance; the consolidated
  on-device pass closes P14 (→ P15, the curator).

---

## Deferred (out of P14 scope → P15 / P16 / BACKLOG)
- **Narrow-then-fill curator + AI Thing-extraction from downloads** (ADR-0002) → **P15** (a cooking video → a
  `Recipe`); activates the real `generateStructured` + the FunctionGemma-vs-Qwen3 license fork.
- **The rich Things Browser** (browse/filter by `@type`, bespoke type cards/exporters, generic key/value view
  for the long tail) → **P15 (v1) → P16 (full)**. P14 ships only the diagnostic.
- **Universal "Grab anything" intake** (file/web-article/manual/camera/barcode) → **P16**.
- **Authored-edge authoring UI** + **P11 Activity Inbox review** of AI-inferred Things/edges → **P15** (P14
  builds the store + provenance that make this gateable).
- **Reified relationships** (kind 3 — a relationship promoted to a `Comment`/`Note`/`Role` Thing) → P15/P16.
- **Full physical spine** (absorbing `media_items`/`media_metadata` into `things`) → **BACKLOG** (ADR-0003) —
  real file-lifecycle migration weight, unscheduled; the id-space stays alignable so the choice stays open.
