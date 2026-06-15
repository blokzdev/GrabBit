import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_repository.dart';

/// Commits a captured [ThingDoc] straight into the canonical store (P16b) — the
/// shared assert seam behind every "Grab anything" intake path.
///
/// Per ADR-0004, **deterministic, user-initiated captures** (manual entry,
/// direct-parse markup, barcode) assert directly: GrabBit mints the Thing id
/// (`thing_<micros>`, distinct from the JSON-LD `@id`, ADR-0003) and upserts the
/// [doc], whose `grabbit:provenance` block already records how it was captured.
/// Unlike `SuggestionReviewService.accept`, **no source-media edge** is written —
/// a universal capture has no MediaObject behind it. Model-extracted (AI-inferred)
/// captures still route through suggest-don't-assert review (P16b-2), not here.
class CaptureCommitService {
  CaptureCommitService(
    this._things, {
    DateTime Function() now = DateTime.now,
    String Function()? newThingId,
  }) : _newThingId =
           newThingId ?? (() => 'thing_${now().microsecondsSinceEpoch}');

  final ThingRepository _things;
  final String Function() _newThingId;

  /// Asserts [doc] as a new Thing and returns its minted id.
  Future<String> commitThing(ThingDoc doc) async {
    final id = _newThingId();
    await _things.upsertThing(id, doc);
    return id;
  }
}

final captureCommitServiceProvider = Provider<CaptureCommitService>(
  (ref) => CaptureCommitService(ref.watch(thingRepositoryProvider)),
);
