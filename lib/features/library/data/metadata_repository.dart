import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/db/database_provider.dart';
import 'package:grabbit/core/utils/shared_url.dart';

enum LibrarySort {
  newest,
  oldest,
  titleAsc,
  titleDesc,
  largest,
  smallest,
  recentlyPlayed,
  // P10h: FTS relevance (bm25). Only meaningful with an active search query;
  // falls back to newest ordering when the query is empty.
  relevance,
  // P10i-b: media duration. Timed-media only (see library_options.dart); null
  // durations (split-chapter files, images) sort last in both directions.
  longest,
  shortest,
  // P10i-b: source upload date (media_metadata.upload_date); null dates last.
  uploadNewest,
  uploadOldest,
}

/// P10i-d preset duration ranges (seconds). Timed media only; items with an
/// unknown duration never match a bucket.
enum DurationBucket {
  underMin,
  oneToFive,
  fiveToTwenty,
  twentyToHour,
  overHour,
}

extension DurationBucketRange on DurationBucket {
  /// `[min, max)` in seconds; `max == null` means unbounded.
  (int min, int? max) get range => switch (this) {
    DurationBucket.underMin => (0, 60),
    DurationBucket.oneToFive => (60, 300),
    DurationBucket.fiveToTwenty => (300, 1200),
    DurationBucket.twentyToHour => (1200, 3600),
    DurationBucket.overHour => (3600, null),
  };
}

/// P10i-d preset resolution tiers, by pixel height. Video/image only; items
/// with unknown dimensions never match a bucket.
enum ResolutionBucket { sd, hd, fullHd, uhd }

extension ResolutionBucketRange on ResolutionBucket {
  /// `[min, max)` pixel height; `max == null` means unbounded.
  (int min, int? max) get heightRange => switch (this) {
    ResolutionBucket.sd => (0, 720),
    ResolutionBucket.hd => (720, 1080),
    ResolutionBucket.fullHd => (1080, 2160),
    ResolutionBucket.uhd => (2160, null),
  };
}

/// P10i-d preset date ranges, used for both the downloaded (created_at) and
/// uploaded (upload_date) filters.
enum DateBucket { today, last7, last30, thisYear }

extension DateBucketSince on DateBucket {
  /// The inclusive lower bound for "within this range", relative to [now].
  DateTime since(DateTime now) => switch (this) {
    DateBucket.today => DateTime(now.year, now.month, now.day),
    DateBucket.last7 => now.subtract(const Duration(days: 7)),
    DateBucket.last30 => now.subtract(const Duration(days: 30)),
    DateBucket.thisYear => DateTime(now.year),
  };
}

/// Search / filter / sort parameters for the library grid.
class LibraryQuery {
  const LibraryQuery({
    this.search = '',
    this.types = const {},
    this.collectionId,
    this.sort = LibrarySort.newest,
    this.site,
    this.uploader,
    this.playlistId,
    this.tag,
    this.favoritesOnly = false,
    this.hasTranscript = false,
    this.durationBucket,
    this.resolutionBucket,
    this.downloadedBucket,
    this.uploadedBucket,
  });

  final String search; // FTS over title + description + transcript (P10h)
  final Set<String> types; // video/audio/image; empty = all (P10i)
  final int? collectionId;
  final LibrarySort sort;
  final String? site; // platform facet
  final String? uploader; // channel facet
  final String? playlistId; // playlist facet
  final String? tag; // tag facet (by tag name)
  final bool favoritesOnly;
  final bool hasTranscript; // P10h: only items with an extracted transcript
  final DurationBucket? durationBucket; // P10i-d
  final ResolutionBucket? resolutionBucket; // P10i-d
  final DateBucket? downloadedBucket; // P10i-d: by created_at
  final DateBucket? uploadedBucket; // P10i-d: by upload_date

  /// Active metadata facets (excludes search/type/sort/collection).
  int get activeFacetCount =>
      (site != null ? 1 : 0) +
      (uploader != null ? 1 : 0) +
      (playlistId != null ? 1 : 0) +
      (tag != null ? 1 : 0) +
      (hasTranscript ? 1 : 0) +
      (durationBucket != null ? 1 : 0) +
      (resolutionBucket != null ? 1 : 0) +
      (downloadedBucket != null ? 1 : 0) +
      (uploadedBucket != null ? 1 : 0);

  LibraryQuery copyWith({
    String? search,
    Set<String>? types,
    int? Function()? collectionId,
    LibrarySort? sort,
    String? Function()? site,
    String? Function()? uploader,
    String? Function()? playlistId,
    String? Function()? tag,
    bool? favoritesOnly,
    bool? hasTranscript,
    DurationBucket? Function()? durationBucket,
    ResolutionBucket? Function()? resolutionBucket,
    DateBucket? Function()? downloadedBucket,
    DateBucket? Function()? uploadedBucket,
  }) => LibraryQuery(
    search: search ?? this.search,
    types: types ?? this.types,
    collectionId: collectionId != null ? collectionId() : this.collectionId,
    sort: sort ?? this.sort,
    site: site != null ? site() : this.site,
    uploader: uploader != null ? uploader() : this.uploader,
    playlistId: playlistId != null ? playlistId() : this.playlistId,
    tag: tag != null ? tag() : this.tag,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    hasTranscript: hasTranscript ?? this.hasTranscript,
    durationBucket: durationBucket != null
        ? durationBucket()
        : this.durationBucket,
    resolutionBucket: resolutionBucket != null
        ? resolutionBucket()
        : this.resolutionBucket,
    downloadedBucket: downloadedBucket != null
        ? downloadedBucket()
        : this.downloadedBucket,
    uploadedBucket: uploadedBucket != null
        ? uploadedBucket()
        : this.uploadedBucket,
  );
}

/// A distinct playlist facet value (filter by [id], display [title]).
class PlaylistFacet {
  const PlaylistFacet({required this.id, required this.title});
  final String id;
  final String title;
}

// P10i-b: a row's source upload date, fetched from media_metadata for ordering
// the typed (non-search) library query, which selects only media_items.
const _uploadDateSubquery =
    '(SELECT upload_date FROM media_metadata WHERE item_id = media_items.id)';
const _uploadDateExpr = CustomExpression<DateTime>(_uploadDateSubquery);
const _uploadDateIsNull = CustomExpression<bool>(
  '$_uploadDateSubquery IS NULL',
);
// Same subquery for the search path, where media_items is aliased `mi`.
const _uploadDateSubqueryMi =
    '(SELECT upload_date FROM media_metadata WHERE item_id = mi.id)';

/// Tags, collections, notes/title edits, and parameterized library queries.
class MetadataRepository {
  MetadataRepository(this._db);

  final AppDatabase _db;

  Stream<List<MediaItem>> watchFiltered(LibraryQuery q) {
    final search = q.search.trim();
    // The keyword search runs through the FTS5 index (title + description +
    // transcript). Drift's query builder has no safe `MATCH`, so the search
    // path is a parameterized raw query; the empty-search path keeps the typed
    // builder. Filters are mirrored across both.
    if (search.isNotEmpty) return _watchSearch(q, search);

    final query = _db.select(_db.mediaItems);
    if (q.types.isNotEmpty) {
      query.where((t) => t.type.isIn(q.types.toList()));
    }
    if (q.site != null) {
      query.where((t) => t.site.equals(q.site!));
    }
    if (q.favoritesOnly) {
      query.where((t) => t.isFavorite.equals(true));
    }
    if (q.hasTranscript) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaMetadata)
            ..addColumns([_db.mediaMetadata.itemId])
            ..where(_db.mediaMetadata.transcript.isNotNull()),
        ),
      );
    }
    if (q.collectionId != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaCollections)
            ..addColumns([_db.mediaCollections.itemId])
            ..where(_db.mediaCollections.collectionId.equals(q.collectionId!)),
        ),
      );
    }
    if (q.uploader != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaMetadata)
            ..addColumns([_db.mediaMetadata.itemId])
            ..where(_db.mediaMetadata.uploader.equals(q.uploader!)),
        ),
      );
    }
    if (q.playlistId != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaMetadata)
            ..addColumns([_db.mediaMetadata.itemId])
            ..where(_db.mediaMetadata.playlistId.equals(q.playlistId!)),
        ),
      );
    }
    if (q.tag != null) {
      query.where(
        (t) => t.id.isInQuery(
          _db.selectOnly(_db.mediaTags)
            ..addColumns([_db.mediaTags.itemId])
            ..join([
              innerJoin(_db.tags, _db.tags.id.equalsExp(_db.mediaTags.tagId)),
            ])
            ..where(_db.tags.name.equals(q.tag!)),
        ),
      );
    }
    // P10i-d range buckets. `>= min (& < max)` on a nullable column excludes
    // rows with an unknown value (NULL comparisons are never true).
    final now = DateTime.now();
    if (q.durationBucket != null) {
      final (min, max) = q.durationBucket!.range;
      query.where((t) => t.durationSec.isBiggerOrEqualValue(min));
      if (max != null) {
        query.where((t) => t.durationSec.isSmallerThanValue(max));
      }
    }
    if (q.resolutionBucket != null) {
      final (min, max) = q.resolutionBucket!.heightRange;
      query.where((t) => t.height.isBiggerOrEqualValue(min));
      if (max != null) query.where((t) => t.height.isSmallerThanValue(max));
    }
    if (q.downloadedBucket != null) {
      final since = q.downloadedBucket!.since(now);
      query.where((t) => t.createdAt.isBiggerOrEqualValue(since));
    }
    if (q.uploadedBucket != null) {
      final since = q.uploadedBucket!.since(now);
      query.where((_) => _uploadDateExpr.isBiggerOrEqualValue(since));
    }
    query.orderBy(switch (q.sort) {
      // Relevance is meaningless without a query → fall back to newest.
      LibrarySort.newest ||
      LibrarySort.relevance => [(t) => OrderingTerm.desc(t.createdAt)],
      LibrarySort.oldest => [(t) => OrderingTerm.asc(t.createdAt)],
      LibrarySort.titleAsc => [(t) => OrderingTerm.asc(t.title)],
      LibrarySort.titleDesc => [(t) => OrderingTerm.desc(t.title)],
      LibrarySort.largest => [(t) => OrderingTerm.desc(t.sizeBytes)],
      LibrarySort.smallest => [(t) => OrderingTerm.asc(t.sizeBytes)],
      // NULLs (never played) sort last on DESC in SQLite.
      LibrarySort.recentlyPlayed => [
        (t) => OrderingTerm.desc(t.lastAccessedAt),
      ],
      // P10i-b: a leading `IS NULL` term sinks null durations last regardless
      // of the value direction (avoids relying on `NULLS LAST` syntax).
      LibrarySort.longest => [
        (t) => OrderingTerm.asc(t.durationSec.isNull()),
        (t) => OrderingTerm.desc(t.durationSec),
      ],
      LibrarySort.shortest => [
        (t) => OrderingTerm.asc(t.durationSec.isNull()),
        (t) => OrderingTerm.asc(t.durationSec),
      ],
      // P10i-b: upload_date lives on media_metadata, not on this row → order by
      // a correlated subquery, with null dates last (same IS NULL lead term).
      LibrarySort.uploadNewest => [
        (_) => OrderingTerm.asc(_uploadDateIsNull),
        (_) => OrderingTerm.desc(_uploadDateExpr),
      ],
      LibrarySort.uploadOldest => [
        (_) => OrderingTerm.asc(_uploadDateIsNull),
        (_) => OrderingTerm.asc(_uploadDateExpr),
      ],
    });
    return query.watch();
  }

  /// FTS5-backed keyword search path (P10h). Joins `media_items` to the
  /// `media_fts` index via `MATCH`, mirrors the [LibraryQuery] filters as bound
  /// clauses, and orders by bm25 relevance (or the chosen column). Reactive via
  /// `readsFrom` on the content tables — the sync triggers refresh `media_fts`
  /// in the same transaction, so edits re-run the stream.
  Stream<List<MediaItem>> _watchSearch(LibraryQuery q, String search) {
    final where = <String>['media_fts MATCH ?'];
    final vars = <Variable<Object>>[
      Variable.withString(_ftsMatchQuery(search)),
    ];
    if (q.types.isNotEmpty) {
      where.add('mi.type IN (${List.filled(q.types.length, '?').join(', ')})');
      vars.addAll(q.types.map(Variable.withString));
    }
    if (q.site != null) {
      where.add('mi.site = ?');
      vars.add(Variable.withString(q.site!));
    }
    if (q.favoritesOnly) {
      where.add('mi.is_favorite = 1');
    }
    if (q.hasTranscript) {
      where.add(
        'mi.id IN (SELECT item_id FROM media_metadata WHERE transcript IS NOT NULL)',
      );
    }
    if (q.collectionId != null) {
      where.add(
        'mi.id IN (SELECT item_id FROM media_collections WHERE collection_id = ?)',
      );
      vars.add(Variable.withInt(q.collectionId!));
    }
    if (q.uploader != null) {
      where.add(
        'mi.id IN (SELECT item_id FROM media_metadata WHERE uploader = ?)',
      );
      vars.add(Variable.withString(q.uploader!));
    }
    if (q.playlistId != null) {
      where.add(
        'mi.id IN (SELECT item_id FROM media_metadata WHERE playlist_id = ?)',
      );
      vars.add(Variable.withString(q.playlistId!));
    }
    if (q.tag != null) {
      where.add(
        'mi.id IN (SELECT mt.item_id FROM media_tags mt '
        'JOIN tags t ON t.id = mt.tag_id WHERE t.name = ?)',
      );
      vars.add(Variable.withString(q.tag!));
    }
    // P10i-d range buckets (mirror the typed path; nulls excluded by `>=`).
    final now = DateTime.now();
    if (q.durationBucket != null) {
      final (min, max) = q.durationBucket!.range;
      where.add('mi.duration_sec >= ?');
      vars.add(Variable.withInt(min));
      if (max != null) {
        where.add('mi.duration_sec < ?');
        vars.add(Variable.withInt(max));
      }
    }
    if (q.resolutionBucket != null) {
      final (min, max) = q.resolutionBucket!.heightRange;
      where.add('mi.height >= ?');
      vars.add(Variable.withInt(min));
      if (max != null) {
        where.add('mi.height < ?');
        vars.add(Variable.withInt(max));
      }
    }
    if (q.downloadedBucket != null) {
      where.add('mi.created_at >= ?');
      vars.add(Variable.withDateTime(q.downloadedBucket!.since(now)));
    }
    if (q.uploadedBucket != null) {
      where.add('$_uploadDateSubqueryMi >= ?');
      vars.add(Variable.withDateTime(q.uploadedBucket!.since(now)));
    }
    final order = switch (q.sort) {
      LibrarySort.relevance => 'bm25(media_fts)',
      LibrarySort.newest => 'mi.created_at DESC',
      LibrarySort.oldest => 'mi.created_at ASC',
      LibrarySort.titleAsc => 'mi.title ASC',
      LibrarySort.titleDesc => 'mi.title DESC',
      LibrarySort.largest => 'mi.size_bytes DESC',
      LibrarySort.smallest => 'mi.size_bytes ASC',
      LibrarySort.recentlyPlayed => 'mi.last_accessed_at DESC',
      // P10i-b: leading IS NULL term keeps null durations/dates last either way.
      LibrarySort.longest => 'mi.duration_sec IS NULL, mi.duration_sec DESC',
      LibrarySort.shortest => 'mi.duration_sec IS NULL, mi.duration_sec ASC',
      LibrarySort.uploadNewest =>
        '$_uploadDateSubqueryMi IS NULL, $_uploadDateSubqueryMi DESC',
      LibrarySort.uploadOldest =>
        '$_uploadDateSubqueryMi IS NULL, $_uploadDateSubqueryMi ASC',
    };
    final sql =
        'SELECT mi.* FROM media_items mi '
        'JOIN media_fts ON media_fts.item_id = mi.id '
        'WHERE ${where.join(' AND ')} ORDER BY $order';
    return _db
        .customSelect(
          sql,
          variables: vars,
          readsFrom: {
            _db.mediaItems,
            _db.mediaMetadata,
            _db.mediaTags,
            _db.mediaCollections,
            _db.tags,
          },
        )
        .watch()
        .map((rows) => rows.map((r) => _db.mediaItems.map(r.data)).toList());
  }

  /// Builds a safe FTS5 MATCH expression from raw user input: each
  /// whitespace-separated token is double-quoted (so `-`, `:`, etc. are literal,
  /// not operators) and prefix-matched (`*`). Tokens are AND-ed (FTS5 default).
  String _ftsMatchQuery(String raw) => raw
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .map((t) => '"${t.replaceAll('"', '""')}"*')
      .join(' ');

  /// Stars or unstars a library item (P9b).
  Future<void> toggleFavorite(String itemId, bool value) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(isFavorite: Value(value)),
    );
  }

  /// Stamps `lastAccessedAt` = now (P9c); feeds the "Recently played" album.
  Future<void> markPlayed(String itemId) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(lastAccessedAt: Value(DateTime.now())),
    );
  }

  /// Distinct platform/site values present in the library (for the facet picker).
  Stream<List<String>> watchDistinctSites() {
    final q = _db.selectOnly(_db.mediaItems, distinct: true)
      ..addColumns([_db.mediaItems.site])
      ..orderBy([OrderingTerm.asc(_db.mediaItems.site)]);
    return q.map((r) => r.read(_db.mediaItems.site)!).watch();
  }

  /// Distinct uploader/channel names present in the library.
  Stream<List<String>> watchDistinctUploaders() {
    final q = _db.selectOnly(_db.mediaMetadata, distinct: true)
      ..addColumns([_db.mediaMetadata.uploader])
      ..where(_db.mediaMetadata.uploader.isNotNull())
      ..orderBy([OrderingTerm.asc(_db.mediaMetadata.uploader)]);
    return q.map((r) => r.read(_db.mediaMetadata.uploader)!).watch();
  }

  /// Distinct tag names actually applied to library items (for the facet picker).
  Stream<List<String>> watchDistinctTags() {
    final q =
        _db.selectOnly(_db.mediaTags, distinct: true).join([
            innerJoin(_db.tags, _db.tags.id.equalsExp(_db.mediaTags.tagId)),
          ])
          ..addColumns([_db.tags.name])
          ..orderBy([OrderingTerm.asc(_db.tags.name)]);
    return q.map((r) => r.read(_db.tags.name)!).watch();
  }

  /// Distinct playlists present in the library.
  Stream<List<PlaylistFacet>> watchDistinctPlaylists() {
    final q = _db.selectOnly(_db.mediaMetadata, distinct: true)
      ..addColumns([
        _db.mediaMetadata.playlistId,
        _db.mediaMetadata.playlistTitle,
      ])
      ..where(_db.mediaMetadata.playlistId.isNotNull())
      ..orderBy([OrderingTerm.asc(_db.mediaMetadata.playlistTitle)]);
    return q.map((r) {
      final id = r.read(_db.mediaMetadata.playlistId)!;
      return PlaylistFacet(
        id: id,
        title: r.read(_db.mediaMetadata.playlistTitle) ?? id,
      );
    }).watch();
  }

  // --- Smart / auto albums (P9b-2) ---

  /// Item counts per platform (`site` → count), for the Platforms albums.
  Stream<Map<String, int>> watchItemCountsBySite() {
    final count = _db.mediaItems.id.count();
    final query = _db.selectOnly(_db.mediaItems)
      ..addColumns([_db.mediaItems.site, count])
      ..groupBy([_db.mediaItems.site]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaItems.site)!: row.read(count) ?? 0,
      },
    );
  }

  /// Item counts per channel (`uploader` → count), for the Channels albums.
  Stream<Map<String, int>> watchItemCountsByUploader() {
    final count = _db.mediaMetadata.itemId.count();
    final query = _db.selectOnly(_db.mediaMetadata)
      ..addColumns([_db.mediaMetadata.uploader, count])
      ..where(_db.mediaMetadata.uploader.isNotNull())
      ..groupBy([_db.mediaMetadata.uploader]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaMetadata.uploader)!: row.read(count) ?? 0,
      },
    );
  }

  /// Items played at least once, most-recent first (the Recently-played album).
  Stream<List<MediaItem>> watchRecentlyPlayed({int limit = 100}) {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.lastAccessedAt.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastAccessedAt)])
      ..limit(limit);
    return query.watch();
  }

  // --- Preventive (source-identity) dedupe (P9b-4) ---

  /// The library item with this yt-dlp source id, or null. Used to warn before
  /// re-downloading something already saved.
  Future<MediaItem?> findItemBySourceId(String sourceId) async {
    final rows = await (_db.select(_db.mediaItems).join([
      innerJoin(
        _db.mediaMetadata,
        _db.mediaMetadata.itemId.equalsExp(_db.mediaItems.id),
      ),
    ])..where(_db.mediaMetadata.sourceId.equals(sourceId))).get();
    return rows.isEmpty ? null : rows.first.readTable(_db.mediaItems);
  }

  /// Fallback match by source URL (tracking params stripped), for items saved
  /// without a source id.
  Future<MediaItem?> findItemByUrl(String url) async {
    final normalized = stripTrackingParams(url);
    final rows =
        await (_db.select(_db.mediaItems)
              ..where((t) => t.sourceUrl.equals(normalized))
              ..limit(1))
            .get();
    return rows.isEmpty ? null : rows.first;
  }

  /// All source ids present in the library (one-shot), for marking playlist
  /// entries already saved.
  Future<Set<String>> existingSourceIds() async {
    final q = _db.selectOnly(_db.mediaMetadata)
      ..addColumns([_db.mediaMetadata.sourceId])
      ..where(_db.mediaMetadata.sourceId.isNotNull());
    final rows = await q.get();
    return {for (final r in rows) r.read(_db.mediaMetadata.sourceId)!};
  }

  // --- Duplicates & storage (P9b-3) ---

  /// Groups of items that share a `contentHash` (2+ each) — likely duplicates.
  Stream<List<List<MediaItem>>> watchDuplicates() {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.contentHash.isNotNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.contentHash),
        (t) => OrderingTerm.asc(t.createdAt),
      ]);
    return query.watch().map((rows) {
      final groups = <String, List<MediaItem>>{};
      for (final r in rows) {
        groups.putIfAbsent(r.contentHash!, () => []).add(r);
      }
      return groups.values.where((g) => g.length > 1).toList();
    });
  }

  /// Total bytes per media type (`video`/`audio`/`image`).
  Stream<Map<String, int>> watchSizeByType() =>
      _watchSizeGrouped(_db.mediaItems.type);

  /// Total bytes per platform (`site`).
  Stream<Map<String, int>> watchSizeBySite() =>
      _watchSizeGrouped(_db.mediaItems.site);

  Stream<Map<String, int>> _watchSizeGrouped(GeneratedColumn<String> column) {
    final sum = _db.mediaItems.sizeBytes.sum();
    final query = _db.selectOnly(_db.mediaItems)
      ..addColumns([column, sum])
      ..groupBy([column]);
    return query.watch().map(
      (rows) => {
        for (final row in rows) row.read<String>(column)!: row.read(sum) ?? 0,
      },
    );
  }

  /// The biggest items first (for storage cleanup).
  Stream<List<MediaItem>> watchLargestItems({int limit = 20}) {
    final query = _db.select(_db.mediaItems)
      ..where((t) => t.sizeBytes.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.sizeBytes)])
      ..limit(limit);
    return query.watch();
  }

  Stream<MediaMetadataData?> watchMetadataForItem(String itemId) => (_db.select(
    _db.mediaMetadata,
  )..where((t) => t.itemId.equals(itemId))).watchSingleOrNull();

  /// One-shot read of an item's metadata row (P13b-2) — for commands that need
  /// the current value once (e.g. translation) rather than a reactive stream.
  Future<MediaMetadataData?> metadataForItem(String itemId) => (_db.select(
    _db.mediaMetadata,
  )..where((t) => t.itemId.equals(itemId))).getSingleOrNull();

  Future<void> updateTitle(String itemId, String title) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(title: Value(title.trim())),
    );
  }

  Future<void> updateNotes(String itemId, String? notes) async {
    await (_db.update(_db.mediaItems)..where((t) => t.id.equals(itemId))).write(
      MediaItemsCompanion(notes: Value(notes)),
    );
  }

  /// Stores the extracted plain-text [transcript] (P10f) and, when provided, the
  /// timestamped [cuesJson] for the synced view (P10f-4). Upserts so it works
  /// for items whose metadata row predates these columns.
  Future<void> updateTranscript(
    String itemId,
    String transcript, {
    String? cuesJson,
  }) async {
    await _db
        .into(_db.mediaMetadata)
        .insertOnConflictUpdate(
          MediaMetadataCompanion.insert(
            itemId: itemId,
            transcript: Value(transcript),
            transcriptCues: Value(cuesJson),
          ),
        );
  }

  /// Stores the on-device abstractive (LLM) [summary] for an item plus the
  /// [modelId] that produced it (P13a). Upserts (only these columns) so it works
  /// for items whose metadata row predates the columns; passing `null` clears it.
  Future<void> updateAiSummary(
    String itemId,
    String? summary, {
    String? modelId,
  }) async {
    await _db
        .into(_db.mediaMetadata)
        .insertOnConflictUpdate(
          MediaMetadataCompanion.insert(
            itemId: itemId,
            aiSummary: Value(summary),
            aiSummaryModelId: Value(modelId),
          ),
        );
  }

  /// Stores the on-device OCR [text] extracted from an image (P13b-1). Upserts
  /// (only this column) so it works for items whose metadata row predates the
  /// column; passing `null` clears it. The `media_fts` triggers reindex it for
  /// full-text search automatically.
  Future<void> updateOcrText(String itemId, String? text) async {
    await _db
        .into(_db.mediaMetadata)
        .insertOnConflictUpdate(
          MediaMetadataCompanion.insert(itemId: itemId, ocrText: Value(text)),
        );
  }

  // --- Tags ---

  Stream<List<Tag>> watchTagsForItem(String itemId) {
    final query = _db.select(_db.tags).join([
      innerJoin(_db.mediaTags, _db.mediaTags.tagId.equalsExp(_db.tags.id)),
    ])..where(_db.mediaTags.itemId.equals(itemId));
    return query.map((row) => row.readTable(_db.tags)).watch();
  }

  Future<void> addTagToItem(String itemId, String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    await _db
        .into(_db.tags)
        .insert(
          TagsCompanion.insert(name: clean),
          mode: InsertMode.insertOrIgnore,
        );
    final tag = await (_db.select(
      _db.tags,
    )..where((t) => t.name.equals(clean))).getSingle();
    await _db
        .into(_db.mediaTags)
        .insert(
          MediaTagsCompanion.insert(itemId: itemId, tagId: tag.id),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeTagFromItem(String itemId, int tagId) async {
    await (_db.delete(
      _db.mediaTags,
    )..where((t) => t.itemId.equals(itemId) & t.tagId.equals(tagId))).go();
  }

  // --- Collections ---

  Stream<List<Collection>> watchCollections() => (_db.select(
    _db.collections,
  )..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<int> createCollection(String name) => _db
      .into(_db.collections)
      .insert(
        CollectionsCompanion.insert(
          name: name.trim(),
          createdAt: DateTime.now(),
        ),
      );

  Future<void> deleteCollection(int id) async {
    await (_db.delete(_db.collections)..where((t) => t.id.equals(id))).go();
  }

  Future<void> renameCollection(int id, String name) async {
    await (_db.update(_db.collections)..where((t) => t.id.equals(id))).write(
      CollectionsCompanion(name: Value(name.trim())),
    );
  }

  /// Item counts per collection (`collectionId` → count) for the list rows.
  Stream<Map<int, int>> watchCollectionItemCounts() {
    final count = _db.mediaCollections.itemId.count();
    final query = _db.selectOnly(_db.mediaCollections)
      ..addColumns([_db.mediaCollections.collectionId, count])
      ..groupBy([_db.mediaCollections.collectionId]);
    return query.watch().map(
      (rows) => {
        for (final row in rows)
          row.read(_db.mediaCollections.collectionId)!: row.read(count) ?? 0,
      },
    );
  }

  Stream<List<Collection>> watchCollectionsForItem(String itemId) {
    final query = _db.select(_db.collections).join([
      innerJoin(
        _db.mediaCollections,
        _db.mediaCollections.collectionId.equalsExp(_db.collections.id),
      ),
    ])..where(_db.mediaCollections.itemId.equals(itemId));
    return query.map((row) => row.readTable(_db.collections)).watch();
  }

  Future<void> addItemToCollection(String itemId, int collectionId) async {
    await _db
        .into(_db.mediaCollections)
        .insert(
          MediaCollectionsCompanion.insert(
            itemId: itemId,
            collectionId: collectionId,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeItemFromCollection(String itemId, int collectionId) async {
    await (_db.delete(_db.mediaCollections)..where(
          (t) => t.itemId.equals(itemId) & t.collectionId.equals(collectionId),
        ))
        .go();
  }
}

final metadataRepositoryProvider = Provider<MetadataRepository>(
  (ref) => MetadataRepository(ref.watch(appDatabaseProvider)),
);

final tagsForItemProvider = StreamProvider.family<List<Tag>, String>(
  (ref, itemId) =>
      ref.watch(metadataRepositoryProvider).watchTagsForItem(itemId),
);

final collectionsProvider = StreamProvider<List<Collection>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchCollections(),
);

final collectionItemCountsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchCollectionItemCounts(),
);

final collectionsForItemProvider =
    StreamProvider.family<List<Collection>, String>(
      (ref, itemId) =>
          ref.watch(metadataRepositoryProvider).watchCollectionsForItem(itemId),
    );

// Hand-written (returns a Drift row type) per CLAUDE.md §8.
final metadataForItemProvider =
    StreamProvider.family<MediaMetadataData?, String>(
      (ref, itemId) =>
          ref.watch(metadataRepositoryProvider).watchMetadataForItem(itemId),
    );

final collectionItemsProvider = StreamProvider.family<List<MediaItem>, int>(
  (ref, collectionId) => ref
      .watch(metadataRepositoryProvider)
      .watchFiltered(LibraryQuery(collectionId: collectionId)),
);

// Distinct facet values for the Library filter sheet.
final distinctSitesProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctSites(),
);

final distinctUploadersProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctUploaders(),
);

final distinctPlaylistsProvider = StreamProvider<List<PlaylistFacet>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctPlaylists(),
);

final distinctTagsProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDistinctTags(),
);

// Smart / auto albums (P9b-2).
final siteCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchItemCountsBySite(),
);

final uploaderCountsProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchItemCountsByUploader(),
);

final recentlyPlayedProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchRecentlyPlayed(),
);

// Duplicates & storage (P9b-3).
final duplicatesProvider = StreamProvider<List<List<MediaItem>>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchDuplicates(),
);

final sizeByTypeProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchSizeByType(),
);

final sizeBySiteProvider = StreamProvider<Map<String, int>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchSizeBySite(),
);

final largestItemsProvider = StreamProvider<List<MediaItem>>(
  (ref) => ref.watch(metadataRepositoryProvider).watchLargestItems(),
);

/// Items for a smart album, keyed by ([kind], [value]). `kind` is
/// `site` | `channel` | `recentPlayed`.
final smartAlbumItemsProvider =
    StreamProvider.family<List<MediaItem>, ({String kind, String? value})>((
      ref,
      key,
    ) {
      final repo = ref.watch(metadataRepositoryProvider);
      return switch (key.kind) {
        'site' => repo.watchFiltered(LibraryQuery(site: key.value)),
        'channel' => repo.watchFiltered(LibraryQuery(uploader: key.value)),
        _ => repo.watchRecentlyPlayed(),
      };
    });

/// Items for an entity hub, keyed by ([type], [value]). `type` is
/// `uploader` | `site` | `playlist` | `tag`; `value` is the matching key
/// (uploader name / site / playlistId / tag name). Pure Drift faceting over
/// `watchFiltered` — works on every device, no graph needed.
final hubItemsProvider =
    StreamProvider.family<List<MediaItem>, ({String type, String value})>((
      ref,
      key,
    ) {
      final repo = ref.watch(metadataRepositoryProvider);
      return repo.watchFiltered(switch (key.type) {
        'uploader' => LibraryQuery(uploader: key.value),
        'site' => LibraryQuery(site: key.value),
        'playlist' => LibraryQuery(playlistId: key.value),
        'tag' => LibraryQuery(tag: key.value),
        _ => const LibraryQuery(),
      });
    });
