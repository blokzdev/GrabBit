# GrabBit — On-Device Graph & Vector DB Spec (CozoDB)

Status: Draft v0.1 · Last updated: 2026-05-24

> Implementation-level source of truth for GrabBit's **on-device data graph and vector index**.
> Captures the engine choice, license analysis, integration approach, schema, sync model, and the
> graph-algorithm → feature map so the research/decision record survives a context or session loss.
> Pairs with `docs/AI-SPEC.md` (which produces the embeddings this layer indexes) and is referenced
> by `docs/design/P-AI-PLAN.md` (the delivery sub-roadmap). Lands in **P10**.

---

## 1. Why a graph DB, and why Cozo

The library already has rich relational signals (uploader/channel, playlist, site, tags,
collections, folders, content hash, download time). Flat SQL filters expose them one facet at a
time; a **graph** lets us traverse and rank across them — "related items", entity hubs, clustered
albums, path/bridge discovery, centrality-based rediscovery — and unifies them with **semantic
similarity** from embeddings. This is a first-class product pillar, not a viz afterthought.

**Engine: [CozoDB](https://www.cozodb.org/)** — a single embeddable Rust engine that is
**relational + graph + vector** in one: Datalog/CozoScript queries, built-in graph algorithms
(PageRank, centrality, shortest-path, community detection), an **HNSW vector index**, full-text
search, **MinHash-LSH** near-duplicate search, and time-travel. One bundled native dependency
therefore serves **both** the relationship graph **and** the AI embeddings vector index.

**Pinned version: `0.7.2`** (released 2025-06-01). Cozo is **stable / feature-complete** — its slow
release cadence reflects maturity, not abandonment. We pin the version and keep everything behind an
interface so a future swap is a single-impl change.

**Alternatives considered & rejected:** ObjectBox (Dart-native + HNSW, but relations-not-graph — no
Datalog/graph algorithms); Kùzu/RyuGraph (powerful Cypher engine, but upstream archived Oct 2025 and
no proven mobile build); Drift + `sqlite-vec` (single engine, but graph algorithms are DIY SQL — not
a "robust graph DB"). Cozo is the only option that is genuinely graph+vector+relational **and**
ships an embeddable, mobile-ready build.

### License (MPL-2.0)

Cozo is **MPL-2.0** — *file-level* copyleft on Cozo's **own source files** only. We **link/bundle**
Cozo, we do not modify its sources, so MPL places **no obligation on GrabBit's own code** and nothing
on our distribution. Free to bundle and ship in a closed-source, off-store app. (If we ever patched a
Cozo source file, only that file's changes would need publishing — we don't plan to.)

---

## 2. Integration — Android (v1) via official AAR + Pigeon; Windows (v2) via C-API/FFI

This is the existing `DownloadEngine` dual-impl pattern (native lib on Android, process/FFI on
Windows). It removes almost all of the "FFI cost" for v1 (which is *engineering time*, never money).

### 2.1 Android (P10, primary) — Maven AAR + Pigeon→Kotlin bridge

Cozo publishes an **official prebuilt Android library on Maven Central**:
**`io.github.cozodb:cozo_android:0.7.2`** — an AAR that bundles the native `.so`s per ABI and exposes
the JVM/Kotlin API (JNI). We consume it through a **Pigeon→Kotlin bridge**, mirroring exactly how
`io.github.junkfood02.youtubedl-android` is wired today (`YtDlpHostApi` in `pigeons/engine.dart` →
Kotlin host). Implications:

- **No NDK cross-compile, no committed `.so`s, no `dart:ffi`, no persistent-isolate handle for v1.**
- A new Pigeon contract (`pigeons/cozo.dart` → `CozoHostApi`, methods `openDb`/`runScript`/`closeDb`)
  marshals **CozoScript + params-JSON in → result-JSON out** (strings only — no DTOs, no `@FlutterApi`,
  since Cozo is request/response). Queries run on a **Kotlin background dispatcher**
  (`Dispatchers.IO`), off the platform thread.
- Kotlin host (`CozoHost.kt`): the class is **`org.cozodb.CozoDb`**; open with
  `CozoDb("sqlite", path, "")`, query with **`db.query(script, paramsJson)`** (returns a JSON string;
  errors carry `"ok": false`), release with `db.close()`.
- **Graceful degradation (key):** the AAR bundles native `.so` for **`arm64-v8a` + `x86` only** (not
  `armeabi-v7a`/`x86_64`). Rather than a global `abiFilters` (which would also cut the *downloader's*
  reach via youtubedl), `CozoHost.openDb` catches `UnsatisfiedLinkError`/`NoClassDefFoundError` and
  reports **unavailable** → the Dart `GraphStore.isAvailable` is false → graph features gate off with
  a friendly reason; the download/manager core is untouched. Cozo loads normally on `arm64-v8a` (all
  modern phones incl. the test S20).
- **CI is unaffected** — the lean Ubuntu `ci.yml` just resolves a Maven dependency; no Rust/NDK
  toolchain runs. (APK builds remain the manual `build-apk.yml`.)

### 2.2 Windows (P14) — C-API via `dart:ffi`

Native-build/obtain `cozo_c.dll`; bind via `dart:ffi` with **`ffigen`** over the tiny `cozo_c.h`
(`cozo_open_db`, `cozo_run_query(script, params_json) → JSON`, `cozo_close_db`,
import/export/backup, `cozo_free_str`). Free the returned C string with `cozo_free_str` in
try/finally. Own the `DynamicLibrary` + DB handle on a **dedicated long-lived background isolate**
(`DynamicLibrary`/pointers aren't transferable across isolates — confirmed Flutter issue #169431;
use `RawReceivePort`/`SendPort` + `NativeFinalizer`). Prefer the Flutter **native-assets build hook**
(`hook/build.dart`, stable since 3.38) to bundle the prebuilt `.dll`. *(Deferred to v2; v1 ships
Android-only via the AAR.)*

### 2.3 Storage backend & file location

Open Cozo with the **SQLite backend** — single persistent file, modest binary size (we already ship
`sqlite3`), trivial backup/delete-to-rebuild. **Not** RocksDB (≈doubles native size; compaction/file
handles are a mobile liability), **not** `mem` (loses the index on process death). Persist via
`path_provider` `getApplicationSupportDirectory()` → `<support>/graph/cozo.db` — app-private, **kept
out of the documents/media dirs** so it never leaks into any library export/backup.

---

## 3. Architectural model — Drift canonical, Cozo derived & rebuildable

**Drift (SQLite, schema v4) stays the single source of truth** for the library. **Cozo is a derived
index** (graph nodes/edges + embedding vectors) keyed by `MediaItems.id`, **rebuildable from Drift at
any time**. Rules:

- **No user-visible mutation ever lands in Cozo only.** Favorites, tags, folders, collections, etc.
  write to Drift first; Cozo updates as a follow-on **projection**.
- A corrupt/stale/version-mismatched Cozo file is **never a data-loss event** — delete and rebuild.
- This keeps Cozo fully **swappable** (CLAUDE.md §3) and keeps the whole feature in the
  **on-device = free** band.

**Schema fingerprint (self-healing).** Persist `cozo_index_version` (the
`GraphSyncService.fingerprint`, now `"<drift schemaVersion>.<edgeBuilderVer>.<embedderModelId>"`) in
the settings blob. On startup, if the fingerprint differs (a migration, projection change, or model
upgrade), rebuild + re-stamp. **If the fingerprint matches, `syncIfStale` still cross-checks the Drift
vs. Cozo `media` count and rebuilds on divergence** (catches a prior partial/failed sync). Separately,
the embedder's **model + dimension** are recorded in an `embedding_meta` sidecar; the embedding
relation is dropped + recreated whenever they change, so a model swap can't leave a stale-dimension
HNSW index (P10b-3).

---

## 4. `GraphStore` interface & placement

New `lib/core/graph/` (mirrors `lib/core/engine/`):

```dart
// lib/core/graph/graph_store.dart — pure-Dart, no AI imports
abstract interface class GraphStore {
  Future<void> open();
  Future<void> close();
  Future<Map<String, Object?>> runScript(String script, Map<String, Object?> params);

  // typed convenience (built on runScript)
  Future<List<String>> relatedTo(String id, {int limit = 20});      // hybrid vector + graph
  Future<List<double>> /*scores*/ vectorSearch(List<double> v, int k);
  Future<EntityHub> entityHub(EntityRef ref);
  Future<List<List<String>>> nearDuplicates(String id);
  Future<int?> communityOf(String id);

  // sync / projection
  Future<void> upsertNode(GraphNode n);
  Future<void> upsertEdge(GraphEdge e);
  Future<void> upsertEmbedding(String id, List<double> vector);
  Future<void> removeItem(String id);
  Future<void> rebuildAll();
}
```

> **Realized design (P10a–P10c):** the shipped `GraphStore` stays **thin** — only
> `open / isAvailable / runScript / ensureSchema / close`. The typed reads/writes sketched above do
> **not** live on the store; orchestration sits in services that depend on the interface (never a
> concrete engine): `GraphSyncService` owns writes/projection/embedding-backfill, and **`GraphQueryService`**
> (P10c, `lib/core/graph/graph_query_service.dart`) owns reads (`vectorSearch`, and later `relatedTo`,
> tag co-occurrence, and `similarityClusters` for near-dup/Suggested albums) over `runScript`, with pure CozoScript builders in `cozo_query.dart`. This
> keeps query shapes unit-testable without the native engine.

- `lib/core/graph/android_cozo_graph_store.dart` — Android impl over the `CozoHostApi` Pigeon bridge
  (v1). A future `windows_cozo_graph_store.dart` (FFI/ffigen) slots behind the same interface (P14).
- `lib/core/graph/graph_store_provider.dart` — `@Riverpod(keepAlive: true)`, platform-branched like
  the existing `engine_provider.dart`; a no-op impl keeps callers safe where unsupported.
- `pigeons/cozo.dart` → `CozoHostApi` + Kotlin host glue, mirroring `pigeons/engine.dart` /
  `YtDlpHost.kt`.

**Separation from `InferenceEngine` (`lib/core/ai/`, see `AI-SPEC.md`):** `InferenceEngine.embed(text)
→ vector` **produces** vectors; `GraphStore` **stores/searches** them. `GraphStore` must not import
the AI layer (and vice versa). Only `GraphSyncService` touches both — this is what lets P10's
deterministic + similarity graph ship independent of the LLM stack, and keeps both engines swappable.

---

## 5. Cozo schema

**Node relations** (CozoScript `:create`):
- `media {id => title, site, type, createdAt, isFavorite, contentHash?, filePath}`
- `uploader {uploaderId => name, channelId?}`, `site {site =>}`, `playlist {playlistId => title}`,
  `tag {name =>}`, `collection {collectionId => name}`, `folder {folderId => name, parentId?}`

**Typed edge relations** (each its own relation, `{from, to => weight?, …}`):
- `postedBy(media → uploader)`, `onPlatform(media → site)`, `inPlaylist(media → playlist)`,
  `taggedWith(media → tag)`, `inCollection(media → collection)`, `inFolder(media → folder)`,
  `folderParent(folder → folder)`
- `duplicateOf(media ↔ media)` — identical `contentHash`
- `coDownloadedWith(media ↔ media => gapSec)` — `createdAt` temporal proximity
- `similarTo(media ↔ media => score)` — materialized from vector search (lags until embeddings exist)

**Vector index (P10b-2b):** HNSW relation `embedding {id => v: <F32; DIM>, textHash}` with
`::hnsw create embedding:idx {dim, dtype:F32, fields:[v], distance:Cosine, …}`. **DIM = 768**
(Gecko 64 / EmbeddingGemma family). `textHash = sha256(modelId + docText)` is the **cache key** — an
unchanged hash skips re-embedding, and a model change re-keys every hash (so vectors never mix
spaces). The relation is **created on demand by `GraphSyncService.backfillEmbeddings()`** (which knows
DIM via the embedder), **not** by the dim-agnostic `GraphStore.ensureSchema`, and is deliberately
**excluded from `graphSchema`** so the deterministic `:replace` rebuild never wipes it. Query-time
vector search (`~embedding:idx`) is **live in P10c-a** via `GraphQueryService.vectorSearch` (powers
semantic library search); `similarTo` materialization follows in later P10c subphases.

**Signal reliability (from the codebase data map)** — build edges only on real signals:

| Signal | Source | Reliability |
|---|---|---|
| `site` (platform) | `media_items.site` | **always present** |
| `createdAt` (co-download) | `media_items.created_at` | **always present** |
| `isFavorite`, `folderId` | `media_items` | user-set |
| collections, tags | junction tables | user-set, sparse |
| `contentHash` (duplicate) | `media_items` | lazy-filled by `DedupeService` |
| uploader / `uploaderId` / `channelId` | `media_metadata` | often present, can be null |
| `playlistId` | `media_metadata` | only if downloaded from a playlist |
| `tags` (extracted) | `media_metadata` | sparse |
| `description` | `media_metadata` | usually present — **best embedding text** |
| similarity (`similarTo`) | embeddings | once the embedder runs |

---

## 6. Sync model — `GraphSyncService` (P10b-1)

Single owner in `lib/core/graph/graph_sync_service.dart` (`AppDatabase` + `GraphStore`). No-ops
gracefully when `GraphStore.isAvailable` is false.

- **Pure projection.** `graph_projection.dart` turns a `LibrarySnapshot` (plain Drift rows) into
  `relation → rows` in each relation's column order (`graphRelationColumns`). Pure → unit-tested.
- **Idempotent rebuild via `:replace`.** For each relation, run
  `?[cols] <- $rows :replace rel {schema}` with the current Drift-derived rows. `:replace` recreates
  the relation's contents, so one rebuild reflects adds, edits **and** deletes; an empty library →
  empty relations. (Confirmed Cozo semantics.) Used by startup self-heal, the live listener, and the
  manual action.
- **Stay current via a debounced Drift-update listener — no repo coupling.** Subscribe to
  `db.tableUpdates(TableUpdateQuery.onAllTables([mediaItems, mediaMetadata, folders, tags, mediaTags,
  collections, mediaCollections]))`, debounce (~2 s), then rebuild. Drift's own update stream is the
  event bus, so no hooks are scattered across the 11 repo mutation sites. Cozo writes hit a separate
  DB, so they don't re-trigger this (no loop).
- **Startup schema-fingerprint self-heal.**
  `fingerprint = "<drift schemaVersion>.<edgeBuilderVer>.<embedderModelId>"` persisted as
  `settings.graphIndexVersion`. On launch (`app.dart` `_maybeSyncGraph`, mirroring `_maybeAutoUpdate`),
  rebuild + stamp iff it changed; if unchanged, also rebuild on a Drift↔Cozo `media` count divergence
  (P10b-3) — handles logic/schema/model changes *and* a prior partial sync the data-listener wouldn't
  catch.
- **Store lifecycle (P10b-3).** The Cozo store is released on app background/detach
  (`GraphSyncService.releaseStore()` from `app.dart`'s `didChangeAppLifecycleState`) to free the SQLite
  handle/lock, and reopens lazily on the next graph touch via `_ensureOpen`.
- **Manual "Rebuild graph index"** (Settings → Graph database) + the About self-test reports
  `media · edges · embeddings` counts.
- **P10b-1 scope:** deterministic nodes + entity/structural edges. **`duplicateOf`** (identical
  `contentHash`) and **`coDownloadedWith`** (consecutive `createdAt` within a 5-min window) are now
  projected deterministically (P10b-3); `similarTo` (vector-derived) remains for P10c.
- **P10b-2b (done):** `backfillEmbeddings()` maintains the HNSW `embedding` relation **incrementally
  and cached** — it diffs the desired `id → textHash` (from `buildEmbeddingDocs`) against the stored
  cache, `:put`s only new/changed items (in chunks), and `:rm`s ids no longer in the library. It's
  gated on `InferenceEngine.ensureReady()` (a cheap no-op when semantic search is off / the model
  isn't downloaded / a non-arm64 host), so it never `:replace`s the relation wholesale and never
  re-embeds unchanged items. Triggered after the deterministic rebuild (live listener), at startup
  (`app.dart`), and on opt-in (Settings toggle / AI-setup). The self-test reports the embedding count.

---

## 7. Graph algorithm → feature map

| Feature (phase) | Cozo mechanism |
|---|---|
| **Related / "More like this"** (P10c-b, **live**) | `GraphQueryService.relatedTo`: HNSW vector search over the item's *own* stored vector + a pure-Datalog neighbour query (shared uploader/playlist/tag/co-download), blended & ranked in Dart (`related_ranking.dart`). Graph-only when the item isn't embedded; excludes `duplicateOf` partners. Also the retrieval half of P12 GraphRAG. |
| **Entity hubs** (P10c-c, **live**) | **c-1 (every device):** navigable hubs — uploader/playlist/tag/site on item-detail are tappable → an `EntityHubScreen` listing that entity's items via Drift `watchFiltered` (no graph). **c-2 (graph):** a **"Related tags"** strip on each hub — `GraphQueryService.relatedTags` collects the tags carried by the entity's items (uploader-name bridged to `uploaderId` via the `uploader` node) and ranks by support; chips open the tag hub. Degenerates to nothing when the graph is unavailable. |
| **Proactive grouping** (P10c-d) | **d-1 (live, every device):** a distinct **Duplicates** auto-album in Collections→Albums (exact-hash `duplicateOf`), with bulk **Clean up** (keep oldest) + **Review** → the cleanup screen. **d-2 (graph, live):** **Suggested** similarity albums — query-time vector clusters (pairwise cosine + connected components in `near_duplicate_clustering.dart`, exact pairs excluded) with one-tap **Save as collection**. The richer community-detection / label-propagation auto-albums + "Rediscover" stay **P12** (below). |
| **Tag suggestions** (P10c-c-2, **live**) | `GraphQueryService.coOccurringTags`: tags on items sharing a deterministic signal with this one (`postedBy`/`inPlaylist`/`taggedWith`/`coDownloadedWith`), minus the item's own tags, ranked in Dart (`cooccurrence_ranking.dart`) by distinct supporting items. Surfaced as tappable chips in the metadata editor. Pure Datalog — every device. |
| **Interactive graph viz** (P10c-e/f) | **e (render, live):** `GraphQueryService.neighborhood(id)` (an item's direct entity + duplicate/co-download edges) → a force-directed `graphview` render with pan/zoom + a type legend, reached via item-detail "View in graph". Deterministic edges — no embedder. **f (live):** tap a media node → its item, tap an entity node → expand its media (and long-press → open hub), edge-type **legend filters**, expansion capped (`:limit`). |
| **Graph-clustered auto-albums** (P12) | **community detection / label propagation** over the similarity + entity graph. |
| **Centrality "Rediscover"** (P12) | `PageRank` / betweenness × `lastAccessedAt` to resurface central-but-stale items. |
| **Path / bridge discovery** (P12) | shortest-path / connectivity between two items or entities. |
| **Local GraphRAG "Ask your library"** (P12) | hybrid retrieval (vector + graph re-rank) feeds the on-device LLM (see `AI-SPEC.md`). |

---

## 8. Risks & mitigations

- **Upstream cadence slowed** → pin `cozo_android:0.7.2`; keep everything behind `GraphStore` with a
  **conformance-test suite** so a replacement (ObjectBox+graph lib, sqlite-vec, etc.) is provable and
  one-impl.
- **APK size** → SQLite backend + `abiFilters` / `--split-per-abi`; **measure in the first APK
  build** and budget.
- **Real-device behavior** → Cozo opens & persists across restarts under the AAR; **`releaseStore()`
  closes it on app background (P10b-3)** to avoid SQLite locks, reopening lazily. → explicit
  `docs/VERIFICATION.md` items.
- **Index/Drift drift** → schema-fingerprint check **+ a Drift↔Cozo `media` count-divergence rebuild
  (P10b-3)** (§3).
- **Malformed engine output** → `runScript` guards the JSON decode and surfaces
  `GraphErrorCode.queryFailed` instead of crashing (P10b-3).

## 9. `GraphStore` conformance-test outline

A backend-agnostic test suite (run against the Cozo impl now, any future impl later): open/close
idempotency; upsert node/edge/embedding then read back; `removeItem` cascades edges; `vectorSearch`
returns nearest by cosine; `relatedTo` blends vector + graph; `rebuildAll` from a fixture Drift set
reproduces a deterministic node/edge count; replay/idempotency (running sync twice converges).
