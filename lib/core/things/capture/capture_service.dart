import 'package:grabbit/core/things/capture/direct_parse.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/curator/thing_classifier.dart';
import 'package:grabbit/core/things/provenance.dart';
import 'package:grabbit/core/things/schema_org_vocabulary.dart';
import 'package:grabbit/core/things/thing_doc.dart';

/// Which ADR-0002 branch produced a capture.
enum CaptureBranch {
  /// Branch (a): structured markup parsed with no model call (device-universal).
  directParse,

  /// Branch (b/c): the narrow-then-fill curator read the content semantically.
  model,

  /// Nothing structured and nothing extracted.
  none,
}

/// One raw input to capture, from any intake path (web-article, file, manual,
/// barcode — P16b). [sourceRef] identifies where it came from (stamped into
/// provenance); the rest are optional hints. [html] drives branch (a); [text]
/// (+ [title]/[url]/[mediaType]/[tags]) drives the curator fallback.
class CaptureRequest {
  const CaptureRequest({
    required this.sourceRef,
    this.html,
    this.title,
    this.text,
    this.url,
    this.mediaType,
    this.tags = const [],
  });

  final String sourceRef;
  final String? html;
  final String? title;
  final String? text;
  final String? url;
  final String? mediaType;
  final List<String> tags;
}

/// The result of a capture: which [branch] ran, and (when something was found) the
/// candidate [doc] — a validated, provenance-stamped `ThingDoc` **not yet asserted**
/// (suggest-don't-assert, ADR-0004; persistence + review is P16b).
class CaptureOutcome {
  const CaptureOutcome({
    required this.branch,
    this.doc,
    this.type,
    this.confidence = 0,
    this.provenance,
  });

  /// Nothing structured, nothing extracted.
  static const CaptureOutcome none = CaptureOutcome(branch: CaptureBranch.none);

  final CaptureBranch branch;
  final ThingDoc? doc;
  final String? type;
  final double confidence;
  final Provenance? provenance;
}

/// The single intake seam every "Grab anything" path routes through (P16). It runs
/// ADR-0002's narrow-then-fill end to end: **branch (a)** direct-parse when the input
/// carries structured markup (no model, every device), otherwise the **branch (b/c)**
/// curator over the content. Pure — the model call is injected, so the whole flow is
/// unit-testable and engine-agnostic.
class CaptureService {
  const CaptureService(this._vocab);

  final SchemaOrgVocabulary _vocab;

  /// Captures [request]. Returns a [CaptureOutcome]; rethrows a curator
  /// `InferenceException` (e.g. `unavailable`) so the caller can surface a friendly
  /// "needs model" reason (mirrors `ThingExtractionService`).
  Future<CaptureOutcome> capture(
    CaptureRequest request, {
    required GenerateStructured generate,
    String? modelId,
    DateTime Function() now = DateTime.now,
  }) async {
    // Branch (a): direct-parse structured markup — no model, every device.
    final html = request.html;
    if (html != null && html.trim().isNotEmpty) {
      final candidates = directParse(
        html,
        sourceRef: request.sourceRef,
        vocab: _vocab,
        now: now,
      );
      if (candidates.isNotEmpty) {
        final doc = candidates.first;
        return CaptureOutcome(
          branch: CaptureBranch.directParse,
          doc: doc,
          type: doc.type,
          confidence: 1,
          provenance: Provenance.directParse,
        );
      }
    }

    // Branch (b/c): no ready structure → the narrow-then-fill curator.
    final text = request.text?.trim() ?? '';
    if (text.isEmpty) return CaptureOutcome.none;

    final host = request.url == null ? null : Uri.tryParse(request.url!)?.host;
    final result = await Curator(_vocab).curate(
      input: ClassificationInput(
        title: request.title,
        text: text,
        host: (host == null || host.isEmpty) ? null : host,
        mediaType: request.mediaType,
        tags: request.tags,
      ),
      generate: generate,
      sourceRef: request.sourceRef,
      modelId: modelId,
      now: now,
    );
    if (result == null) return CaptureOutcome.none;
    return CaptureOutcome(
      branch: CaptureBranch.model,
      doc: result.doc,
      type: result.type,
      confidence: result.confidence,
      provenance: result.provenance,
    );
  }
}
