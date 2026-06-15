import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grabbit/core/ai/generation_provider.dart';
import 'package:grabbit/core/ai/inference_error.dart';
import 'package:grabbit/core/ai/structured_generation.dart';
import 'package:grabbit/core/db/database.dart';
import 'package:grabbit/core/things/capture/capture_commit_service.dart';
import 'package:grabbit/core/things/capture/capture_service.dart';
import 'package:grabbit/core/things/capture/capture_service_provider.dart';
import 'package:grabbit/core/things/capture/web_page_fetcher.dart';
import 'package:grabbit/core/things/curator/curator.dart';
import 'package:grabbit/core/things/thing_suggestion_repository.dart';
import 'package:grabbit/features/capture/data/web_capture.dart';
import 'package:grabbit/features/library/data/suggestion_review_service.dart';
import 'package:grabbit/features/notifications/data/notification_center.dart';
import 'package:grabbit/features/notifications/data/notifications_repository.dart';
import 'package:grabbit/features/settings/presentation/settings_controller.dart';

/// The outcome of a web-article capture (P16b-2), mapped to UI by the screen.
sealed class WebCaptureResult {
  const WebCaptureResult();
}

/// Branch (a) direct-parse: a deterministic Thing was asserted straight away.
class WebCaptureCommitted extends WebCaptureResult {
  const WebCaptureCommitted(this.thingId, this.type);
  final String thingId;
  final String type;
}

/// Branch (b/c) model: a pending suggestion was stored for review/confirm.
class WebCaptureReview extends WebCaptureResult {
  const WebCaptureReview(this.captureId, this.type);
  final String captureId;
  final String type;
}

/// No structured markup and (no model / nothing extracted) — offer manual entry.
class WebCaptureNothingFound extends WebCaptureResult {
  const WebCaptureNothingFound();
}

/// The fetch failed — [message] is user-facing, [code] drives any affordance.
class WebCaptureError extends WebCaptureResult {
  const WebCaptureError(this.message, this.code);
  final String message;
  final WebFetchError code;
}

/// The generate fn + model id the curator should fill with (P16b-2).
typedef CaptureGen = ({GenerateStructured generate, String? modelId});

/// Orchestrates web-article capture: fetch → CaptureService → assert or suggest.
abstract interface class WebCaptureController {
  Future<WebCaptureResult> capture(String url);
}

/// A no-op fill used when no function-calling model is ready — makes the curator
/// branch throw `unavailable`, which the controller catches → "nothing found".
Future<StructuredResult> _unavailableGenerate(
  List<StructuredToolDef> toolDefs,
  String prompt, {
  String? systemPrompt,
}) async => throw const InferenceException(
  InferenceErrorCode.unavailable,
  'Generation not available',
);

class DefaultWebCaptureController implements WebCaptureController {
  DefaultWebCaptureController(
    this._fetcher,
    this._capture,
    this._commit,
    this._suggestions,
    this._center,
    this._resolveGen, {
    DateTime Function() now = DateTime.now,
    String Function()? newCaptureId,
  }) : _now = now,
       _newCaptureId =
           newCaptureId ?? (() => 'cap_${now().microsecondsSinceEpoch}');

  final WebPageFetcher _fetcher;
  final CaptureService _capture;
  final CaptureCommitService _commit;
  final ThingSuggestionRepository _suggestions;
  final NotificationCenter _center;
  final Future<CaptureGen> Function() _resolveGen;
  final DateTime Function() _now;
  final String Function() _newCaptureId;

  @override
  Future<WebCaptureResult> capture(String url) async {
    final FetchedPage page;
    try {
      page = await _fetcher.fetch(url);
    } on WebFetchException catch (e) {
      return WebCaptureError(e.message, e.code);
    }

    final gen = await _resolveGen();
    final request = CaptureRequest(
      sourceRef: page.finalUrl,
      html: page.body,
      url: page.finalUrl,
      title: extractPageTitle(page.body),
      text: extractReadableText(page.body),
    );

    final CaptureOutcome outcome;
    try {
      outcome = await _capture.capture(
        request,
        generate: gen.generate,
        modelId: gen.modelId,
        now: _now,
      );
    } on InferenceException {
      // Model unavailable / failed → degrade to manual (direct-parse already ran).
      return const WebCaptureNothingFound();
    }

    final doc = outcome.doc;
    switch (outcome.branch) {
      case CaptureBranch.directParse:
        if (doc == null) return const WebCaptureNothingFound();
        final id = await _commit.commitThing(doc);
        return WebCaptureCommitted(id, outcome.type ?? '');
      case CaptureBranch.model:
        if (doc == null) return const WebCaptureNothingFound();
        final capId = _newCaptureId();
        final type = outcome.type ?? 'Thing';
        await _suggestions.replaceForItem(capId, [
          ThingSuggestionsCompanion.insert(
            id: 'sug_${_now().microsecondsSinceEpoch}',
            sourceItemId: capId,
            type: type,
            jsonld: doc.toJsonString(),
            confidence: Value(outcome.confidence),
            createdAt: _now(),
          ),
        ]);
        await postSuggestionNotification(
          _center,
          itemId: capId,
          title: request.title ?? page.finalUrl,
          type: type,
          targetRoute: '/capture/$capId/suggestions',
          dedupeKey: 'web_suggest_$capId',
        );
        return WebCaptureReview(capId, type);
      case CaptureBranch.none:
        return const WebCaptureNothingFound();
    }
  }
}

final webCaptureControllerProvider = FutureProvider<WebCaptureController>((
  ref,
) async {
  final captureService = await ref.watch(captureServiceProvider.future);
  return DefaultWebCaptureController(
    ref.watch(webPageFetcherProvider),
    captureService,
    ref.watch(captureCommitServiceProvider),
    ref.watch(thingSuggestionRepositoryProvider),
    ref.watch(notificationCenterProvider),
    () async {
      final model = ref.read(activeStructuredExtractionModelProvider);
      final enabled =
          ref.read(settingsControllerProvider).value?.generationEnabled ??
          false;
      final engine = ref.read(generationEngineProvider);
      // Probe only when enabled — never load a model the user hasn't opted into.
      final modelReady = model != null && enabled && await engine.ensureReady();
      if (modelReady) {
        return (generate: engine.generateStructured, modelId: model.id);
      }
      return (generate: _unavailableGenerate, modelId: null);
    },
  );
});
