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
- A new Pigeon contract (`pigeons/cozo.dart` → `CozoHostApi`) marshals **CozoScript + params-JSON in
  → result-JSON out**. Queries run on a **Kotlin background dispatcher** (off the platform thread);
  heavy HNSW/PageRank/community-detection work never blocks the UI.
- Gradle: add the Maven dep and set `abiFilters` (e.g. `arm64-v8a`, `x86_64`); offer
  `--split-per-abi` for sideload. Pin the version.
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

**Schema fingerprint (self-healing).** Persist `cozo_index_version = hash(Drift schema v +
embedding-model id + edge-builder v)` in the existing settings blob. On startup, if the fingerprint
differs (a migration or model upgrade happened), mark the index **stale** and rebuild lazily. If the
Drift item count and Cozo node count diverge beyond a threshold, offer a rebuild.

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

**Vector index:** HNSW relation `embedding {id => v: <F32; DIM>}` with `::hnsw create`. **DIM** is
fixed by the embedder (e.g. Gecko ~256/384 — confirm at impl) and **pinned in the schema
fingerprint**.

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

## 6. Sync model — `GraphSyncService`

Single owner in the data layer (e.g. `lib/core/graph/graph_sync_service.dart`), invoked from
repositories — **never the UI**.

- **Initial bulk build / "Rebuild index" maintenance action** (Settings, beside the existing
  `DedupeService` / storage-maintenance): read Drift rows in batches, project nodes/edges, compute
  embeddings, **bulk-load via `cozo_import_relations`** (far faster than per-row `:put`).
- **Incremental hooks at existing repository write points:**
  - `onItemAdded(id)` — download-complete insert (queue/downloader completion): upsert media node +
    entity nodes (uploader/site/playlist/folder/tags) + deterministic edges; enqueue embedding.
  - `onItemChanged(id)` — `metadata_repository.dart`, `folder_repository.dart`
    (rename/tag/favorite/move/collection).
  - `onItemRemoved(id)` — `library_repository.dart` `deleteItem` (≈ line 39): delete node; edges
    cascade in CozoScript.
- **Idempotent** (`:put`/upsert) so a replay after a crash or partial rebuild converges.
- **Embedding generation is the slow step** — queue it, batch it, and let it **lag** the
  deterministic edges (the graph is useful before vectors exist).

---

## 7. Graph algorithm → feature map

| Feature (phase) | Cozo mechanism |
|---|---|
| **Related / "More like this"** (P10) | HNSW `~embedding{…}` vector search + graph re-rank (shared uploader/tag/playlist boosts). Also the retrieval half of P12 GraphRAG. |
| **Entity hubs** (P10) | degree / `PageRank` over `postedBy` / `taggedWith` to rank top creators/tags. |
| **Near-duplicate clusters** (P10) | `duplicateOf` connected components + high-score `similarTo`; optionally Cozo **MinHash-LSH**. |
| **Tag suggestions** (P10) | co-occurrence over a node's neighborhood. |
| **Interactive graph viz** (P10) | neighborhood query → render with `graphview` (force-directed, expand/collapse). |
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
- **Real-device behavior** → Cozo opens & persists across restarts under the AAR; `close_db` /
  release on app background to avoid SQLite locks. → explicit `docs/VERIFICATION.md` items.
- **Index/Drift drift** → schema-fingerprint check + count-divergence rebuild offer (§3).

## 9. `GraphStore` conformance-test outline

A backend-agnostic test suite (run against the Cozo impl now, any future impl later): open/close
idempotency; upsert node/edge/embedding then read back; `removeItem` cascades edges; `vectorSearch`
returns nearest by cosine; `relatedTo` blends vector + graph; `rebuildAll` from a fixture Drift set
reproduces a deterministic node/edge count; replay/idempotency (running sync twice converges).
