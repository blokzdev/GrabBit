import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/thing_doc.dart';
import 'package:grabbit/core/things/thing_edge_repository.dart';

/// The schema.org type backing a reified relationship note (P16e, ADR-0004 kind 3).
const String kAuthoredNoteType = 'Comment';

/// Builds a user-authored `Comment` [ThingDoc] from a note's [text] (P16e) — the
/// reified relationship promoted to its own searchable Thing. `name` is a short
/// snippet so it's findable in the browser; the full note is `text`.
ThingDoc buildNoteThing(String text, {DateTime Function() now = DateTime.now}) {
  final clean = text.trim();
  final snippet = clean.length <= 60 ? clean : '${clean.substring(0, 57)}…';
  return ThingDoc({
    '@context': 'https://schema.org',
    '@type': kAuthoredNoteType,
    if (snippet.isNotEmpty) 'name': snippet,
    if (clean.isNotEmpty) 'text': clean,
    kGrabbitProvenanceKey: grabbitProvenanceBlock(
      provenance: Provenance.userAuthored,
      capturedAt: now(),
      sourceRef: 'authored-note',
    ),
  });
}

/// Writes the **authored-edge moat** (P16e, ADR-0004 kind 2 + 3): a user-asserted
/// `relatedTo`-style link between two Things, and the reified note that promotes a
/// content-bearing relationship to its own `Comment` Thing linking both. Thin
/// wrapper over [ThingEdgeRepository] + [CaptureCommitService] — no schema bump.
class AuthoredEdgeService {
  AuthoredEdgeService(this._edges, this._commit, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ThingEdgeRepository _edges;
  final CaptureCommitService _commit;
  final DateTime Function() _now;

  /// Asserts a user-authored [subject]→[object] edge labelled [predicate], with an
  /// optional [note].
  Future<void> addLink({
    required String subject,
    required String object,
    required String predicate,
    String? note,
  }) {
    final trimmedNote = note?.trim();
    return _edges.upsertEdge(
      subject: subject,
      object: object,
      predicate: predicate,
      provenance: Provenance.userAuthored,
      note: (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
    );
  }

  /// Removes the user-authored [subject]→[object] edge labelled [predicate].
  Future<void> deleteLink(String subject, String predicate, String object) =>
      _edges.deleteEdge(subject, predicate, object);

  /// Promotes a content-bearing relationship to a reified `Comment` Thing holding
  /// [text], linked to both [subjectId] and [objectId] via authored `about` edges.
  /// Returns the new Comment's id.
  Future<String> addNote({
    required String subjectId,
    required String objectId,
    required String text,
  }) async {
    final commentId = await _commit.commitThing(
      buildNoteThing(text, now: _now),
    );
    for (final participant in [subjectId, objectId]) {
      await _edges.upsertEdge(
        subject: commentId,
        object: participant,
        predicate: 'about',
        provenance: Provenance.userAuthored,
      );
    }
    return commentId;
  }
}

final authoredEdgeServiceProvider = Provider<AuthoredEdgeService>(
  (ref) => AuthoredEdgeService(
    ref.watch(thingEdgeRepositoryProvider),
    ref.watch(captureCommitServiceProvider),
  ),
);
